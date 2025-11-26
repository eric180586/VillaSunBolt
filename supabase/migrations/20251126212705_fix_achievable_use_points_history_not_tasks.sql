/*
  # Fix Achievable Points - Use Points History Instead of Tasks Table

  ## THE ROOT PROBLEM:
  Tasks get deleted/archived, so we can't reconstruct historical "achievable" 
  from the tasks table!

  ## NEW APPROACH:
  - For CURRENT date: Use tasks table (as before)
  - For HISTORICAL dates: Use points_history to see what user COULD have done
  
  ## Logic for Historical:
  If user got points for something, it was achievable!
  - Sum positive points from points_history (what they could earn)
  - Ignore negative points (penalties don't count as "achievable")

  ## Example (Sopheaktra 22.11):
  points_history shows:
  - check_in: +5
  - task_completed: +9
  - task_completed: +15
  Total achievable: 5 + 9 + 15 = 29

  This matches reality: She COULD earn these points, and she DID!
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
  ) INTO v_has_checked_in;

  -- If no schedule AND no check-in, user can't earn points
  IF NOT v_has_schedule AND NOT v_has_checked_in THEN
    RETURN 0;
  END IF;

  -- ========================================
  -- FOR HISTORICAL DATES: Use points_history
  -- ========================================
  IF NOT v_is_today THEN
    -- Sum all POSITIVE points from history (what user could earn)
    SELECT COALESCE(SUM(
      CASE 
        WHEN ph.points_change > 0 THEN ph.points_change
        ELSE 0
      END
    ), 0) INTO v_achievable_points
    FROM points_history ph
    WHERE ph.user_id = p_user_id
      AND DATE(ph.created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date;

    -- If we have history data, use it
    IF v_achievable_points > 0 THEN
      RETURN v_achievable_points;
    END IF;

    -- Otherwise fall through to estimated calculation below
  END IF;

  -- ========================================
  -- FOR TODAY OR IF NO HISTORY: Calculate from current data
  -- ========================================

  -- 1. Check-in bonus (+5 for punctuality)
  v_achievable_points := v_achievable_points + 5;

  -- 2. TASKS
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

  -- 3. Patrol rounds
  SELECT COUNT(*) INTO v_num_locations FROM patrol_locations;
  
  SELECT COUNT(*) INTO v_patrol_rounds
  FROM patrol_rounds pr
  WHERE pr.assigned_to = p_user_id
    AND DATE(pr.scheduled_time AT TIME ZONE 'Asia/Phnom_Penh') = p_date;
  
  v_achievable_points := v_achievable_points + (v_patrol_rounds * v_num_locations);

  -- 4. Checklist instances
  SELECT v_achievable_points + COALESCE(SUM(ci.points_awarded), 0) INTO v_achievable_points
  FROM checklist_instances ci
  WHERE ci.assigned_to = p_user_id
    AND ci.instance_date = p_date
    AND ci.status NOT IN ('completed', 'approved', 'archived');

  RETURN v_achievable_points;
END;
$$;

COMMENT ON FUNCTION calculate_theoretically_achievable_points IS 
'Calculates achievable points. For historical dates, uses points_history (source of truth). For today, estimates from current tasks.';
