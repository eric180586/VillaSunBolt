/*
  # Fix Achievable Points Calculation Logic

  ## Problem
  Current system counts unassigned tasks as FULLY achievable for EVERY staff member,
  causing inflated achievable points and percentages over 100%.
  
  Example: 4 staff checked in, 3 unassigned tasks (5 points each)
  - Wrong: Each staff gets 15 points = 60 total achievable
  - Correct: 15 points divided among 4 staff = 3.75 points each = 15 total

  ## Solution
  1. Individual achievable points:
     - Check-in points: 5 if approved check-in exists
     - Assigned tasks: Full points (or half if secondary assignment)
     - Unassigned tasks: Divided equally among ALL checked-in staff members
  
  2. Team achievable points:
     - Sum of check-in points (5 × number of checked-in staff)
     - Sum of ALL task points (counted once per task, not per staff member)
  
  ## Examples
  Scenario: 4 staff checked in, 4 tasks total (25 points: 10+5+5+5, all with deadline = +4)
  
  Individual (e.g., Sopheaktra):
  - Check-in: 5 points
  - If 1 task assigned to her (10 pts + 1 deadline): 11 points
  - If 3 unassigned tasks (15 pts + 3 deadline = 18 pts) ÷ 4 staff: 4.5 points
  - Total achievable: 5 + 11 + 4.5 = 20.5 points
  
  Team total:
  - Check-ins: 4 × 5 = 20 points
  - All tasks: 25 + 4 (deadlines) = 29 points
  - Total achievable: 20 + 29 = 49 points
*/

-- Drop existing functions to recreate with correct logic
DROP FUNCTION IF EXISTS calculate_daily_achievable_points(uuid, date);
DROP FUNCTION IF EXISTS calculate_team_daily_achievable_points(date);

-- Individual achievable points with correct unassigned task distribution
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

  -- Calculate points from ASSIGNED tasks (tasks where user is assigned_to or secondary_assigned_to)
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
  AND status NOT IN ('completed', 'cancelled')
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
    AND status NOT IN ('completed', 'cancelled')
    AND assigned_to IS NULL;

    v_total_points := v_total_points + v_unassigned_task_points;
  END IF;

  -- Round to integer
  RETURN ROUND(v_total_points)::integer;
END;
$$;

-- Team achievable points: Simple sum without multiplication
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

  -- Task points: Each task counts ONCE (not multiplied by staff count)
  SELECT COALESCE(SUM(
    points_value + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status NOT IN ('completed', 'cancelled');

  v_total_points := v_total_points + v_task_points;

  RETURN v_total_points;
END;
$$;

-- Refresh today's point goals with corrected calculations
SELECT update_daily_point_goals(NULL, CURRENT_DATE);
