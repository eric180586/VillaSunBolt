/*
  # Fix Achievable Points - Use weekly_schedules Table

  1. Changes
    - Update calculate_theoretically_achievable_points to use weekly_schedules
    - Parse shifts JSONB array to determine if user works today
    - Check for 'early' or 'late' shift (not 'off')
*/

-- Drop old function
DROP FUNCTION IF EXISTS calculate_theoretically_achievable_points(uuid, date);

-- Create new function with correct schedule logic
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
  v_shift_record jsonb;
BEGIN
  -- Check if user has a shift for this date in weekly_schedules
  SELECT shift_data->>'shift' INTO v_shift_type
  FROM weekly_schedules ws,
       jsonb_array_elements(ws.shifts) AS shift_data
  WHERE ws.staff_id = p_user_id
    AND (shift_data->>'date')::date = p_date
    AND shift_data->>'shift' IN ('early', 'late')
  LIMIT 1;

  v_has_schedule := (v_shift_type IS NOT NULL);

  -- 1. Check-in points (+5 for punctuality)
  IF v_has_schedule THEN
    v_achievable_points := v_achievable_points + 5;
  END IF;

  -- 2. Unassigned tasks (everyone with schedule can potentially do them)
  IF v_has_schedule THEN
    SELECT v_achievable_points + COALESCE(SUM(t.points_value), 0) INTO v_achievable_points
    FROM tasks t
    WHERE t.assigned_to IS NULL
      AND t.is_template = false
      AND t.status NOT IN ('completed', 'archived')
      AND DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date;
  END IF;

  -- 3. Assigned tasks (only for this user)
  SELECT v_achievable_points + COALESCE(SUM(t.points_value), 0) INTO v_achievable_points
  FROM tasks t
  WHERE t.assigned_to = p_user_id
    AND t.is_template = false
    AND t.status NOT IN ('completed', 'archived')
    AND DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date;

  -- 4. Helper tasks (split points - 50% for helper)
  SELECT v_achievable_points + COALESCE(SUM(t.points_value / 2), 0) INTO v_achievable_points
  FROM tasks t
  WHERE t.helper_id = p_user_id
    AND t.is_template = false
    AND t.status NOT IN ('completed', 'archived')
    AND DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date;

  -- 5. Patrol rounds (+1 per scheduled scan)
  SELECT v_achievable_points + COALESCE(COUNT(*), 0) INTO v_achievable_points
  FROM patrol_rounds pr
  WHERE pr.assigned_to = p_user_id
    AND DATE(pr.scheduled_time AT TIME ZONE 'Asia/Phnom_Penh') = p_date
    AND pr.completed_at IS NULL;

  RETURN v_achievable_points;
END;
$$;