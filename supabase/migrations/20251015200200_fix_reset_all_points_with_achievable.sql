/*
  # Fix Reset All Points - Include Achievable Points Reset

  ## Changes:
  - Update reset_all_points() function to reset achievable points fields
  - Reset theoretically_achievable_points and team_achievable_points to 0
  - Reset all daily_point_goals fields instead of deleting
  
  ## Why:
  - When admin resets points, monthly achievable points should also be reset
  - Keeps daily_point_goals records but zeros out all values
*/

CREATE OR REPLACE FUNCTION reset_all_points()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- 1. Delete all points history
  DELETE FROM points_history WHERE id IS NOT NULL;
  
  -- 2. Reset all daily point goals (including achievable points)
  UPDATE daily_point_goals
  SET
    theoretically_achievable_points = 0,
    team_achievable_points = 0,
    achieved_points = 0,
    team_points_earned = 0,
    percentage = 0,
    color_status = 'gray',
    total_tasks_today = 0,
    completed_tasks_today = 0
  WHERE id IS NOT NULL;
  
  -- 3. Reset total_points in profiles for all staff
  UPDATE profiles
  SET total_points = 0
  WHERE role = 'staff';
  
  -- 4. Reset tasks (points_value = initial_points_value)
  UPDATE tasks
  SET 
    points_value = COALESCE(initial_points_value, points_value),
    deadline_bonus_awarded = false,
    reopened_count = 0
  WHERE id IS NOT NULL;
  
  -- 5. Reinitialize daily goals for today
  PERFORM initialize_daily_goals_for_today();
END;
$$;

GRANT EXECUTE ON FUNCTION reset_all_points() TO authenticated;
