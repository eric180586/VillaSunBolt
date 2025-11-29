/*
  # Fix: initial_points_value = 0 Bug
  
  ## Problem:
  - Tasks haben initial_points_value = 0 (nicht NULL)
  - COALESCE(initial_points_value, points_value) = 0 statt points_value
  - Ergebnis: 0 + 1 = 1 Punkt statt 5 + 1 = 6
  
  ## Lösung:
  - COALESCE(NULLIF(initial_points_value, 0), points_value) verwenden
  - Alle Berechnungsfunktionen korrigieren
*/

-- ==========================================
-- FIX: calculate_individual_daily_achievable_points
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

  -- Assigned Tasks (mit NULLIF für initial_points_value)
  SELECT COALESCE(SUM(
    CASE
      WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to AND 
           (assigned_to = p_user_id OR secondary_assigned_to = p_user_id) THEN
        ((COALESCE(NULLIF(initial_points_value, 0), points_value)::numeric / 2) + 
         (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END))
      WHEN assigned_to = p_user_id THEN
        (COALESCE(NULLIF(initial_points_value, 0), points_value)::numeric + 
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

  -- Unassigned Tasks (mit NULLIF)
  SELECT COALESCE(SUM(
    (COALESCE(NULLIF(initial_points_value, 0), points_value)::numeric + 
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
-- FIX: calculate_team_daily_achievable_points
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

  -- Anzahl arbeitender Staff
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

  -- Assigned Tasks (mit NULLIF)
  SELECT COALESCE(SUM(
    CASE
      WHEN assigned_to IS NOT NULL AND secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
        (COALESCE(NULLIF(initial_points_value, 0), points_value)::numeric + 
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
      WHEN assigned_to IS NOT NULL THEN
        (COALESCE(NULLIF(initial_points_value, 0), points_value)::numeric + 
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
      ELSE 0
    END
  ), 0)
  INTO v_assigned_tasks_points
  FROM tasks
  WHERE DATE(due_date) = v_target_date
  AND assigned_to IS NOT NULL
  AND status NOT IN ('cancelled', 'archived');

  -- Unassigned Tasks (mit NULLIF)
  SELECT COALESCE(SUM(
    (COALESCE(NULLIF(initial_points_value, 0), points_value)::numeric + 
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

-- Neu berechnen
SELECT initialize_daily_goals_for_today();
