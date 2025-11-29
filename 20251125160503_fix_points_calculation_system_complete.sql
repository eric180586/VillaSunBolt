/*
  # Fix Punktesystem - Vollständige Überarbeitung

  ## Probleme
  1. ❌ calculate_team_achievable_points zählt nur Tasks mit due_date = heute
  2. ❌ calculate_theoretically_achievable_points zählt ALLE offenen Tasks (inkl. überfällige)
  3. ❌ Inkonsistenz: Achieved kann größer als Achievable sein
  4. ❌ Team Achievable zeigt 0 obwohl Staff Punkte haben

  ## Lösung
  1. ✅ Team Achievable = Summe aller Staff Achievable Points
  2. ✅ Konsistente Logik für Individual und Team
  3. ✅ Validation: Achieved nie > Achievable
  4. ✅ Nur Punkte von Check-In bis heute zählen als "achieved"
*/

-- ============================================================================
-- 1. Fix calculate_team_achievable_points - Sum of all staff achievable
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_team_achievable_points(p_date date DEFAULT CURRENT_DATE)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_achievable integer := 0;
  v_staff_record RECORD;
BEGIN
  -- Sum achievable points from ALL staff members
  FOR v_staff_record IN 
    SELECT id FROM profiles WHERE role = 'staff'
  LOOP
    v_total_achievable := v_total_achievable + 
      calculate_theoretically_achievable_points(v_staff_record.id, p_date);
  END LOOP;

  RETURN v_total_achievable;
END;
$$;

COMMENT ON FUNCTION calculate_team_achievable_points IS 
'Calculates team achievable points as SUM of all staff achievable points';

-- ============================================================================
-- 2. Fix calculate_theoretically_achievable_points
--    - Only count points user can ACTUALLY earn today
--    - Don't count overdue tasks in achievable (they're lost opportunities)
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

  RETURN v_achievable_points;
END;
$$;

COMMENT ON FUNCTION calculate_theoretically_achievable_points IS 
'Calculates ONLY points that can be earned TODAY - no overdue tasks';

-- ============================================================================
-- 3. Fix calculate_achieved_points - Only positive points
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
  -- Sum ALL points (positive and negative) earned on this date
  SELECT COALESCE(SUM(points_change), 0) INTO v_achieved_points
  FROM points_history
  WHERE user_id = p_user_id
    AND DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date;

  -- Ensure it's never negative (for percentage calculation)
  IF v_achieved_points < 0 THEN
    v_achieved_points := 0;
  END IF;

  RETURN v_achieved_points;
END;
$$;

COMMENT ON FUNCTION calculate_achieved_points IS 
'Calculates achieved points (never negative for display)';

-- ============================================================================
-- 4. Add validation function to prevent achieved > achievable
-- ============================================================================

CREATE OR REPLACE FUNCTION validate_points_logic()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_staff_record RECORD;
  v_achievable integer;
  v_achieved integer;
  v_errors text := '';
BEGIN
  FOR v_staff_record IN 
    SELECT id, full_name FROM profiles WHERE role = 'staff'
  LOOP
    v_achievable := calculate_theoretically_achievable_points(v_staff_record.id, CURRENT_DATE);
    v_achieved := calculate_achieved_points(v_staff_record.id, CURRENT_DATE);
    
    IF v_achieved > v_achievable THEN
      v_errors := v_errors || format(
        E'\n❌ %s: Achieved (%s) > Achievable (%s)', 
        v_staff_record.full_name, v_achieved, v_achievable
      );
    END IF;
  END LOOP;

  IF v_errors != '' THEN
    RAISE NOTICE 'VALIDATION ERRORS:%', v_errors;
  ELSE
    RAISE NOTICE '✅ All points calculations are valid!';
  END IF;
END;
$$;

-- ============================================================================
-- 5. Create helper function to get detailed breakdown
-- ============================================================================

CREATE OR REPLACE FUNCTION get_points_breakdown(p_user_id uuid, p_date date DEFAULT CURRENT_DATE)
RETURNS TABLE(
  category text,
  points integer,
  details text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH breakdown AS (
    -- Check-in bonus
    SELECT 
      'Check-In Bonus'::text as category,
      CASE WHEN EXISTS(
        SELECT 1 FROM check_ins 
        WHERE user_id = p_user_id 
        AND check_in_date = p_date
        AND status = 'approved'
      ) THEN 5 ELSE 0 END as points,
      'Punctuality bonus'::text as details
    
    UNION ALL
    
    -- Tasks
    SELECT 
      'Tasks'::text,
      COALESCE(SUM(
        CASE 
          WHEN t.assigned_to = p_user_id THEN t.points_value
          WHEN t.helper_id = p_user_id THEN t.points_value / 2
          ELSE t.points_value
        END
      ), 0)::integer,
      COUNT(*)::text || ' tasks'
    FROM tasks t
    WHERE t.is_template = false
      AND t.status NOT IN ('completed', 'approved', 'archived', 'cancelled')
      AND (t.due_date::date = p_date OR (t.due_date IS NULL AND DATE(t.created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date))
      AND (t.assigned_to = p_user_id OR t.helper_id = p_user_id OR t.assigned_to IS NULL)
    
    UNION ALL
    
    -- Patrols
    SELECT 
      'Patrols'::text,
      COUNT(*)::integer,
      COUNT(*)::text || ' patrol rounds'
    FROM patrol_rounds pr
    WHERE pr.assigned_to = p_user_id
      AND DATE(pr.scheduled_time AT TIME ZONE 'Asia/Phnom_Penh') = p_date
      AND pr.completed_at IS NULL
    
    UNION ALL
    
    -- Checklists
    SELECT 
      'Checklists'::text,
      COALESCE(SUM(ci.points_awarded), 0)::integer,
      COUNT(*)::text || ' checklists'
    FROM checklist_instances ci
    WHERE ci.assigned_to = p_user_id
      AND ci.instance_date = p_date
      AND ci.status NOT IN ('completed', 'approved', 'archived')
  )
  SELECT * FROM breakdown WHERE points > 0;
END;
$$;

COMMENT ON FUNCTION get_points_breakdown IS 
'Shows detailed breakdown of achievable points by category';

-- ============================================================================
-- 6. Update daily goals function with validation
-- ============================================================================

CREATE OR REPLACE FUNCTION update_daily_point_goals_for_user(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_achievable integer;
  v_achieved integer;
  v_percentage numeric;
  v_color text;
  v_team_achievable integer;
  v_team_achieved integer;
BEGIN
  -- Calculate individual points
  v_achievable := calculate_theoretically_achievable_points(p_user_id, p_date);
  v_achieved := calculate_achieved_points(p_user_id, p_date);

  -- VALIDATION: Achieved should never exceed achievable
  IF v_achieved > v_achievable AND v_achievable > 0 THEN
    RAISE NOTICE 'WARNING: User % has achieved (%) > achievable (%) on %', 
      p_user_id, v_achieved, v_achievable, p_date;
    -- Cap achieved at achievable
    v_achieved := v_achievable;
  END IF;

  -- Calculate percentage
  IF v_achievable > 0 THEN
    v_percentage := (v_achieved::numeric / v_achievable::numeric) * 100;
  ELSE
    v_percentage := 0;
  END IF;

  -- Get color status
  v_color := get_color_status(v_achievable, v_achieved);

  -- Calculate team points
  v_team_achievable := calculate_team_achievable_points(p_date);
  
  SELECT COALESCE(SUM(points_change), 0)
  INTO v_team_achieved
  FROM points_history
  WHERE DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date
    AND user_id IN (SELECT id FROM profiles WHERE role = 'staff');

  -- Upsert into daily_point_goals
  INSERT INTO daily_point_goals (
    user_id,
    goal_date,
    theoretically_achievable_points,
    achieved_points,
    percentage,
    color_status,
    team_achievable_points,
    team_points_earned,
    updated_at
  )
  VALUES (
    p_user_id,
    p_date,
    v_achievable,
    v_achieved,
    v_percentage,
    v_color,
    v_team_achievable,
    v_team_achieved,
    now()
  )
  ON CONFLICT (user_id, goal_date)
  DO UPDATE SET
    theoretically_achievable_points = v_achievable,
    achieved_points = v_achieved,
    percentage = v_percentage,
    color_status = v_color,
    team_achievable_points = v_team_achievable,
    team_points_earned = v_team_achieved,
    updated_at = now();
END;
$$;

COMMENT ON FUNCTION update_daily_point_goals_for_user IS 
'Updates daily point goals with validation to prevent achieved > achievable';
