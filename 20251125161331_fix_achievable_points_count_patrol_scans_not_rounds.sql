/*
  # Fix Patrol Points - Count Expected Scans, Not Rounds

  ## Problem
  - System awards 1 point per SCAN
  - But achievable counts number of ROUNDS (1 point per round)
  - Inconsistency: If 5 rounds with 3 locations each = 15 possible points
    But achievable only counted 5 points!

  ## Solution
  - Achievable = Number of Rounds × Number of Locations to scan
  - This matches the actual points that CAN be earned

  ## Example
  - 5 patrol rounds scheduled
  - 3 locations to scan per round
  - Achievable = 5 × 3 = 15 patrol points
  - User scans 8 locations = 8 points earned
  - Percentage = 8/15 = 53% ✅
*/

-- ============================================================================
-- Fix calculate_theoretically_achievable_points - Count expected scans
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
  -- Check if user has a shift for this date in weekly_schedules
  SELECT shift_data->>'shift' INTO v_shift_type
  FROM weekly_schedules ws,
    jsonb_array_elements(ws.shifts) AS shift_data
  WHERE ws.staff_id = p_user_id
    AND (shift_data->>'date')::date = p_date
    AND shift_data->>'shift' IN ('early', 'late')
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

  -- 1. Check-in points (+5 for punctuality)
  v_achievable_points := v_achievable_points + 5;

  -- 2. Tasks due TODAY or created TODAY (not overdue tasks!)
  SELECT v_achievable_points + COALESCE(SUM(
    CASE 
      -- Unassigned tasks
      WHEN t.assigned_to IS NULL THEN t.points_value
      -- Assigned to this user
      WHEN t.assigned_to = p_user_id THEN t.points_value
      -- Helper tasks (half points)
      WHEN t.helper_id = p_user_id THEN t.points_value / 2
      ELSE 0
    END
  ), 0) INTO v_achievable_points
  FROM tasks t
  WHERE t.is_template = false
    AND t.status NOT IN ('completed', 'approved', 'archived', 'cancelled')
    AND (
      -- Tasks due today
      t.due_date::date = p_date
      OR
      -- Tasks created today without due_date
      (t.due_date IS NULL AND DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date)
    );

  -- 3. Patrol rounds - COUNT EXPECTED SCANS, NOT ROUNDS!
  -- Each patrol round requires scanning all locations
  -- So points = number_of_rounds × number_of_locations
  
  -- Get total number of locations in the system
  SELECT COUNT(*) INTO v_num_locations FROM patrol_locations;
  
  -- Get number of patrol rounds scheduled for today
  SELECT COUNT(*) INTO v_patrol_rounds
  FROM patrol_rounds pr
  WHERE pr.assigned_to = p_user_id
    AND DATE(pr.scheduled_time AT TIME ZONE 'Asia/Phnom_Penh') = p_date
    AND pr.completed_at IS NULL;
  
  -- Add expected scan points (rounds × locations)
  v_achievable_points := v_achievable_points + (v_patrol_rounds * v_num_locations);

  -- 4. Checklist instances for today only
  SELECT v_achievable_points + COALESCE(SUM(ci.points_awarded), 0) INTO v_achievable_points
  FROM checklist_instances ci
  WHERE ci.assigned_to = p_user_id
    AND ci.instance_date = p_date
    AND ci.status NOT IN ('completed', 'approved', 'archived');

  RETURN v_achievable_points;
END;
$$;

COMMENT ON FUNCTION calculate_theoretically_achievable_points IS 
'Calculates achievable points including EXPECTED patrol scans (rounds × locations)';

-- ============================================================================
-- Add helper function to see patrol breakdown
-- ============================================================================

CREATE OR REPLACE FUNCTION get_patrol_breakdown(
  p_user_id uuid, 
  p_date date DEFAULT CURRENT_DATE
)
RETURNS TABLE(
  scheduled_rounds integer,
  locations_per_round integer,
  expected_scans integer,
  actual_scans integer,
  percentage numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_num_locations integer;
  v_scheduled_rounds integer;
  v_actual_scans integer;
BEGIN
  -- Get number of locations
  SELECT COUNT(*) INTO v_num_locations FROM patrol_locations;
  
  -- Get scheduled rounds for today
  SELECT COUNT(*) INTO v_scheduled_rounds
  FROM patrol_rounds pr
  WHERE pr.assigned_to = p_user_id
    AND DATE(pr.scheduled_time AT TIME ZONE 'Asia/Phnom_Penh') = p_date;
  
  -- Get actual scans done (only for today's rounds)
  SELECT COUNT(*) INTO v_actual_scans
  FROM patrol_scans ps
  JOIN patrol_rounds pr ON pr.id = ps.patrol_round_id
  WHERE pr.assigned_to = p_user_id
    AND DATE(pr.scheduled_time AT TIME ZONE 'Asia/Phnom_Penh') = p_date;
  
  RETURN QUERY
  SELECT 
    v_scheduled_rounds,
    v_num_locations,
    v_scheduled_rounds * v_num_locations as expected_scans,
    v_actual_scans,
    CASE 
      WHEN v_scheduled_rounds * v_num_locations > 0 
      THEN (v_actual_scans::numeric / (v_scheduled_rounds * v_num_locations)::numeric * 100)
      ELSE 0
    END as percentage;
END;
$$;

COMMENT ON FUNCTION get_patrol_breakdown IS 
'Shows detailed breakdown of patrol expectations vs actual scans';
