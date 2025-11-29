/*
  # Add points calculation functions

  1. Functions Created
    - calculate_daily_achievable_points: Calculate achievable points per user
    - calculate_team_achievable_points: Calculate total team points
    - update_daily_point_goals: Update daily goals with current values

  2. Logic
    - Check-in gives 0 points
    - Solo tasks: 100% + 2 deadline bonus
    - Shared tasks: 50% each + 1 deadline bonus each
    - Unassigned tasks: ALL staff get 100% + 2 bonus
*/

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
  SELECT EXISTS (
    SELECT 1 FROM check_ins
    WHERE user_id = p_user_id
    AND DATE(check_in_time) = p_date
    AND status = 'approved'
  ) INTO v_has_checked_in;

  IF NOT v_has_checked_in THEN
    RETURN 0;
  END IF;

  SELECT COALESCE(SUM(
    CASE 
      WHEN assigned_to IS NULL THEN 
        points_value + (CASE WHEN due_date IS NOT NULL THEN 2 ELSE 0 END)
      WHEN assigned_to = p_user_id AND secondary_assigned_to IS NOT NULL THEN
        (points_value / 2) + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
      WHEN secondary_assigned_to = p_user_id THEN
        (points_value / 2) + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
      WHEN assigned_to = p_user_id THEN
        points_value + (CASE WHEN due_date IS NOT NULL THEN 2 ELSE 0 END)
      ELSE 0
    END
  ), 0)
  INTO v_total_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status != 'cancelled'
  AND status != 'archived'
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
BEGIN
  SELECT COALESCE(SUM(
    points_value + (CASE WHEN due_date IS NOT NULL THEN 2 ELSE 0 END)
  ), 0)
  INTO v_total_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status != 'cancelled'
  AND status != 'archived'
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
  v_team_achievable integer;
  v_team_achieved integer;
BEGIN
  v_team_achievable := calculate_team_achievable_points(p_date);
  
  SELECT COALESCE(SUM(points_change), 0)
  INTO v_team_achieved
  FROM points_history
  WHERE DATE(created_at) = p_date;

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
      percentage, color_status, team_achievable_points, team_points_earned, updated_at
    )
    VALUES (v_user.id, p_date, v_achievable, v_achieved, v_percentage, v_color, 
            v_team_achievable, v_team_achieved, now())
    ON CONFLICT (user_id, goal_date)
    DO UPDATE SET
      theoretically_achievable_points = v_achievable,
      achieved_points = v_achieved,
      percentage = v_percentage,
      color_status = v_color,
      team_achievable_points = v_team_achievable,
      team_points_earned = v_team_achieved,
      updated_at = now();
  END LOOP;
END;
$$;
