/*
  # Fix Achievable Points - Historical Calculation

  ## THE REAL PROBLEM:
  When calculating achievable points for a PAST date (e.g., 2025-11-22),
  we need to count tasks that:
  1. Were OPEN at the start of that day
  2. Got COMPLETED/APPROVED during that day
  
  Currently we only count tasks that are STILL open NOW, which is WRONG!

  ## Solution:
  For historical dates, count tasks where:
  - Task was created BEFORE or ON that date
  - Task was completed/approved ON that date (or still open)
  - This means: "What COULD the user do on that day?"

  ## Example (Sopheaktra 22.11.2025):
  - Task "clean metal" created before 22.11
  - Task completed on 22.11 → 9 points
  - Should be counted in achievable!
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
  v_num_locations integer;
  v_patrol_rounds integer;
  v_is_today boolean;
BEGIN
  v_is_today := (p_date = CURRENT_DATE);

  -- Check if user has a shift for this date
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
    AND status = 'approved'
  ) INTO v_has_checked_in;

  -- If no schedule AND no check-in, user can't earn points
  IF NOT v_has_schedule AND NOT v_has_checked_in THEN
    RETURN 0;
  END IF;

  -- 1. Check-in bonus (+5 for punctuality)
  v_achievable_points := v_achievable_points + 5;

  -- 2. TASKS - Different logic for TODAY vs HISTORICAL
  IF v_is_today THEN
    -- FOR TODAY: Count all open tasks (including overdue)
    SELECT v_achievable_points + COALESCE(SUM(
      CASE 
        WHEN t.assigned_to IS NULL AND (
          t.due_date::date = p_date OR 
          (t.due_date IS NULL AND DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date)
        ) THEN t.points_value
        WHEN t.assigned_to = p_user_id THEN t.points_value
        WHEN t.helper_id = p_user_id THEN t.points_value / 2
        ELSE 0
      END
    ), 0) INTO v_achievable_points
    FROM tasks t
    WHERE t.is_template = false
      AND t.status NOT IN ('completed', 'approved', 'archived', 'cancelled');
  ELSE
    -- FOR HISTORICAL: Count tasks that existed and were completable on that date
    SELECT v_achievable_points + COALESCE(SUM(
      CASE 
        -- Unassigned tasks created on this date
        WHEN t.assigned_to IS NULL AND (
          t.due_date::date = p_date OR 
          (t.due_date IS NULL AND DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date)
        ) THEN t.points_value
        -- Assigned tasks: created before/on date AND (completed on date OR still open)
        WHEN t.assigned_to = p_user_id 
          AND DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') <= p_date
          AND (
            t.status NOT IN ('completed', 'approved', 'archived', 'cancelled')
            OR DATE(t.completed_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date
            OR DATE(t.reviewed_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date
          )
        THEN t.points_value
        -- Helper tasks
        WHEN t.helper_id = p_user_id 
          AND DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') <= p_date
          AND (
            t.status NOT IN ('completed', 'approved', 'archived', 'cancelled')
            OR DATE(t.completed_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date
            OR DATE(t.reviewed_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date
          )
        THEN t.points_value / 2
        ELSE 0
      END
    ), 0) INTO v_achievable_points
    FROM tasks t
    WHERE t.is_template = false;
  END IF;

  -- 3. Patrol rounds - COUNT EXPECTED SCANS
  SELECT COUNT(*) INTO v_num_locations FROM patrol_locations;
  
  SELECT COUNT(*) INTO v_patrol_rounds
  FROM patrol_rounds pr
  WHERE pr.assigned_to = p_user_id
    AND DATE(pr.scheduled_time AT TIME ZONE 'Asia/Phnom_Penh') = p_date;
  
  v_achievable_points := v_achievable_points + (v_patrol_rounds * v_num_locations);

  -- 4. Checklist instances
  IF v_is_today THEN
    SELECT v_achievable_points + COALESCE(SUM(ci.points_awarded), 0) INTO v_achievable_points
    FROM checklist_instances ci
    WHERE ci.assigned_to = p_user_id
      AND ci.instance_date = p_date
      AND ci.status NOT IN ('completed', 'approved', 'archived');
  ELSE
    SELECT v_achievable_points + COALESCE(SUM(ci.points_awarded), 0) INTO v_achievable_points
    FROM checklist_instances ci
    WHERE ci.assigned_to = p_user_id
      AND ci.instance_date = p_date;
  END IF;

  RETURN v_achievable_points;
END;
$$;

COMMENT ON FUNCTION calculate_theoretically_achievable_points IS 
'Calculates achievable points correctly for both TODAY and HISTORICAL dates. Historical: counts tasks that existed and were completable on that date.';
