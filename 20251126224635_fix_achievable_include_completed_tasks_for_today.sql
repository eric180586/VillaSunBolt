/*
  # Fix Achievable - Include Completed Tasks for Today

  ## THE PROBLEM:
  When a task is completed, it gets excluded from achievable calculation.
  This causes achievable to DECREASE when tasks are completed - which is wrong!

  ## CORRECT BEHAVIOR:
  Achievable = "what you COULD earn today"
  Once a task is assigned to you, it's part of your achievable - EVEN AFTER completion!

  ## EXAMPLE:
  08:00 - achievable = 20 (5 check-in + 15 tasks)
  10:00 - Accept unassigned task (12 points)
          achievable = 32 ✅
  12:00 - Complete the task
          achievable = 32 ✅ (NOT 20!)
  14:00 - Admin approves
          achievable = 32 ✅ (stays the same!)
          achieved = 12
          percentage = 37.5% (12/32)

  ## THE FIX:
  For TODAY: Include completed/approved tasks in achievable
  For HISTORICAL: Use points_history (unchanged)
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

  -- 2. TASKS - Include ALL tasks (even completed/approved)
  -- Because once assigned to you, they're part of your achievable!
  SELECT v_achievable_points + COALESCE(SUM(
    CASE
      WHEN t.assigned_to = p_user_id THEN t.points_value
      WHEN t.helper_id = p_user_id THEN t.points_value / 2
      ELSE 0
    END
  ), 0) INTO v_achievable_points
  FROM tasks t
  WHERE t.is_template = false
    AND t.status NOT IN ('archived', 'cancelled')  -- Only exclude archived/cancelled
    AND (
      t.assigned_to = p_user_id
      OR t.helper_id = p_user_id
    )
    AND (
      -- Task is for today
      DATE(t.due_date) = p_date
      OR (t.due_date IS NULL AND DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date)
      -- Or task was completed today
      OR (t.completed_at IS NOT NULL AND DATE(t.completed_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date)
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
    AND ci.status NOT IN ('archived');  -- Include completed checklists!

  RETURN v_achievable_points;
END;
$$;

COMMENT ON FUNCTION calculate_theoretically_achievable_points IS
'Calculates achievable points. For today: includes all tasks (even completed), because achievable should not decrease. For historical: uses points_history.';
