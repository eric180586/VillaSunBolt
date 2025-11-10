/*
  # Rewrite Theoretically Achievable Points Calculation

  1. New Logic
    - Check-in points (+5) for users with schedule today
    - Unassigned tasks: counted for ALL users with schedule today
    - Assigned tasks: only for assigned user
    - Helper tasks: split points (50% each)
    - Patrol rounds: +1 per scheduled scan
  
  2. Key Changes
    - Templates that generate tasks today ARE included
    - Tasks are "achievable" until someone takes them
    - When task assigned, it's removed from others' achievable pool
  
  3. Security
    - Function is SECURITY DEFINER to access all data
    - Called by triggers and scheduled jobs
*/

-- Drop old function if exists
DROP FUNCTION IF EXISTS calculate_theoretically_achievable_points(uuid, date);

-- Create new function with correct logic
CREATE OR REPLACE FUNCTION calculate_theoretically_achievable_points(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_achievable_points integer := 0;
  v_has_schedule boolean := false;
  v_shift_type text;
BEGIN
  -- Check if user has a schedule for this date
  SELECT 
    CASE 
      WHEN p_date = ANY(morning_shift_dates) THEN 'morning'
      WHEN p_date = ANY(late_shift_dates) THEN 'late'
      ELSE NULL
    END INTO v_shift_type
  FROM schedules
  WHERE user_id = p_user_id
  LIMIT 1;

  v_has_schedule := (v_shift_type IS NOT NULL);

  -- 1. Check-in points (+5 for punctuality)
  IF v_has_schedule THEN
    v_achievable_points := v_achievable_points + 5;
  END IF;

  -- 2. Unassigned tasks (everyone with schedule can potentially do them)
  IF v_has_schedule THEN
    SELECT COALESCE(SUM(points_value), 0) INTO v_achievable_points
    FROM (
      SELECT v_achievable_points + COALESCE(SUM(t.points_value), 0) as points_value
      FROM tasks t
      WHERE t.assigned_to IS NULL
        AND t.is_template = false
        AND t.status != 'completed'
        AND t.status != 'archived'
        AND DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date
    ) unassigned;
  END IF;

  -- 3. Assigned tasks (only for this user)
  SELECT v_achievable_points + COALESCE(SUM(t.points_value), 0) INTO v_achievable_points
  FROM tasks t
  WHERE t.assigned_to = p_user_id
    AND t.is_template = false
    AND t.status != 'completed'
    AND t.status != 'archived'
    AND DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date;

  -- 4. Helper tasks (split points - 50% for helper)
  SELECT v_achievable_points + COALESCE(SUM(t.points_value / 2), 0) INTO v_achievable_points
  FROM tasks t
  WHERE t.helper_id = p_user_id
    AND t.is_template = false
    AND t.status != 'completed'
    AND t.status != 'archived'
    AND DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date;

  -- 5. Patrol rounds (+1 per scheduled scan)
  SELECT v_achievable_points + COALESCE(COUNT(*), 0) INTO v_achievable_points
  FROM patrol_rounds pr
  WHERE pr.assigned_to = p_user_id
    AND DATE(pr.scheduled_time AT TIME ZONE 'Asia/Phnom_Penh') = p_date
    AND pr.status != 'completed';

  RETURN v_achievable_points;
END;
$$;

-- Create function to calculate achieved points from points_history
CREATE OR REPLACE FUNCTION calculate_achieved_points(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_achieved_points integer := 0;
BEGIN
  SELECT COALESCE(SUM(points_change), 0) INTO v_achieved_points
  FROM points_history
  WHERE user_id = p_user_id
    AND DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date;

  RETURN v_achieved_points;
END;
$$;

-- Create function to determine color based on percentage
CREATE OR REPLACE FUNCTION get_color_status(
  p_achievable integer,
  p_achieved integer
)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_percentage numeric;
BEGIN
  -- If no achievable points, return gray (neutral)
  IF p_achievable = 0 THEN
    RETURN 'gray';
  END IF;

  v_percentage := (p_achieved::numeric / p_achievable::numeric) * 100;

  -- Color thresholds
  IF v_percentage >= 95 THEN
    RETURN 'dark-green';
  ELSIF v_percentage >= 90 THEN
    RETURN 'green';
  ELSIF v_percentage >= 83 THEN
    RETURN 'orange';
  ELSIF v_percentage >= 74 THEN
    RETURN 'yellow';
  ELSE
    RETURN 'red';
  END IF;
END;
$$;

-- Update daily_point_goals table with new calculations
CREATE OR REPLACE FUNCTION update_daily_point_goals_for_user(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_achievable integer;
  v_achieved integer;
  v_percentage numeric;
  v_color text;
BEGIN
  -- Calculate points
  v_achievable := calculate_theoretically_achievable_points(p_user_id, p_date);
  v_achieved := calculate_achieved_points(p_user_id, p_date);
  
  -- Calculate percentage
  IF v_achievable > 0 THEN
    v_percentage := (v_achieved::numeric / v_achievable::numeric) * 100;
  ELSE
    v_percentage := 0;
  END IF;

  -- Get color status
  v_color := get_color_status(v_achievable, v_achieved);

  -- Upsert into daily_point_goals
  INSERT INTO daily_point_goals (
    user_id,
    goal_date,
    theoretically_achievable_points,
    achieved_points,
    percentage,
    color_status
  )
  VALUES (
    p_user_id,
    p_date,
    v_achievable,
    v_achieved,
    v_percentage,
    v_color
  )
  ON CONFLICT (user_id, goal_date)
  DO UPDATE SET
    theoretically_achievable_points = v_achievable,
    achieved_points = v_achieved,
    percentage = v_percentage,
    color_status = v_color,
    updated_at = now();
END;
$$;

-- Update all users' daily point goals
CREATE OR REPLACE FUNCTION update_all_daily_point_goals(
  p_date date DEFAULT CURRENT_DATE
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_record RECORD;
BEGIN
  FOR v_user_record IN 
    SELECT id FROM profiles WHERE role = 'staff'
  LOOP
    PERFORM update_daily_point_goals_for_user(v_user_record.id, p_date);
  END LOOP;
END;
$$;