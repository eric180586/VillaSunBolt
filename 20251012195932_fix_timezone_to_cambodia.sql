/*
  # Zeitzone auf Kambodscha (Asia/Phnom_Penh) umstellen
  
  ## Problem:
  - Datenbank verwendet UTC für CURRENT_DATE
  - In Kambodscha ist es UTC+7
  - Um 19:00 UTC ist es bereits 02:00 am nächsten Tag in Kambodscha
  - App zeigt falsche Daten
  
  ## Lösung:
  - Alle CURRENT_DATE durch (now() AT TIME ZONE 'Asia/Phnom_Penh')::date ersetzen
  - Alle Funktionen anpassen
*/

-- Helper Function: Aktuelles Datum in Kambodscha
CREATE OR REPLACE FUNCTION current_date_cambodia()
RETURNS date
LANGUAGE sql
STABLE
AS $$
  SELECT (now() AT TIME ZONE 'Asia/Phnom_Penh')::date;
$$;

-- ==========================================
-- UPDATE: calculate_individual_daily_achievable_points
-- ==========================================
CREATE OR REPLACE FUNCTION calculate_individual_daily_achievable_points(
  p_user_id uuid,
  p_date date DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points numeric := 0;
  v_has_shift boolean := false;
  v_task_points numeric := 0;
  v_target_date date;
BEGIN
  v_target_date := COALESCE(p_date, current_date_cambodia());

  SELECT EXISTS (
    SELECT 1 
    FROM weekly_schedules ws
    CROSS JOIN jsonb_array_elements(ws.shifts) AS shift
    WHERE ws.staff_id = p_user_id
    AND ws.is_published = true
    AND (shift->>'date')::date = v_target_date
    AND shift->>'shift' != 'off'
  ) INTO v_has_shift;

  IF NOT v_has_shift THEN
    RETURN 0;
  END IF;

  v_total_points := 5;

  SELECT COALESCE(SUM(
    CASE
      WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to AND 
           (assigned_to = p_user_id OR secondary_assigned_to = p_user_id) THEN
        ((COALESCE(initial_points_value, points_value)::numeric / 2) + 
         (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END))
      WHEN assigned_to = p_user_id THEN
        (COALESCE(initial_points_value, points_value)::numeric + 
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
      ELSE 0
    END
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date) = v_target_date
  AND (assigned_to = p_user_id OR secondary_assigned_to = p_user_id)
  AND status NOT IN ('cancelled', 'archived');

  v_total_points := v_total_points + v_task_points;

  SELECT COALESCE(SUM(
    (COALESCE(initial_points_value, points_value)::numeric + 
     (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date) = v_target_date
  AND assigned_to IS NULL
  AND status NOT IN ('cancelled', 'archived');

  v_total_points := v_total_points + v_task_points;

  RETURN ROUND(v_total_points)::integer;
END;
$$;

-- ==========================================
-- UPDATE: calculate_team_daily_achievable_points
-- ==========================================
CREATE OR REPLACE FUNCTION calculate_team_daily_achievable_points(
  p_date date DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points numeric := 0;
  v_scheduled_staff_count integer := 0;
  v_checkin_base integer := 0;
  v_assigned_tasks_points numeric := 0;
  v_unassigned_tasks_points numeric := 0;
  v_target_date date;
BEGIN
  v_target_date := COALESCE(p_date, current_date_cambodia());

  SELECT COUNT(DISTINCT ws.staff_id)
  INTO v_scheduled_staff_count
  FROM weekly_schedules ws
  CROSS JOIN jsonb_array_elements(ws.shifts) AS shift
  JOIN profiles p ON ws.staff_id = p.id
  WHERE ws.is_published = true
  AND (shift->>'date')::date = v_target_date
  AND shift->>'shift' != 'off'
  AND p.role = 'staff';

  v_checkin_base := 5 * v_scheduled_staff_count;

  SELECT COALESCE(SUM(
    CASE
      WHEN assigned_to IS NOT NULL AND secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
        (COALESCE(initial_points_value, points_value)::numeric + 
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
      WHEN assigned_to IS NOT NULL THEN
        (COALESCE(initial_points_value, points_value)::numeric + 
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
      ELSE 0
    END
  ), 0)
  INTO v_assigned_tasks_points
  FROM tasks
  WHERE DATE(due_date) = v_target_date
  AND assigned_to IS NOT NULL
  AND status NOT IN ('cancelled', 'archived');

  SELECT COALESCE(SUM(
    (COALESCE(initial_points_value, points_value)::numeric + 
     (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
  ), 0)
  INTO v_unassigned_tasks_points
  FROM tasks
  WHERE DATE(due_date) = v_target_date
  AND assigned_to IS NULL
  AND status NOT IN ('cancelled', 'archived');

  v_total_points := v_checkin_base + v_assigned_tasks_points + v_unassigned_tasks_points;

  RETURN ROUND(v_total_points)::integer;
END;
$$;

-- ==========================================
-- UPDATE: calculate_individual_daily_achieved_points
-- ==========================================
CREATE OR REPLACE FUNCTION calculate_individual_daily_achieved_points(
  p_user_id uuid,
  p_date date DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points integer := 0;
  v_target_date date;
BEGIN
  v_target_date := COALESCE(p_date, current_date_cambodia());

  SELECT COALESCE(SUM(points_change), 0)
  INTO v_total_points
  FROM points_history
  WHERE user_id = p_user_id
  AND DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh') = v_target_date;

  RETURN v_total_points;
END;
$$;

-- ==========================================
-- UPDATE: calculate_team_daily_achieved_points
-- ==========================================
CREATE OR REPLACE FUNCTION calculate_team_daily_achieved_points(
  p_date date DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points integer := 0;
  v_target_date date;
BEGIN
  v_target_date := COALESCE(p_date, current_date_cambodia());

  SELECT COALESCE(SUM(ph.points_change), 0)
  INTO v_total_points
  FROM points_history ph
  JOIN profiles p ON ph.user_id = p.id
  WHERE p.role = 'staff'
  AND DATE(ph.created_at AT TIME ZONE 'Asia/Phnom_Penh') = v_target_date;

  RETURN v_total_points;
END;
$$;

-- ==========================================
-- UPDATE: update_daily_point_goals
-- ==========================================
CREATE OR REPLACE FUNCTION update_daily_point_goals(
  p_user_id uuid DEFAULT NULL,
  p_date date DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user record;
  v_target_date date;
BEGIN
  v_target_date := COALESCE(p_date, current_date_cambodia());

  IF p_user_id IS NULL THEN
    FOR v_user IN 
      SELECT id FROM profiles WHERE role = 'staff'
    LOOP
      PERFORM update_daily_point_goals(v_user.id, v_target_date);
    END LOOP;
    RETURN;
  END IF;

  INSERT INTO daily_point_goals (
    user_id,
    goal_date,
    theoretically_achievable_points,
    achieved_points,
    team_achievable_points,
    team_points_earned
  )
  VALUES (
    p_user_id,
    v_target_date,
    calculate_individual_daily_achievable_points(p_user_id, v_target_date),
    calculate_individual_daily_achieved_points(p_user_id, v_target_date),
    calculate_team_daily_achievable_points(v_target_date),
    calculate_team_daily_achieved_points(v_target_date)
  )
  ON CONFLICT (user_id, goal_date)
  DO UPDATE SET
    theoretically_achievable_points = EXCLUDED.theoretically_achievable_points,
    achieved_points = EXCLUDED.achieved_points,
    team_achievable_points = EXCLUDED.team_achievable_points,
    team_points_earned = EXCLUDED.team_points_earned,
    updated_at = now();
END;
$$;

-- ==========================================
-- UPDATE: initialize_daily_goals_for_today
-- ==========================================
CREATE OR REPLACE FUNCTION initialize_daily_goals_for_today()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM update_daily_point_goals(NULL, current_date_cambodia());
END;
$$;

-- Berechne jetzt für den 13. Oktober (heute in Kambodscha)
SELECT initialize_daily_goals_for_today();
