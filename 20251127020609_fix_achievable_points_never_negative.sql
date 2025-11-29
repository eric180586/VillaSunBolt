/*
  # Fix Achievable Points - Never Allow Negative Values

  ## THE PROBLEM:
  Achievable points can become negative when penalties are very high.
  Example: User checks in 580 minutes late = -116 points penalty
  
  But "achievable" means "what you COULD earn" - this should never be negative!
  Penalties don't reduce what's achievable, they just reduce what you achieved.

  ## THE FIX:
  Ensure achievable points are always >= 0 (at minimum 0).
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

  -- 3. Patrol rounds scheduled for today only
  SELECT v_achievable_points + COALESCE(COUNT(*), 0) INTO v_achievable_points
  FROM patrol_rounds pr
  WHERE pr.assigned_to = p_user_id
    AND DATE(pr.scheduled_time AT TIME ZONE 'Asia/Phnom_Penh') = p_date
    AND pr.completed_at IS NULL;

  -- 4. Checklist instances for today only
  SELECT v_achievable_points + COALESCE(SUM(ci.points_awarded), 0) INTO v_achievable_points
  FROM checklist_instances ci
  WHERE ci.assigned_to = p_user_id
    AND ci.instance_date = p_date
    AND ci.status NOT IN ('completed', 'approved', 'archived');

  -- CRITICAL: Achievable points can never be negative!
  -- Penalties reduce "achieved", not "achievable"
  IF v_achievable_points < 0 THEN
    v_achievable_points := 0;
  END IF;

  RETURN v_achievable_points;
END;
$$;

COMMENT ON FUNCTION calculate_theoretically_achievable_points IS 
'Calculates ONLY points that can be earned TODAY - never negative (penalties reduce achieved, not achievable)';
