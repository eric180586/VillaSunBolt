/*
  # Fix Points Calculation - Final Correct Version

  ## Problems Fixed:
  1. Check-in base points always added (+5) even when late
  2. Achievable points don't account for actual check-in points earned
  3. Fortune wheel bonus points not included correctly
  4. Helper points calculation inconsistent

  ## Solution:
  - Achievable points = What user CAN earn (realistic)
  - Achieved points = What user ACTUALLY earned (from points_history)
  - Clear separation between potential and actual points
*/

-- ============================================================================
-- 1. CORRECT calculate_theoretically_achievable_points
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
  --    This is ACHIEVABLE, not necessarily what they got
  IF v_has_schedule THEN
    v_achievable_points := v_achievable_points + 5;
  END IF;

  -- 2. Tasks due TODAY or created TODAY (not overdue tasks!)
  SELECT v_achievable_points + COALESCE(SUM(
    CASE
      -- Unassigned tasks (anyone can take)
      WHEN t.assigned_to IS NULL THEN t.points_value
      -- Assigned to this user (full points)
      WHEN t.assigned_to = p_user_id THEN t.points_value
      -- Helper tasks (half points)
      WHEN t.helper_id = p_user_id THEN (t.points_value / 2)
      ELSE 0
    END
  ), 0) INTO v_achievable_points
  FROM tasks t
  WHERE t.is_template = false
    AND t.status NOT IN ('completed', 'approved', 'archived', 'cancelled')
    AND (
      -- Tasks due today
      DATE(t.due_date AT TIME ZONE 'Asia/Phnom_Penh') = p_date
      OR
      -- Tasks created today (for same-day tasks)
      DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date
    );

  -- 3. Patrol rounds scheduled for today
  SELECT v_achievable_points + COALESCE(SUM(
    CASE WHEN pr.status = 'completed' THEN 0
    ELSE 1 END
  ), 0) INTO v_achievable_points
  FROM patrol_rounds pr
  WHERE pr.assigned_to = p_user_id
    AND DATE(pr.scheduled_time AT TIME ZONE 'Asia/Phnom_Penh') = p_date;

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
'Calculates MAXIMUM points user can earn TODAY (best case scenario)';

-- ============================================================================
-- 2. SIMPLE calculate_achieved_points - Just sum points_history
-- ============================================================================
CREATE OR REPLACE FUNCTION calculate_achieved_points(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_achieved_points integer := 0;
BEGIN
  -- Sum ALL points earned on this date (including negative)
  SELECT COALESCE(SUM(points_change), 0) INTO v_achieved_points
  FROM points_history
  WHERE user_id = p_user_id
    AND DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date;

  RETURN v_achieved_points;
END;
$$;

COMMENT ON FUNCTION calculate_achieved_points IS
'Sum of all points (positive and negative) earned today from points_history';

-- ============================================================================
-- 3. NEW: Get detailed points breakdown for user
-- ============================================================================
CREATE OR REPLACE FUNCTION get_user_points_breakdown(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
  v_checkin_points int := 0;
  v_task_points int := 0;
  v_patrol_points int := 0;
  v_checklist_points int := 0;
  v_bonus_points int := 0;
  v_penalty_points int := 0;
  v_total_achieved int := 0;
  v_total_achievable int := 0;
BEGIN
  -- Get check-in points
  SELECT COALESCE(SUM(points_change), 0) INTO v_checkin_points
  FROM points_history
  WHERE user_id = p_user_id
    AND DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date
    AND category = 'check_in';

  -- Get task completion points
  SELECT COALESCE(SUM(points_change), 0) INTO v_task_points
  FROM points_history
  WHERE user_id = p_user_id
    AND DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date
    AND category IN ('task_completed', 'deadline_bonus', 'quality_bonus');

  -- Get patrol points
  SELECT COALESCE(SUM(points_change), 0) INTO v_patrol_points
  FROM points_history
  WHERE user_id = p_user_id
    AND DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date
    AND category = 'patrol_round';

  -- Get checklist points
  SELECT COALESCE(SUM(points_change), 0) INTO v_checklist_points
  FROM points_history
  WHERE user_id = p_user_id
    AND DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date
    AND category = 'checklist_completed';

  -- Get bonus points (fortune wheel, etc)
  SELECT COALESCE(SUM(points_change), 0) INTO v_bonus_points
  FROM points_history
  WHERE user_id = p_user_id
    AND DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date
    AND category = 'bonus'
    AND points_change > 0;

  -- Get penalty points
  SELECT COALESCE(SUM(points_change), 0) INTO v_penalty_points
  FROM points_history
  WHERE user_id = p_user_id
    AND DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date
    AND (
      category IN ('check_in_late', 'task_reopened', 'patrol_missed')
      OR points_change < 0
    );

  -- Total achieved
  v_total_achieved := calculate_achieved_points(p_user_id, p_date);

  -- Total achievable
  v_total_achievable := calculate_theoretically_achievable_points(p_user_id, p_date);

  -- Build result
  v_result := jsonb_build_object(
    'date', p_date,
    'achieved', v_total_achieved,
    'achievable', v_total_achievable,
    'percentage', CASE
      WHEN v_total_achievable > 0 THEN (v_total_achieved::float / v_total_achievable * 100)::int
      ELSE 0
    END,
    'breakdown', jsonb_build_object(
      'checkin', v_checkin_points,
      'tasks', v_task_points,
      'patrols', v_patrol_points,
      'checklists', v_checklist_points,
      'bonus', v_bonus_points,
      'penalties', v_penalty_points
    )
  );

  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION get_user_points_breakdown IS
'Returns detailed breakdown of user points for a specific date';

-- Grant permissions
GRANT EXECUTE ON FUNCTION calculate_theoretically_achievable_points TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_achieved_points TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_points_breakdown TO authenticated;
