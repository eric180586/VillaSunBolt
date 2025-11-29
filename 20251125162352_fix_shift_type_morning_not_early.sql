/*
  # Fix Shift Type Recognition - "morning" not "early"

  ## Critical Bug
  - System uses shift type "morning" in weekly_schedules
  - But calculate_theoretically_achievable_points checks for "early"
  - Result: Staff with "morning" shifts get 0 achievable points!

  ## Found Shift Types
  - "morning" - 40 entries (MAIN shift type)
  - "late" - 10 entries
  - "off" - 13 entries (day off)

  ## Fix
  Change all instances of 'early' to 'morning' in point calculations
*/

-- ============================================================================
-- Fix calculate_theoretically_achievable_points
-- ============================================================================

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
BEGIN
  -- Check if user has a shift for this date
  -- FIXED: Check for 'morning' and 'late', not 'early' and 'late'!
  SELECT shift_data->>'shift' INTO v_shift_type
  FROM weekly_schedules ws,
    jsonb_array_elements(ws.shifts) AS shift_data
  WHERE ws.staff_id = p_user_id
    AND (shift_data->>'date')::date = p_date
    AND shift_data->>'shift' IN ('morning', 'late')  -- FIXED: was 'early', 'late'
  LIMIT 1;

  v_has_schedule := (v_shift_type IS NOT NULL);

  -- Check if user has checked in on this date
  SELECT EXISTS(
    SELECT 1 FROM check_ins
    WHERE user_id = p_user_id
    AND check_in_date = p_date
    AND status = 'approved'
  ) INTO v_has_checked_in;

  -- If no schedule AND no check-in, user can't earn points today
  IF NOT v_has_schedule AND NOT v_has_checked_in THEN
    RETURN 0;
  END IF;

  -- 1. Check-in bonus (+5 for punctuality)
  v_achievable_points := v_achievable_points + 5;

  -- 2. ALL OPEN TASKS (including overdue!)
  SELECT v_achievable_points + COALESCE(SUM(
    CASE 
      -- Unassigned tasks (only from today)
      WHEN t.assigned_to IS NULL AND (
        t.due_date::date = p_date OR 
        (t.due_date IS NULL AND DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date)
      ) THEN t.points_value
      -- Assigned to this user (ANY open task!)
      WHEN t.assigned_to = p_user_id THEN t.points_value
      -- Helper tasks (half points)
      WHEN t.helper_id = p_user_id THEN t.points_value / 2
      ELSE 0
    END
  ), 0) INTO v_achievable_points
  FROM tasks t
  WHERE t.is_template = false
    AND t.status NOT IN ('completed', 'approved', 'archived', 'cancelled');

  -- 3. Patrol rounds - COUNT EXPECTED SCANS
  SELECT COUNT(*) INTO v_num_locations FROM patrol_locations;
  
  SELECT COUNT(*) INTO v_patrol_rounds
  FROM patrol_rounds pr
  WHERE pr.assigned_to = p_user_id
    AND DATE(pr.scheduled_time AT TIME ZONE 'Asia/Phnom_Penh') = p_date
    AND pr.completed_at IS NULL;
  
  v_achievable_points := v_achievable_points + (v_patrol_rounds * v_num_locations);

  -- 4. Checklist instances for today
  SELECT v_achievable_points + COALESCE(SUM(ci.points_awarded), 0) INTO v_achievable_points
  FROM checklist_instances ci
  WHERE ci.assigned_to = p_user_id
    AND ci.instance_date = p_date
    AND ci.status NOT IN ('completed', 'approved', 'archived');

  RETURN v_achievable_points;
END;
$$;

COMMENT ON FUNCTION calculate_theoretically_achievable_points IS 
'Calculates achievable points. FIXED: Recognizes "morning" shift (not "early")';

-- ============================================================================
-- Also check and fix process_check_in if it has same issue
-- ============================================================================

-- Note: We should search for all functions that check shift types
-- and ensure they all use 'morning' and 'late', not 'early' and 'late'
