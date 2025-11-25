/*
  # Fix Achievable Points - Count Tasks Even Without Schedule

  1. Problem
    - Function only counts tasks if user has a schedule
    - But users can check-in and do tasks even without published schedule
    - This causes "34 of 0" - user has 34 points but 0 shown as achievable
    
  2. Solution
    - Always count assigned tasks (regardless of schedule)
    - Always count helper tasks (regardless of schedule)
    - Only check-in bonus requires schedule
    - Unassigned tasks still require schedule (only staff on duty can take them)
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
    AND shift_data->>'shift' IN ('early', 'late')
  LIMIT 1;

  v_has_schedule := (v_shift_type IS NOT NULL);
  
  -- Check if user has checked in today (even without schedule)
  SELECT EXISTS(
    SELECT 1 FROM check_ins
    WHERE user_id = p_user_id
    AND check_in_date = p_date
  ) INTO v_has_checked_in;

  -- 1. Check-in points (+5 for punctuality if has schedule OR already checked in)
  IF v_has_schedule OR v_has_checked_in THEN
    v_achievable_points := v_achievable_points + 5;
  END IF;

  -- 2. Unassigned tasks (only if has schedule - must be on duty to take them)
  IF v_has_schedule THEN
    SELECT v_achievable_points + COALESCE(SUM(t.points_value), 0) INTO v_achievable_points
    FROM tasks t
    WHERE t.assigned_to IS NULL
      AND t.is_template = false
      AND t.status NOT IN ('completed', 'archived')
      AND (
        t.due_date::date = p_date
        OR
        (t.due_date IS NULL AND DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') <= p_date)
      );
  END IF;

  -- 3. Tasks assigned to this user (ALWAYS count, even without schedule!)
  SELECT v_achievable_points + COALESCE(SUM(t.points_value), 0) INTO v_achievable_points
  FROM tasks t
  WHERE t.assigned_to = p_user_id
    AND t.is_template = false
    AND t.status NOT IN ('completed', 'archived')
    AND (
      t.due_date::date = p_date
      OR
      (t.due_date IS NULL AND DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') <= p_date)
    );

  -- 4. Helper tasks (ALWAYS count, even without schedule!)
  SELECT v_achievable_points + COALESCE(SUM(t.points_value / 2), 0) INTO v_achievable_points
  FROM tasks t
  WHERE t.helper_id = p_user_id
    AND t.is_template = false
    AND t.status NOT IN ('completed', 'archived')
    AND (
      t.due_date::date = p_date
      OR
      (t.due_date IS NULL AND DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') <= p_date)
    );

  -- 5. Patrol rounds scheduled for today (ALWAYS count if assigned)
  SELECT v_achievable_points + COALESCE(COUNT(*), 0) INTO v_achievable_points
  FROM patrol_rounds pr
  WHERE pr.assigned_to = p_user_id
    AND DATE(pr.scheduled_time AT TIME ZONE 'Asia/Phnom_Penh') = p_date
    AND pr.completed_at IS NULL;

  -- 6. Checklist instances for today (ALWAYS count if assigned)
  SELECT v_achievable_points + COALESCE(SUM(ci.points_awarded), 0) INTO v_achievable_points
  FROM checklist_instances ci
  WHERE ci.assigned_to = p_user_id
    AND ci.instance_date = p_date
    AND ci.status NOT IN ('completed', 'approved', 'archived');

  RETURN v_achievable_points;
END;
$$;