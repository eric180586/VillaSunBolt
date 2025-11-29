/*
  # Fix Achievable Points - Remove Unassigned Tasks

  ## THE PROBLEM:
  Unassigned tasks were counting towards individual user's "achievable" points.

  ## WHY THIS IS WRONG:
  - Unassigned tasks are NOT assigned to you
  - You CAN take them (optional), but they're not YOUR responsibility
  - Only when you ACCEPT them, they become assigned to you

  ## THE FIX:
  Remove the logic that adds unassigned tasks to achievable calculation.

  ## CORRECT LOGIC:
  Your achievable points =
    + Check-in bonus (5 points)
    + Tasks assigned_to = you (full points)
    + Tasks helper_id = you (half points)
    + Patrol rounds assigned to you
    + Checklist instances assigned to you

  ## EXAMPLE BEFORE FIX:
  - Morning: 10 unassigned tasks (120 points)
  - Your assigned tasks: 2 (20 points)
  - Achievable shown: 145 points (WRONG! You're not responsible for unassigned)

  ## EXAMPLE AFTER FIX:
  - Morning: achievable = 25 points (5 check-in + 20 your tasks)
  - You take unassigned task → achievable increases to 37
  - You complete it → 12 points earned
  - This is CORRECT behavior!

  ## NOTE FOR HISTORICAL DATES:
  For past dates, we use points_history (unchanged).
  This fix only affects TODAY's calculation.
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

    -- If no positive history, check if user had penalties only
    IF EXISTS(
      SELECT 1 FROM points_history ph
      WHERE ph.user_id = p_user_id
        AND DATE(ph.created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date
        AND ph.points_change < 0
    ) THEN
      -- User had penalties but no positive points
      -- They could have earned the check-in bonus (5) but got penalty instead
      RETURN 5;
    END IF;

    -- No history at all = no shift = 0 achievable
    RETURN 0;
  END IF;

  -- ========================================
  -- FOR TODAY: Calculate from current data
  -- ========================================

  -- 1. Check-in bonus (+5 for punctuality)
  v_achievable_points := v_achievable_points + 5;

  -- 2. TASKS - ONLY ASSIGNED OR HELPER TASKS
  -- REMOVED: Unassigned tasks logic!
  SELECT v_achievable_points + COALESCE(SUM(
    CASE
      WHEN t.assigned_to = p_user_id THEN t.points_value
      WHEN t.helper_id = p_user_id THEN t.points_value / 2
      ELSE 0
    END
  ), 0) INTO v_achievable_points
  FROM tasks t
  WHERE t.is_template = false
    AND t.status NOT IN ('completed', 'approved', 'archived', 'cancelled')
    AND (
      t.assigned_to = p_user_id
      OR t.helper_id = p_user_id
    );

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
'Calculates achievable points for a user on a specific date. Only counts tasks ASSIGNED to the user, not unassigned tasks. For historical dates, uses points_history as source of truth.';
