/*
  # Fix Achievable Points Calculation

  1. Changes
    - Use initial_points_value (or points_value if not set) for achievable calculation
    - This ensures reopen penalties don't reduce achievable points
    - Achievable points = base points (5) + deadline bonus (1) = max 6 per task
    - Reopen penalties only affect achieved points, not achievable

  2. Logic
    - For achievable: Use initial value before any penalties
    - Deadline bonus is +1 point if deadline exists
    - Shared tasks split points 50/50
*/

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
  v_checkin_points integer := 0;
  v_task_points integer := 0;
  v_has_checked_in boolean := false;
  v_staff_count integer := 0;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM check_ins
    WHERE user_id = p_user_id
    AND DATE(check_in_time) = p_date
    AND status = 'approved'
  ) INTO v_has_checked_in;

  IF v_has_checked_in THEN
    v_checkin_points := 5;
  END IF;

  v_total_points := v_total_points + v_checkin_points;

  SELECT COUNT(DISTINCT id) INTO v_staff_count
  FROM profiles
  WHERE role = 'staff';

  IF v_staff_count = 0 THEN
    RETURN v_total_points;
  END IF;

  SELECT COALESCE(SUM(
    CASE 
      WHEN assigned_to = p_user_id THEN
        CASE 
          WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
            (COALESCE(initial_points_value, points_value) / 2.0) + (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END)
          ELSE
            COALESCE(initial_points_value, points_value) + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
        END
      
      WHEN secondary_assigned_to = p_user_id THEN
        (COALESCE(initial_points_value, points_value) / 2.0) + (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END)
      
      WHEN assigned_to IS NULL THEN
        (COALESCE(initial_points_value, points_value)::numeric / v_staff_count) + 
        (CASE WHEN due_date IS NOT NULL THEN (1.0 / v_staff_count) ELSE 0 END)
      
      ELSE 0
    END
  ), 0)::integer
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status NOT IN ('completed', 'cancelled', 'archived');

  v_total_points := v_total_points + v_task_points;

  RETURN v_total_points;
END;
$$;

CREATE OR REPLACE FUNCTION calculate_team_daily_achievable_points(
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_checkin_points integer := 0;
  v_total_task_points integer := 0;
BEGIN
  SELECT COUNT(*) * 5 INTO v_total_checkin_points
  FROM check_ins
  WHERE DATE(check_in_time) = p_date
  AND status = 'approved';

  SELECT COALESCE(SUM(COALESCE(initial_points_value, points_value) + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)), 0)::integer
  INTO v_total_task_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status NOT IN ('completed', 'cancelled', 'archived')
  AND assigned_to IS NOT NULL;

  RETURN v_total_checkin_points + v_total_task_points;
END;
$$;