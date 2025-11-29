/*
  # Fix Points Calculation - Patrol Rounds Column

  ## Problem:
  The calculate_theoretically_achievable_points function references pr.status
  but patrol_rounds table uses completed_at instead.

  ## Solution:
  Update function to check completed_at IS NULL instead of status
*/

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
  v_shift_type text := NULL;
  v_has_checked_in boolean := false;
BEGIN
  -- Check if user has a shift for this date in weekly_schedules
  SELECT shift_data->>'shift' INTO v_shift_type
  FROM weekly_schedules ws,
    jsonb_array_elements(ws.shifts) AS shift_data
  WHERE ws.staff_id = p_user_id
    AND (shift_data->>'date')::date = p_date
    AND shift_data->>'shift' IN ('early', 'late', 'morning')
  LIMIT 1;

  v_has_schedule := (v_shift_type IS NOT NULL);

  -- Check if user has checked in on this date
  SELECT EXISTS(
    SELECT 1 FROM check_ins
    WHERE user_id = p_user_id
    AND check_in_date = p_date
  ) INTO v_has_checked_in;

  -- If no schedule AND no check-in, user can't earn points today
  IF NOT v_has_schedule AND NOT v_has_checked_in THEN
    RETURN 0;
  END IF;

  -- 1. Check-in points - BEST CASE scenario (on time = +5)
  IF v_has_schedule THEN
    v_achievable_points := v_achievable_points + 5;
  END IF;

  -- 2. Tasks due TODAY or created TODAY
  SELECT v_achievable_points + COALESCE(SUM(
    CASE
      WHEN t.assigned_to IS NULL THEN t.points_value
      WHEN t.assigned_to = p_user_id THEN t.points_value
      WHEN t.helper_id = p_user_id THEN (t.points_value / 2)
      ELSE 0
    END
  ), 0) INTO v_achievable_points
  FROM tasks t
  WHERE t.is_template = false
    AND t.status NOT IN ('completed', 'approved', 'archived', 'cancelled')
    AND (
      DATE(t.due_date AT TIME ZONE 'Asia/Phnom_Penh') = p_date
      OR
      DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date
    );

  -- 3. Patrol rounds scheduled for today (completed_at IS NULL = not done yet)
  SELECT v_achievable_points + COALESCE(COUNT(*), 0) INTO v_achievable_points
  FROM patrol_rounds pr
  WHERE pr.assigned_to = p_user_id
    AND pr.date = p_date
    AND pr.completed_at IS NULL;

  -- 4. Checklist instances for today
  SELECT v_achievable_points + COALESCE(SUM(
    CASE WHEN ci.status IN ('completed', 'approved') THEN 0
    ELSE COALESCE(ci.points_awarded, 10) END
  ), 0) INTO v_achievable_points
  FROM checklist_instances ci
  WHERE ci.assigned_to = p_user_id
    AND ci.instance_date = p_date;

  RETURN v_achievable_points;
END;
$$;

COMMENT ON FUNCTION calculate_theoretically_achievable_points IS
'Calculates MAXIMUM points user can earn TODAY (best case scenario) - FIXED patrol_rounds';
