/*
  # Fix Achievable Points - Correct Checklist Column Names

  ## Problem:
  - checklist_instances has no 'assigned_to' or 'due_date'
  - Correct columns: 'completed_by' and 'instance_date'
  
  ## Solution:
  - Fix column references in achievable points functions
  - Checklists count for user if completed_by = user_id
*/

CREATE OR REPLACE FUNCTION calculate_individual_daily_achievable_points(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points numeric := 0;
  v_has_shift boolean := false;
  v_task_points numeric := 0;
BEGIN
  SELECT EXISTS (
    SELECT 1 
    FROM weekly_schedules ws
    CROSS JOIN jsonb_array_elements(ws.shifts) AS shift
    WHERE ws.staff_id = p_user_id
    AND ws.is_published = true
    AND (shift->>'date')::date = p_date
    AND shift->>'shift' != 'off'
  ) INTO v_has_shift;

  IF NOT v_has_shift THEN
    RETURN 0;
  END IF;

  v_total_points := 0;

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
  WHERE DATE(due_date) = p_date
  AND (assigned_to = p_user_id OR secondary_assigned_to = p_user_id)
  AND status NOT IN ('cancelled', 'archived');

  v_total_points := v_total_points + v_task_points;

  SELECT COALESCE(SUM(
    (COALESCE(initial_points_value, points_value)::numeric + 
     (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND assigned_to IS NULL
  AND secondary_assigned_to IS NULL
  AND status NOT IN ('cancelled', 'archived');

  v_total_points := v_total_points + v_task_points;

  SELECT COALESCE(SUM(c.points_value::numeric), 0)
  INTO v_task_points
  FROM checklist_instances ci
  INNER JOIN checklists c ON c.id = ci.checklist_id
  WHERE ci.instance_date = p_date
  AND ci.status NOT IN ('cancelled');

  v_total_points := v_total_points + v_task_points;

  SELECT COALESCE(SUM(3), 0)
  INTO v_task_points
  FROM patrol_rounds
  WHERE assigned_to = p_user_id
  AND DATE(scheduled_time) = p_date
  AND completed_at IS NULL;

  v_total_points := v_total_points + v_task_points;

  RETURN FLOOR(v_total_points);
END;
$$;

CREATE OR REPLACE FUNCTION calculate_team_daily_achievable_points(p_date date DEFAULT CURRENT_DATE)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points numeric := 0;
  v_task_points numeric := 0;
BEGIN
  SELECT COALESCE(SUM(
    CASE
      WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
        (COALESCE(initial_points_value, points_value)::numeric + 
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
      WHEN assigned_to IS NOT NULL THEN
        (COALESCE(initial_points_value, points_value)::numeric + 
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
      ELSE
        (COALESCE(initial_points_value, points_value)::numeric + 
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
    END
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status NOT IN ('cancelled', 'archived');

  v_total_points := v_total_points + v_task_points;

  SELECT COALESCE(SUM(c.points_value::numeric), 0)
  INTO v_task_points
  FROM checklist_instances ci
  INNER JOIN checklists c ON c.id = ci.checklist_id
  WHERE ci.instance_date = p_date
  AND ci.status NOT IN ('cancelled');

  v_total_points := v_total_points + v_task_points;

  SELECT COALESCE(SUM(3), 0)
  INTO v_task_points
  FROM patrol_rounds
  WHERE DATE(scheduled_time) = p_date
  AND completed_at IS NULL;

  v_total_points := v_total_points + v_task_points;

  RETURN FLOOR(v_total_points);
END;
$$;
