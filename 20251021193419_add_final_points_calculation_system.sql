/*
  FINALES PUNKTESYSTEM - Korrigiert alle vorherigen Bugs
  
  Korrekte Logik:
  - Unassigned Tasks: ALLE Staff bekommen volle Punkte
  - Shared Tasks: 50/50 Split
  - Deadline-Bonus: +2 Punkte
  - Check-in: 0 Punkte (kein automatischer Bonus)
*/

-- Daily Point Goals Tabelle erstellen falls nicht existiert
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

DROP POLICY IF EXISTS "Users can view own daily goals" ON daily_point_goals;
CREATE POLICY "Users can view own daily goals"
  ON daily_point_goals FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all daily goals" ON daily_point_goals;
CREATE POLICY "Admins can view all daily goals"
  ON daily_point_goals FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

DROP POLICY IF EXISTS "System can insert daily goals" ON daily_point_goals;
CREATE POLICY "System can insert daily goals"
  ON daily_point_goals FOR INSERT TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "System can update daily goals" ON daily_point_goals;
CREATE POLICY "System can update daily goals"
  ON daily_point_goals FOR UPDATE TO authenticated
  USING (true) WITH CHECK (true);

-- Individual Achievable Points Calculation
CREATE OR REPLACE FUNCTION calculate_daily_achievable_points(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points numeric := 0;
  v_has_checked_in boolean := false;
BEGIN
  -- Check if user checked in today (approved)
  SELECT EXISTS (
    SELECT 1 FROM check_ins
    WHERE user_id = p_user_id
    AND DATE(check_in_time) = p_date
    AND status = 'approved'
  ) INTO v_has_checked_in;

  IF NOT v_has_checked_in THEN
    RETURN 0;
  END IF;

  -- Check-in gibt 0 Punkte (kein Bonus mehr)
  
  -- Tasks: Solo = 100% + 2 Bonus, Shared = 50% + 1 Bonus, Unassigned = 100% + 2 Bonus für ALLE
  SELECT COALESCE(SUM(
    CASE 
      -- Unassigned Tasks: ALLE bekommen volle Punkte
      WHEN assigned_to IS NULL THEN 
        points_value + (CASE WHEN due_date IS NOT NULL THEN 2 ELSE 0 END)
      -- Assigned to this user AND has secondary: 50%
      WHEN assigned_to = p_user_id AND secondary_assigned_to IS NOT NULL THEN
        (points_value / 2) + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
      -- Secondary assignment: 50%
      WHEN secondary_assigned_to = p_user_id THEN
        (points_value / 2) + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
      -- Solo assignment: 100%
      WHEN assigned_to = p_user_id THEN
        points_value + (CASE WHEN due_date IS NOT NULL THEN 2 ELSE 0 END)
      ELSE 0
    END
  ), 0)
  INTO v_total_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status != 'cancelled'
  AND status != 'completed';

  RETURN v_total_points::integer;
END;
$$;

-- Team Achievable Points Calculation
CREATE OR REPLACE FUNCTION calculate_team_achievable_points(
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points integer := 0;
  v_checked_in_count integer := 0;
BEGIN
  -- Count approved check-ins
  SELECT COUNT(DISTINCT user_id) INTO v_checked_in_count
  FROM check_ins
  WHERE DATE(check_in_time) = p_date
  AND status = 'approved';

  -- Check-in: 0 × staff count
  
  -- Tasks: Each task counted ONCE
  SELECT COALESCE(SUM(
    points_value + (CASE WHEN due_date IS NOT NULL THEN 2 ELSE 0 END)
  ), 0)
  INTO v_total_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status != 'cancelled'
  AND status != 'completed';

  RETURN v_total_points;
END;
$$;

-- Update Daily Point Goals Function
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
  FOR v_user IN 
    SELECT id FROM profiles 
    WHERE (p_user_id IS NULL OR id = p_user_id)
    AND role = 'staff'
  LOOP
    v_achievable := calculate_daily_achievable_points(v_user.id, p_date);
    
    SELECT COALESCE(SUM(points_change), 0)
    INTO v_achieved
    FROM points_history
    WHERE user_id = v_user.id
    AND DATE(created_at) = p_date;
    
    IF v_achievable > 0 THEN
      v_percentage := (v_achieved::numeric / v_achievable::numeric) * 100;
    ELSE
      v_percentage := 0;
    END IF;

    IF v_percentage >= 90 THEN
      v_color := 'green';
    ELSIF v_percentage >= 70 THEN
      v_color := 'yellow';
    ELSE
      v_color := 'red';
    END IF;

    INSERT INTO daily_point_goals (
      user_id, goal_date, theoretically_achievable_points, achieved_points, 
      percentage, color_status, updated_at
    )
    VALUES (v_user.id, p_date, v_achievable, v_achieved, v_percentage, v_color, now())
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

-- Monthly Progress Function
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
  SELECT 
    COALESCE(SUM(theoretically_achievable_points), 0),
    COALESCE(SUM(achieved_points), 0)
  INTO v_total_achievable, v_total_achieved
  FROM daily_point_goals
  WHERE user_id = p_user_id
  AND EXTRACT(YEAR FROM goal_date) = p_year
  AND EXTRACT(MONTH FROM goal_date) = p_month;

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

-- Team Monthly Progress
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
BEGIN
  SELECT 
    COALESCE(SUM(theoretically_achievable_points), 0),
    COALESCE(SUM(achieved_points), 0)
  INTO v_total_achievable, v_total_achieved
  FROM daily_point_goals
  WHERE EXTRACT(YEAR FROM goal_date) = p_year
  AND EXTRACT(MONTH FROM goal_date) = p_month
  AND user_id IN (SELECT id FROM profiles WHERE role = 'staff');

  IF v_total_achievable > 0 THEN
    v_percentage := (v_total_achieved::numeric / v_total_achievable::numeric) * 100;
  END IF;

  RETURN jsonb_build_object(
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