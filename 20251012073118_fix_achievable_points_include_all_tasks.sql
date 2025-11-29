/*
  # Fix Achievable Points to Include All Tasks
  
  ## Problem
  The calculate_daily_achievable_points function was filtering out completed tasks
  with `status NOT IN ('completed', 'cancelled')`. This caused the theoretically
  achievable points to show 0 or low values after tasks were completed.
  
  ## Solution
  "Theoretically achievable points" should represent ALL points that COULD be achieved
  on a given day, regardless of whether tasks were completed. Only exclude 'cancelled' tasks.
  
  ## Logic
  - Include tasks with status: 'pending', 'in_progress', 'completed'
  - Exclude only 'cancelled' tasks (these were never meant to be done)
  - This gives an accurate baseline for percentage calculations
*/

-- Individual achievable points: Include all non-cancelled tasks
CREATE OR REPLACE FUNCTION calculate_daily_achievable_points(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points numeric := 0;
  v_checkin_points integer := 0;
  v_assigned_task_points numeric := 0;
  v_unassigned_task_points numeric := 0;
  v_has_checked_in boolean := false;
  v_checked_in_staff_count integer := 0;
BEGIN
  -- Check if user has approved check-in today
  SELECT EXISTS (
    SELECT 1 FROM check_ins
    WHERE user_id = p_user_id
    AND DATE(check_in_time) = p_date
    AND status = 'approved'
  ) INTO v_has_checked_in;

  -- If no check-in, no points achievable
  IF NOT v_has_checked_in THEN
    RETURN 0;
  END IF;

  -- Check-in points
  v_checkin_points := 5;
  v_total_points := v_total_points + v_checkin_points;

  -- Count total staff with approved check-ins (for unassigned task distribution)
  SELECT COUNT(DISTINCT user_id)
  INTO v_checked_in_staff_count
  FROM check_ins
  WHERE DATE(check_in_time) = p_date
  AND status = 'approved'
  AND user_id IN (SELECT id FROM profiles WHERE role = 'staff');

  -- Calculate points from ASSIGNED tasks (include completed tasks)
  SELECT COALESCE(SUM(
    CASE
      -- Task is assigned to this user as primary
      WHEN assigned_to = p_user_id THEN
        CASE
          -- Shared with secondary user: half points + half deadline bonus
          WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
            (points_value / 2.0) + (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END)
          -- Solo assignment: full points + full deadline bonus
          ELSE
            points_value + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
        END
      -- Task is assigned to this user as secondary
      WHEN secondary_assigned_to = p_user_id THEN
        (points_value / 2.0) + (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END)
      ELSE 0
    END
  ), 0)
  INTO v_assigned_task_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status != 'cancelled'
  AND (assigned_to = p_user_id OR secondary_assigned_to = p_user_id);

  v_total_points := v_total_points + v_assigned_task_points;

  -- Calculate points from UNASSIGNED tasks (divided among all checked-in staff)
  IF v_checked_in_staff_count > 0 THEN
    SELECT COALESCE(SUM(
      (points_value + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)) / v_checked_in_staff_count::numeric
    ), 0)
    INTO v_unassigned_task_points
    FROM tasks
    WHERE DATE(due_date) = p_date
    AND status != 'cancelled'
    AND assigned_to IS NULL;

    v_total_points := v_total_points + v_unassigned_task_points;
  END IF;

  -- Round to integer
  RETURN ROUND(v_total_points)::integer;
END;
$$;

-- Team achievable points: Include all non-cancelled tasks
CREATE OR REPLACE FUNCTION calculate_team_daily_achievable_points(
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points integer := 0;
  v_checkin_points integer := 0;
  v_task_points integer := 0;
  v_checked_in_staff_count integer := 0;
BEGIN
  -- Count staff with approved check-ins
  SELECT COUNT(DISTINCT user_id)
  INTO v_checked_in_staff_count
  FROM check_ins
  WHERE DATE(check_in_time) = p_date
  AND status = 'approved'
  AND user_id IN (SELECT id FROM profiles WHERE role = 'staff');

  -- Check-in points: 5 × number of checked-in staff
  v_checkin_points := v_checked_in_staff_count * 5;
  v_total_points := v_total_points + v_checkin_points;

  -- Task points: Each task counts ONCE (include completed tasks)
  SELECT COALESCE(SUM(
    points_value + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status != 'cancelled';

  v_total_points := v_total_points + v_task_points;

  RETURN v_total_points;
END;
$$;

-- Refresh today's point goals with corrected calculations
SELECT update_daily_point_goals(NULL, CURRENT_DATE);
