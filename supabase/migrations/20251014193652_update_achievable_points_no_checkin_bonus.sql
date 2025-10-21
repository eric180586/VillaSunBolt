/*
  # Update Achievable Points Calculation - Remove Check-In Bonus

  ## Changes:
  - Remove 5 points for check-in from achievable calculation
  - Check-in gives 0 points (only penalty if late ≥ 25 min)
  - Update both individual and team achievable points
  
  ## Impact:
  - Individual achievable = Tasks only (no check-in bonus)
  - Team achievable = All tasks (no check-in bonus)
*/

-- Update Individual Achievable Points (remove check-in 5 points)
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

  -- NO CHECK-IN POINTS ANYMORE
  v_total_points := 0;

  -- Assigned Tasks (primary oder secondary)
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

  -- Unassigned Tasks
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

  -- Checklists
  SELECT COALESCE(SUM(c.points_value::numeric), 0)
  INTO v_task_points
  FROM checklist_instances ci
  INNER JOIN checklists c ON c.id = ci.checklist_id
  WHERE ci.assigned_to = p_user_id
  AND ci.due_date = p_date
  AND ci.status NOT IN ('cancelled');

  v_total_points := v_total_points + v_task_points;

  -- Patrol Rounds
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

-- Update Team Achievable Points (remove check-in bonus)
CREATE OR REPLACE FUNCTION calculate_team_daily_achievable_points(p_date date DEFAULT CURRENT_DATE)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points numeric := 0;
  v_task_points numeric := 0;
BEGIN
  -- NO CHECK-IN BONUS FOR TEAM
  
  -- All tasks with deadline today
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

  -- All checklists
  SELECT COALESCE(SUM(c.points_value::numeric), 0)
  INTO v_task_points
  FROM checklist_instances ci
  INNER JOIN checklists c ON c.id = ci.checklist_id
  WHERE ci.due_date = p_date
  AND ci.status NOT IN ('cancelled');

  v_total_points := v_total_points + v_task_points;

  -- All patrol rounds
  SELECT COALESCE(SUM(3), 0)
  INTO v_task_points
  FROM patrol_rounds
  WHERE DATE(scheduled_time) = p_date
  AND completed_at IS NULL;

  v_total_points := v_total_points + v_task_points;

  RETURN FLOOR(v_total_points);
END;
$$;
