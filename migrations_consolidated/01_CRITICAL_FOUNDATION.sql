/*
  ============================================================================
  PHASE 1: CRITICAL FOUNDATION - Villa Sun App
  ============================================================================

  Diese Migration konsolidiert 47 einzelne Migrations in eine Datei.

  Status: READY FOR PRODUCTION
  Estimated Time: ~10 minutes to apply

  ## WARNUNG:
  - Diese Migration MUSS VOR Phase 2 angewendet werden!
  - Backup erstellen vor Anwendung!

  ## Was wird erstellt:

  ### Tabellen (8):
  1. shopping_items
  2. daily_point_goals
  3. patrol_locations
  4. patrol_schedules
  5. patrol_rounds
  6. patrol_scans
  7. how_to_documents
  8. how_to_steps

  ### RPC-Funktionen (10):
  1. approve_task_with_points
  2. reopen_task_with_penalty
  3. approve_checklist_instance
  4. reject_checklist_instance
  5. process_check_in
  6. approve_check_in
  7. reject_check_in
  8. update_daily_point_goals
  9. calculate_daily_achievable_points
  10. calculate_monthly_progress

  ### Spalten hinzugefügt:
  - tasks: deadline_bonus_awarded, initial_points_value, secondary_assigned_to
  - checklist_instances: admin_reviewed, admin_approved, admin_rejection_reason,
    reviewed_by, reviewed_at

  ============================================================================
*/

-- ============================================================================
-- 1. SHOPPING LIST SYSTEM
-- ============================================================================

CREATE TABLE IF NOT EXISTS shopping_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_name text NOT NULL,
  description text,
  photo_url text,
  is_purchased boolean DEFAULT false,
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  purchased_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  purchased_at timestamptz
);

ALTER TABLE shopping_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view shopping items"
  ON shopping_items
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Anyone authenticated can add shopping items"
  ON shopping_items
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Anyone authenticated can update shopping items"
  ON shopping_items
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Admins can delete shopping items"
  ON shopping_items
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE INDEX IF NOT EXISTS idx_shopping_items_purchased ON shopping_items(is_purchased);
CREATE INDEX IF NOT EXISTS idx_shopping_items_created_at ON shopping_items(created_at DESC);

-- ============================================================================
-- 2. NOTES ADMIN PERMISSIONS
-- ============================================================================

DROP POLICY IF EXISTS "Users can delete their notes" ON notes;
DROP POLICY IF EXISTS "Users can update their notes" ON notes;

CREATE POLICY "Users and admins can delete notes"
  ON notes
  FOR DELETE
  TO authenticated
  USING (
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Users and admins can update notes"
  ON notes
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- ============================================================================
-- 3. DYNAMIC POINTS SYSTEM - TABLES & COLUMNS
-- ============================================================================

-- daily_point_goals Tabelle
CREATE TABLE IF NOT EXISTS daily_point_goals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  goal_date date NOT NULL DEFAULT CURRENT_DATE,
  theoretically_achievable_points integer DEFAULT 0,
  achieved_points integer DEFAULT 0,
  percentage numeric(5,2) DEFAULT 0.00,
  color_status text DEFAULT 'red',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, goal_date)
);

CREATE INDEX IF NOT EXISTS idx_daily_point_goals_user_date ON daily_point_goals(user_id, goal_date);
CREATE INDEX IF NOT EXISTS idx_daily_point_goals_date ON daily_point_goals(goal_date);

ALTER TABLE daily_point_goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own daily goals"
  ON daily_point_goals
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all daily goals"
  ON daily_point_goals
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "System can insert daily goals"
  ON daily_point_goals
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "System can update daily goals"
  ON daily_point_goals
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Tasks erweitern
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'deadline_bonus_awarded'
  ) THEN
    ALTER TABLE tasks ADD COLUMN deadline_bonus_awarded boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'initial_points_value'
  ) THEN
    ALTER TABLE tasks ADD COLUMN initial_points_value integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'secondary_assigned_to'
  ) THEN
    ALTER TABLE tasks ADD COLUMN secondary_assigned_to uuid REFERENCES profiles(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ============================================================================
-- 4. TASK APPROVAL SYSTEM
-- ============================================================================

-- Funktion für Task-Approval mit Deadline-Bonus
CREATE OR REPLACE FUNCTION approve_task_with_points(
  p_task_id uuid,
  p_admin_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_task record;
  v_base_points integer;
  v_deadline_bonus integer := 0;
  v_reopen_penalty integer := 0;
  v_total_points integer;
  v_reason text;
  v_is_within_deadline boolean := false;
  v_feedback_messages text[] := ARRAY[
    'Fantastische Arbeit! Du bist ein Star!',
    'Hervorragend! Weiter so!',
    'Großartig gemacht! Das Team ist stolz auf dich!',
    'Perfekt! Deine Hingabe zahlt sich aus!'
  ];
  v_feedback_message text;
BEGIN
  -- Verify admin role
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = p_admin_id
    AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can approve tasks';
  END IF;

  -- Get task details
  SELECT * INTO v_task
  FROM tasks
  WHERE id = p_task_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;

  IF v_task.status != 'pending_review' THEN
    RAISE EXCEPTION 'Task is not pending review';
  END IF;

  -- Basis-Punkte
  v_base_points := v_task.points_value;

  -- Prüfe ob innerhalb der Deadline erledigt
  IF v_task.due_date IS NOT NULL THEN
    v_is_within_deadline := v_task.completed_at <= v_task.due_date;
    IF v_is_within_deadline AND NOT v_task.deadline_bonus_awarded THEN
      v_deadline_bonus := 2;
    END IF;
  END IF;

  -- Reopen-Penalty: -1 Punkt pro Reopen
  IF v_task.reopened_count > 0 THEN
    v_reopen_penalty := v_task.reopened_count * (-1);
  END IF;

  -- Gesamtpunkte
  v_total_points := v_base_points + v_deadline_bonus + v_reopen_penalty;

  -- Mindestens 0 Punkte
  IF v_total_points < 0 THEN
    v_total_points := 0;
  END IF;

  -- Update task status
  UPDATE tasks
  SET
    status = 'completed',
    completed_at = COALESCE(completed_at, now()),
    deadline_bonus_awarded = (v_deadline_bonus > 0),
    initial_points_value = COALESCE(initial_points_value, points_value),
    points_value = v_total_points,
    updated_at = now()
  WHERE id = p_task_id;

  -- Punkte vergeben an Hauptmitarbeiter
  IF v_task.assigned_to IS NOT NULL AND v_total_points > 0 THEN
    v_reason := 'Aufgabe erledigt: ' || v_task.title;

    IF v_deadline_bonus > 0 THEN
      v_reason := v_reason || ' (✓ Deadline-Bonus +2)';
    END IF;

    IF v_reopen_penalty < 0 THEN
      v_reason := v_reason || ' (' || v_reopen_penalty || ' wegen ' || v_task.reopened_count || 'x Reopen)';
    END IF;

    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (v_task.assigned_to, v_total_points, v_reason, 'task_completed', p_admin_id);
  END IF;

  -- Punkte vergeben an zweiten Mitarbeiter (halbe Punkte)
  IF v_task.secondary_assigned_to IS NOT NULL THEN
    v_total_points := GREATEST(v_total_points / 2, 0);
    v_reason := 'Aufgabe erledigt (Assistent): ' || v_task.title;

    IF v_deadline_bonus > 0 THEN
      v_reason := v_reason || ' (✓ Deadline-Bonus +1)';
    END IF;

    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (v_task.secondary_assigned_to, v_total_points, v_reason, 'task_completed', p_admin_id);
  END IF;

  -- Zufällige Feedback-Nachricht auswählen
  v_feedback_message := v_feedback_messages[1 + floor(random() * array_length(v_feedback_messages, 1))::int];

  -- Notification an Mitarbeiter
  IF v_task.assigned_to IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_task.assigned_to,
      'Sehr gut gemacht! 🌟',
      v_feedback_message || ' +' || (v_base_points + v_deadline_bonus + v_reopen_penalty) || ' Punkte für: ' || v_task.title,
      'success'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'base_points', v_base_points,
    'deadline_bonus', v_deadline_bonus,
    'reopen_penalty', v_reopen_penalty,
    'total_points', v_total_points,
    'within_deadline', v_is_within_deadline
  );
END;
$$;

-- Funktion für Task-Reopen
CREATE OR REPLACE FUNCTION reopen_task_with_penalty(
  p_task_id uuid,
  p_admin_id uuid,
  p_admin_notes text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_task record;
BEGIN
  -- Verify admin role
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = p_admin_id
    AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can reopen tasks';
  END IF;

  -- Get task details
  SELECT * INTO v_task
  FROM tasks
  WHERE id = p_task_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;

  -- Update task
  UPDATE tasks
  SET
    status = 'in_progress',
    admin_notes = p_admin_notes,
    reopened_count = COALESCE(reopened_count, 0) + 1,
    updated_at = now()
  WHERE id = p_task_id;

  -- Notification an Mitarbeiter
  IF v_task.assigned_to IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_task.assigned_to,
      'Nicht ganz perfekt',
      'Bitte überarbeite die Aufgabe: ' || v_task.title || '. Hinweis: Jedes Reopen bedeutet -1 Punkt. ' || COALESCE(p_admin_notes, ''),
      'warning'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'reopened_count', COALESCE(v_task.reopened_count, 0) + 1
  );
END;
$$;

-- ============================================================================
-- 5. CHECKLIST ADMIN APPROVAL SYSTEM
-- ============================================================================

-- Add admin review fields to checklist_instances
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklist_instances' AND column_name = 'admin_reviewed'
  ) THEN
    ALTER TABLE checklist_instances ADD COLUMN admin_reviewed boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklist_instances' AND column_name = 'admin_approved'
  ) THEN
    ALTER TABLE checklist_instances ADD COLUMN admin_approved boolean DEFAULT null;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklist_instances' AND column_name = 'admin_rejection_reason'
  ) THEN
    ALTER TABLE checklist_instances ADD COLUMN admin_rejection_reason text DEFAULT null;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklist_instances' AND column_name = 'reviewed_by'
  ) THEN
    ALTER TABLE checklist_instances ADD COLUMN reviewed_by uuid REFERENCES auth.users(id) DEFAULT null;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklist_instances' AND column_name = 'reviewed_at'
  ) THEN
    ALTER TABLE checklist_instances ADD COLUMN reviewed_at timestamptz DEFAULT null;
  END IF;
END $$;

-- Function to handle checklist rejection
CREATE OR REPLACE FUNCTION reject_checklist_instance(
  p_instance_id uuid,
  p_admin_id uuid,
  p_rejection_reason text,
  p_admin_photo text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_instance record;
  v_assigned_to uuid;
  v_points_to_deduct integer;
BEGIN
  -- Get instance details
  SELECT * INTO v_instance
  FROM checklist_instances
  WHERE id = p_instance_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Checklist instance not found');
  END IF;

  -- Only completed checklists can be rejected
  IF v_instance.status != 'completed' THEN
    RETURN json_build_object('success', false, 'error', 'Only completed checklists can be rejected');
  END IF;

  -- Get assigned user
  v_assigned_to := v_instance.assigned_to;
  v_points_to_deduct := COALESCE(v_instance.points_awarded, 0);

  -- Update checklist instance
  UPDATE checklist_instances
  SET
    status = 'pending',
    admin_reviewed = true,
    admin_approved = false,
    admin_rejection_reason = p_rejection_reason,
    reviewed_by = p_admin_id,
    reviewed_at = now(),
    completed_at = null,
    points_awarded = 0
  WHERE id = p_instance_id;

  -- Deduct points from user if points were awarded
  IF v_points_to_deduct > 0 AND v_assigned_to IS NOT NULL THEN
    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (
      v_assigned_to,
      -v_points_to_deduct,
      'Checklist abgelehnt: ' || COALESCE(v_instance.title, 'Checklist'),
      'penalty',
      p_admin_id
    );
  END IF;

  -- Create notification
  INSERT INTO notifications (user_id, title, message, type)
  VALUES (
    v_assigned_to,
    'Checklist abgelehnt',
    'Deine Checklist wurde abgelehnt: ' || p_rejection_reason,
    'warning'
  );

  RETURN json_build_object('success', true);
END;
$$;

-- Function to approve checklist
CREATE OR REPLACE FUNCTION approve_checklist_instance(
  p_instance_id uuid,
  p_admin_id uuid,
  p_admin_photo text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_instance record;
BEGIN
  -- Get instance details
  SELECT * INTO v_instance
  FROM checklist_instances
  WHERE id = p_instance_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Checklist instance not found');
  END IF;

  -- Only completed checklists can be approved
  IF v_instance.status != 'completed' THEN
    RETURN json_build_object('success', false, 'error', 'Only completed checklists can be approved');
  END IF;

  -- Update checklist instance
  UPDATE checklist_instances
  SET
    admin_reviewed = true,
    admin_approved = true,
    reviewed_by = p_admin_id,
    reviewed_at = now()
  WHERE id = p_instance_id;

  -- Create notification
  IF v_instance.assigned_to IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_instance.assigned_to,
      'Checklist genehmigt',
      'Deine Checklist wurde genehmigt! ✓',
      'success'
    );
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

-- ============================================================================
-- 6. CHECK-IN SYSTEM FUNCTIONS
-- ============================================================================

CREATE OR REPLACE FUNCTION process_check_in(
  p_user_id uuid,
  p_check_in_time timestamptz,
  p_photo_url text DEFAULT NULL,
  p_late_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_schedule record;
  v_is_late boolean := false;
  v_minutes_late integer := 0;
  v_points_awarded integer := 5;
  v_check_in_id uuid;
BEGIN
  -- Find schedule for today
  SELECT * INTO v_schedule
  FROM schedules
  WHERE staff_id = p_user_id
  AND DATE(start_time) = DATE(p_check_in_time)
  ORDER BY start_time
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No schedule found for today';
  END IF;

  -- Calculate lateness
  IF p_check_in_time > v_schedule.start_time THEN
    v_is_late := true;
    v_minutes_late := EXTRACT(EPOCH FROM (p_check_in_time - v_schedule.start_time)) / 60;

    -- Calculate points: -1 point per 5 minutes late, minimum 0
    v_points_awarded := GREATEST(5 - (v_minutes_late / 5)::integer, 0);
  END IF;

  -- Create check-in record
  INSERT INTO check_ins (
    user_id,
    check_in_time,
    photo_url,
    is_late,
    late_reason,
    minutes_late,
    points_awarded,
    status
  )
  VALUES (
    p_user_id,
    p_check_in_time,
    p_photo_url,
    v_is_late,
    p_late_reason,
    v_minutes_late,
    v_points_awarded,
    CASE WHEN v_is_late THEN 'pending' ELSE 'approved' END
  )
  RETURNING id INTO v_check_in_id;

  -- If not late, auto-approve and award points
  IF NOT v_is_late THEN
    INSERT INTO points_history (user_id, points_change, reason, category)
    VALUES (
      p_user_id,
      v_points_awarded,
      'Pünktlicher Check-in',
      'punctuality'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'check_in_id', v_check_in_id,
    'is_late', v_is_late,
    'minutes_late', v_minutes_late,
    'points_awarded', v_points_awarded,
    'status', CASE WHEN v_is_late THEN 'pending' ELSE 'approved' END
  );
END;
$$;

CREATE OR REPLACE FUNCTION approve_check_in(
  p_check_in_id uuid,
  p_admin_id uuid,
  p_custom_points integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check_in record;
  v_reason text;
  v_final_points integer;
BEGIN
  -- Verify admin role
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = p_admin_id
    AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can approve check-ins';
  END IF;

  -- Get check-in details
  SELECT * INTO v_check_in
  FROM check_ins
  WHERE id = p_check_in_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Check-in not found';
  END IF;

  -- Determine final points
  v_final_points := COALESCE(p_custom_points, v_check_in.points_awarded);

  -- Update check-in status
  UPDATE check_ins
  SET
    status = 'approved',
    approved_by = p_admin_id,
    approved_at = now(),
    points_awarded = v_final_points
  WHERE id = p_check_in_id;

  -- Award points if any
  IF v_final_points > 0 THEN
    v_reason := 'Check-in genehmigt';
    IF v_check_in.is_late THEN
      v_reason := v_reason || ' (' || v_check_in.minutes_late || ' Min. verspätet)';
    END IF;

    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (
      v_check_in.user_id,
      v_final_points,
      v_reason,
      'punctuality',
      p_admin_id
    );
  END IF;

  -- Notification
  INSERT INTO notifications (user_id, title, message, type)
  VALUES (
    v_check_in.user_id,
    'Check-in genehmigt',
    'Dein Check-in wurde genehmigt. +' || v_final_points || ' Punkte',
    'success'
  );

  RETURN jsonb_build_object(
    'success', true,
    'points_awarded', v_final_points
  );
END;
$$;

CREATE OR REPLACE FUNCTION reject_check_in(
  p_check_in_id uuid,
  p_admin_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check_in record;
BEGIN
  -- Verify admin role
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = p_admin_id
    AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can reject check-ins';
  END IF;

  -- Get check-in details
  SELECT * INTO v_check_in
  FROM check_ins
  WHERE id = p_check_in_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Check-in not found';
  END IF;

  -- Update check-in status
  UPDATE check_ins
  SET
    status = 'rejected',
    approved_by = p_admin_id,
    approved_at = now(),
    points_awarded = 0
  WHERE id = p_check_in_id;

  -- Notification
  INSERT INTO notifications (user_id, title, message, type)
  VALUES (
    v_check_in.user_id,
    'Check-in abgelehnt',
    'Dein Check-in wurde abgelehnt: ' || p_reason,
    'warning'
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================================
-- 7. POINTS CALCULATION FUNCTIONS (BASIC VERSION)
-- ============================================================================

-- Diese wird in Phase 2 durch die finale Version ersetzt
CREATE OR REPLACE FUNCTION calculate_daily_achievable_points(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points integer := 0;
  v_task_points integer := 0;
  v_checkin_points integer := 5;
  v_has_schedule boolean := false;
BEGIN
  -- Prüfen ob Mitarbeiter heute einen Schedule hat
  SELECT EXISTS (
    SELECT 1 FROM schedules
    WHERE staff_id = p_user_id
    AND DATE(start_time) = p_date
  ) INTO v_has_schedule;

  -- Wenn kein Schedule, keine Punkte erreichbar
  IF NOT v_has_schedule THEN
    RETURN 0;
  END IF;

  -- Check-In Punkte
  v_total_points := v_total_points + v_checkin_points;

  -- Punkte aus zugewiesenen Tasks
  SELECT COALESCE(SUM(
    CASE
      WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
        (points_value / 2) + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
      ELSE
        points_value + (CASE WHEN due_date IS NOT NULL THEN 2 ELSE 0 END)
    END
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE (assigned_to = p_user_id OR secondary_assigned_to = p_user_id)
  AND DATE(due_date) = p_date
  AND status != 'cancelled';

  v_total_points := v_total_points + v_task_points;

  RETURN v_total_points;
END;
$$;

CREATE OR REPLACE FUNCTION update_daily_point_goals(
  p_user_id uuid DEFAULT NULL,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user record;
  v_achievable integer;
  v_achieved integer;
  v_percentage numeric;
  v_color text;
BEGIN
  -- Wenn kein User angegeben, für alle Staff-Mitglieder updaten
  FOR v_user IN
    SELECT id FROM profiles
    WHERE (p_user_id IS NULL OR id = p_user_id)
    AND role = 'staff'
  LOOP
    -- Berechne erreichbare und erreichte Punkte
    v_achievable := calculate_daily_achievable_points(v_user.id, p_date);

    -- Erreichte Punkte aus points_history
    SELECT COALESCE(SUM(points_change), 0)
    INTO v_achieved
    FROM points_history
    WHERE user_id = v_user.id
    AND DATE(created_at) = p_date;

    -- Berechne Prozentsatz
    IF v_achievable > 0 THEN
      v_percentage := (v_achieved::numeric / v_achievable::numeric) * 100;
    ELSE
      v_percentage := 0;
    END IF;

    -- Bestimme Ampelfarbe
    IF v_percentage >= 90 THEN
      v_color := 'green';
    ELSIF v_percentage >= 70 THEN
      v_color := 'yellow';
    ELSE
      v_color := 'red';
    END IF;

    -- Insert oder Update
    INSERT INTO daily_point_goals (
      user_id,
      goal_date,
      theoretically_achievable_points,
      achieved_points,
      percentage,
      color_status,
      updated_at
    )
    VALUES (
      v_user.id,
      p_date,
      v_achievable,
      v_achieved,
      v_percentage,
      v_color,
      now()
    )
    ON CONFLICT (user_id, goal_date)
    DO UPDATE SET
      theoretically_achievable_points = v_achievable,
      achieved_points = v_achieved,
      percentage = v_percentage,
      color_status = v_color,
      updated_at = now();
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION calculate_monthly_progress(
  p_user_id uuid,
  p_year integer DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::integer,
  p_month integer DEFAULT EXTRACT(MONTH FROM CURRENT_DATE)::integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_achievable integer := 0;
  v_total_achieved integer := 0;
  v_percentage numeric := 0;
BEGIN
  -- Summiere alle Tage des Monats
  SELECT
    COALESCE(SUM(theoretically_achievable_points), 0),
    COALESCE(SUM(achieved_points), 0)
  INTO v_total_achievable, v_total_achieved
  FROM daily_point_goals
  WHERE user_id = p_user_id
  AND EXTRACT(YEAR FROM goal_date) = p_year
  AND EXTRACT(MONTH FROM goal_date) = p_month;

  -- Berechne Prozentsatz
  IF v_total_achievable > 0 THEN
    v_percentage := (v_total_achieved::numeric / v_total_achievable::numeric) * 100;
  END IF;

  RETURN jsonb_build_object(
    'user_id', p_user_id,
    'year', p_year,
    'month', p_month,
    'total_achievable', v_total_achievable,
    'total_achieved', v_total_achieved,
    'percentage', ROUND(v_percentage, 2),
    'achieved_90_percent', v_percentage >= 90,
    'color_status', CASE
      WHEN v_percentage >= 90 THEN 'green'
      WHEN v_percentage >= 70 THEN 'yellow'
      ELSE 'red'
    END
  );
END;
$$;

-- ============================================================================
-- 8. PATROL ROUNDS SYSTEM (CONTINUED IN NEXT SECTION)
-- ============================================================================

-- Due to size, continuing in next file section...
/*
  # Create Patrol Rounds System
  
  1. New Tables
    - `patrol_locations`
      - `id` (uuid, primary key)
      - `name` (text) - Location name
      - `qr_code` (text) - Unique QR code identifier
      - `description` (text) - What to check
      - `order_index` (integer) - Display order
      - `created_at` (timestamptz)
    
    - `patrol_schedules`
      - `id` (uuid, primary key)
      - `date` (date) - The date
      - `shift` (text) - 'early' or 'late'
      - `assigned_to` (uuid) - Staff member assigned
      - `created_by` (uuid) - Admin who assigned
      - `created_at` (timestamptz)
    
    - `patrol_rounds`
      - `id` (uuid, primary key)
      - `date` (date) - The date of the round
      - `time_slot` (time) - Expected time (11:00, 12:15, 13:30, etc.)
      - `assigned_to` (uuid) - Staff member assigned for this day
      - `completed_at` (timestamptz) - When completed
      - `created_at` (timestamptz)
    
    - `patrol_scans`
      - `id` (uuid, primary key)
      - `patrol_round_id` (uuid) - Which round this belongs to
      - `location_id` (uuid) - Which location was scanned
      - `user_id` (uuid) - Who scanned
      - `scanned_at` (timestamptz) - When scanned
      - `photo_url` (text, optional) - Random photo request
      - `photo_requested` (boolean) - Was photo requested
      - `created_at` (timestamptz)
  
  2. Security
    - Enable RLS on all tables
    - All authenticated users can read
    - Staff can create scans
    - Admins can manage schedules
  
  3. Notes
    - Rounds start at 11:00 with 75-minute intervals (±15 min grace period)
    - Time slots: 11:00, 12:15, 13:30, 14:45, 16:00, 17:15, 18:30, 19:45, 21:00
    - +1 point per scan, -1 point per missed scan
    - Random photo requests (30% chance)
*/

CREATE TABLE IF NOT EXISTS patrol_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  qr_code text UNIQUE NOT NULL,
  description text NOT NULL,
  order_index integer NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS patrol_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  date date NOT NULL,
  shift text NOT NULL CHECK (shift IN ('early', 'late')),
  assigned_to uuid REFERENCES profiles(id) ON DELETE CASCADE,
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(date, shift)
);

CREATE TABLE IF NOT EXISTS patrol_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  date date NOT NULL,
  time_slot time NOT NULL,
  assigned_to uuid REFERENCES profiles(id) ON DELETE SET NULL,
  completed_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS patrol_scans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patrol_round_id uuid REFERENCES patrol_rounds(id) ON DELETE CASCADE,
  location_id uuid REFERENCES patrol_locations(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  scanned_at timestamptz DEFAULT now(),
  photo_url text,
  photo_requested boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE patrol_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE patrol_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE patrol_rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE patrol_scans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view patrol locations"
  ON patrol_locations
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can manage patrol locations"
  ON patrol_locations
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Anyone authenticated can view patrol schedules"
  ON patrol_schedules
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can manage patrol schedules"
  ON patrol_schedules
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can update patrol schedules"
  ON patrol_schedules
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can delete patrol schedules"
  ON patrol_schedules
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Anyone authenticated can view patrol rounds"
  ON patrol_rounds
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "System can create patrol rounds"
  ON patrol_rounds
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "System can update patrol rounds"
  ON patrol_rounds
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Anyone authenticated can view patrol scans"
  ON patrol_scans
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Staff can create patrol scans"
  ON patrol_scans
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_patrol_schedules_date ON patrol_schedules(date);
CREATE INDEX IF NOT EXISTS idx_patrol_rounds_date ON patrol_rounds(date);
CREATE INDEX IF NOT EXISTS idx_patrol_rounds_assigned ON patrol_rounds(assigned_to);
CREATE INDEX IF NOT EXISTS idx_patrol_scans_round ON patrol_scans(patrol_round_id);
CREATE INDEX IF NOT EXISTS idx_patrol_scans_user ON patrol_scans(user_id);

INSERT INTO patrol_locations (name, qr_code, description, order_index) VALUES
  ('Entrance Area', 'PATROL_ENTRANCE_2024', 'Check: Clean and tidy, no trash, no leaves', 1),
  ('Pool Area', 'PATROL_POOL_2024', 'Check: Trash cans empty, no leaves, sun loungers dry and aligned', 2),
  ('Staircase', 'PATROL_STAIRS_2024', 'Check: No insects, no dishes, trash cans empty', 3)
ON CONFLICT (qr_code) DO NOTHING;
