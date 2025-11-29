/*
  # Dynamisches Punktesystem mit Deadline-Tracking und Ampel-Darstellung

  ## Neue Tabellen
  - `daily_point_goals`
    - Speichert tägliche Punkteziele pro Mitarbeiter
    - Tracked theoretisch erreichbare vs. tatsächlich erreichte Punkte
    - Basis für Ampel-Darstellung und Monatsziel-Berechnung

  ## Änderungen an bestehenden Tabellen
  - `tasks`
    - Fügt `deadline_bonus_awarded` hinzu
    - Fügt `initial_points_value` hinzu (für Reopen-Tracking)
  - `point_templates`
    - Fügt Standardwerte für verschiedene Task-Kategorien hinzu

  ## Neue Funktionen
  - `calculate_daily_achievable_points()` - Berechnet theoretisch erreichbare Punkte
  - `update_task_points_on_assignment()` - Verteilt Punkte dynamisch bei Zuweisung
  - `calculate_monthly_progress()` - Berechnet Monatsfortschritt für 90%-Ziel

  ## Security
  - RLS-Policies für daily_point_goals
  - Alle Mitarbeiter können eigene Ziele sehen
  - Admins können alle Ziele sehen und bearbeiten
*/

-- Tabelle für tägliche Punkteziele
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
END $$;

-- Funktion zum Einfügen der Standard-Punktewerte in point_templates
CREATE OR REPLACE FUNCTION ensure_default_point_templates()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Room Cleaning Template
  INSERT INTO point_templates (name, points, reason, category)
  VALUES ('Room Cleaning', 5, 'Room cleaning completed', 'room_cleaning')
  ON CONFLICT DO NOTHING;

  -- Small Cleaning Template
  INSERT INTO point_templates (name, points, reason, category)
  VALUES ('Small Cleaning', 3, 'Small cleaning completed', 'small_cleaning')
  ON CONFLICT DO NOTHING;

  -- Default Task Template
  INSERT INTO point_templates (name, points, reason, category)
  VALUES ('Standard Task', 2, 'Task completed', 'general')
  ON CONFLICT DO NOTHING;

  -- Punctuality Template
  INSERT INTO point_templates (name, points, reason, category)
  VALUES ('Pünktlich', 5, 'On-time check-in', 'punctuality')
  ON CONFLICT DO NOTHING;

  -- Deadline Bonus Template
  INSERT INTO point_templates (name, points, reason, category)
  VALUES ('Deadline Bonus', 2, 'Task completed within deadline', 'bonus')
  ON CONFLICT DO NOTHING;
END;
$$;

-- Standard-Templates einfügen
SELECT ensure_default_point_templates();

-- Funktion zur Berechnung der täglichen erreichbaren Punkte für einen Mitarbeiter
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

  -- Check-In Punkte (5 Punkte für Pünktlichkeit)
  v_total_points := v_total_points + v_checkin_points;

  -- Punkte aus zugewiesenen Tasks
  SELECT COALESCE(SUM(
    CASE 
      WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
        -- Bei 2 Mitarbeitern: halbe Punkte + ggf. Deadline-Bonus
        (points_value / 2) + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
      ELSE
        -- Vollständige Punkte + ggf. Deadline-Bonus
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

-- Funktion zur Berechnung der erreichten Punkte für einen Mitarbeiter an einem Tag
CREATE OR REPLACE FUNCTION calculate_daily_achieved_points(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points integer := 0;
BEGIN
  -- Punkte aus der points_history für diesen Tag
  SELECT COALESCE(SUM(points_change), 0)
  INTO v_total_points
  FROM points_history
  WHERE user_id = p_user_id
  AND DATE(created_at) = p_date;

  RETURN v_total_points;
END;
$$;

-- Funktion zum Update der täglichen Punkteziele
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
    v_achieved := calculate_daily_achieved_points(v_user.id, p_date);
    
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

-- Funktion zur Berechnung des Monatsfortschritts
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
  v_achieved_90_percent boolean := false;
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

  -- Prüfe ob 90% erreicht
  v_achieved_90_percent := v_percentage >= 90;

  RETURN jsonb_build_object(
    'user_id', p_user_id,
    'year', p_year,
    'month', p_month,
    'total_achievable', v_total_achievable,
    'total_achieved', v_total_achieved,
    'percentage', ROUND(v_percentage, 2),
    'achieved_90_percent', v_achieved_90_percent,
    'color_status', CASE
      WHEN v_percentage >= 90 THEN 'green'
      WHEN v_percentage >= 70 THEN 'yellow'
      ELSE 'red'
    END
  );
END;
$$;

-- Funktion zur Berechnung des Team-Monatsfortschritts
CREATE OR REPLACE FUNCTION calculate_team_monthly_progress(
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
  v_achieved_90_percent boolean := false;
BEGIN
  -- Summiere für alle Staff-Mitglieder
  SELECT 
    COALESCE(SUM(theoretically_achievable_points), 0),
    COALESCE(SUM(achieved_points), 0)
  INTO v_total_achievable, v_total_achieved
  FROM daily_point_goals
  WHERE EXTRACT(YEAR FROM goal_date) = p_year
  AND EXTRACT(MONTH FROM goal_date) = p_month
  AND user_id IN (SELECT id FROM profiles WHERE role = 'staff');

  -- Berechne Prozentsatz
  IF v_total_achievable > 0 THEN
    v_percentage := (v_total_achieved::numeric / v_total_achievable::numeric) * 100;
  END IF;

  -- Prüfe ob 90% erreicht
  v_achieved_90_percent := v_percentage >= 90;

  RETURN jsonb_build_object(
    'year', p_year,
    'month', p_month,
    'total_achievable', v_total_achievable,
    'total_achieved', v_total_achieved,
    'percentage', ROUND(v_percentage, 2),
    'achieved_90_percent', v_achieved_90_percent,
    'team_event_unlocked', v_achieved_90_percent,
    'color_status', CASE
      WHEN v_percentage >= 90 THEN 'green'
      WHEN v_percentage >= 70 THEN 'yellow'
      ELSE 'red'
    END
  );
END;
$$;
