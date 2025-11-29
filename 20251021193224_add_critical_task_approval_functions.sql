/*
  Fügt kritische Task Approval Funktionen hinzu die das Frontend braucht
  
  - approve_task_with_points()
  - reopen_task_with_penalty()
  - Benötigte Spalten für Tasks
*/

-- Füge fehlende Spalten zu tasks hinzu
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

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'pending_review'
  ) THEN
    -- Prüfe ob 'pending_review' Status existiert, wenn nicht füge hinzu
    ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_status_check;
    ALTER TABLE tasks ADD CONSTRAINT tasks_status_check CHECK (
      status = ANY (ARRAY['pending'::text, 'in_progress'::text, 'pending_review'::text, 'completed'::text, 'cancelled'::text])
    );
  END IF;
END $$;

-- Task Approval Funktion
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
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;

  -- Basis-Punkte
  v_base_points := v_task.points_value;

  -- Deadline-Bonus
  IF v_task.due_date IS NOT NULL AND v_task.completed_at IS NOT NULL THEN
    v_is_within_deadline := v_task.completed_at <= v_task.due_date;
    IF v_is_within_deadline THEN
      v_deadline_bonus := 2;
    END IF;
  END IF;

  -- Reopen-Penalty
  IF v_task.reopened_count > 0 THEN
    v_reopen_penalty := v_task.reopened_count * (-1);
  END IF;

  v_total_points := GREATEST(v_base_points + v_deadline_bonus + v_reopen_penalty, 0);

  -- Update task
  UPDATE tasks
  SET 
    status = 'completed',
    completed_at = COALESCE(completed_at, now()),
    deadline_bonus_awarded = (v_deadline_bonus > 0),
    initial_points_value = COALESCE(initial_points_value, points_value),
    points_value = v_total_points,
    updated_at = now()
  WHERE id = p_task_id;

  -- Award points
  IF v_task.assigned_to IS NOT NULL AND v_total_points > 0 THEN
    v_reason := 'Aufgabe erledigt: ' || v_task.title;
    IF v_deadline_bonus > 0 THEN
      v_reason := v_reason || ' (+2 Deadline-Bonus)';
    END IF;
    IF v_reopen_penalty < 0 THEN
      v_reason := v_reason || ' (' || v_reopen_penalty || ' Reopen-Penalty)';
    END IF;

    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (v_task.assigned_to, v_total_points, v_reason, 'task_completed', p_admin_id);
  END IF;

  -- Notification
  IF v_task.assigned_to IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_task.assigned_to,
      'Task genehmigt!',
      'Sehr gut! +' || v_total_points || ' Punkte für: ' || v_task.title,
      'success'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'base_points', v_base_points,
    'deadline_bonus', v_deadline_bonus,
    'reopen_penalty', v_reopen_penalty,
    'total_points', v_total_points
  );
END;
$$;

-- Task Reopen Funktion
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
  -- Verify admin
  IF NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = p_admin_id AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can reopen tasks';
  END IF;

  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;
  
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

  -- Notification
  IF v_task.assigned_to IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_task.assigned_to,
      'Task zur Überarbeitung',
      'Bitte überarbeite: ' || v_task.title || '. ' || COALESCE(p_admin_notes, ''),
      'warning'
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'reopened_count', COALESCE(v_task.reopened_count, 0) + 1);
END;
$$;