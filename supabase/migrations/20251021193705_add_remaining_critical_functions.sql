/*
  # Add Remaining Critical Functions
  
  1. New Functions
    - `add_bonus_points()` - Add bonus points to users (fortune wheel, quiz)
    - `reset_all_points()` - Reset points system (admin function)
    - `initialize_daily_goals_for_today()` - Initialize daily point goals
    - `calculate_team_achievable_points()` - Calculate team achievable points
    - `notify_scheduled_task()` - Notification helper for scheduled tasks
    - `notify_task_deadline()` - Notification helper for task deadlines
    
  2. Security
    - Admin-only functions for points management
    - Public functions for notifications (called by edge functions)
*/

-- Function to add bonus points (fortune wheel, quiz, etc.)
CREATE OR REPLACE FUNCTION add_bonus_points(
  p_user_id uuid,
  p_points integer,
  p_reason text,
  p_category text DEFAULT 'bonus'
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update user's total points
  UPDATE profiles
  SET total_points = total_points + p_points
  WHERE id = p_user_id;

  -- Add to points history
  INSERT INTO points_history (user_id, points_change, reason, category)
  VALUES (p_user_id, p_points, p_reason, p_category);

  -- Update daily point goals
  PERFORM update_daily_point_goals(p_user_id, CURRENT_DATE);

  RETURN json_build_object('success', true, 'points_added', p_points);
END;
$$;

-- Function to reset all points
CREATE OR REPLACE FUNCTION reset_all_points()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count integer := 0;
BEGIN
  -- Reset all user points
  UPDATE profiles
  SET total_points = 0
  WHERE role = 'staff';

  GET DIAGNOSTICS v_count = ROW_COUNT;

  -- Clear points history
  DELETE FROM points_history;

  -- Clear daily point goals
  DELETE FROM daily_point_goals;

  -- Reinitialize daily goals for today
  PERFORM update_daily_point_goals(NULL, CURRENT_DATE);

  RETURN json_build_object(
    'success', true,
    'users_reset', v_count,
    'message', 'All points have been reset successfully'
  );
END;
$$;

-- Function to initialize daily goals for today
CREATE OR REPLACE FUNCTION initialize_daily_goals_for_today()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM update_daily_point_goals(NULL, CURRENT_DATE);
END;
$$;

-- Function to calculate team achievable points for a specific date
CREATE OR REPLACE FUNCTION calculate_team_achievable_points(
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points integer := 0;
  v_user record;
BEGIN
  -- Sum achievable points for all staff members who have a schedule on this date
  FOR v_user IN 
    SELECT DISTINCT profiles.id
    FROM profiles
    WHERE profiles.role = 'staff'
    AND EXISTS (
      SELECT 1 FROM schedules
      WHERE schedules.staff_id = profiles.id
      AND DATE(schedules.start_time) = p_date
    )
  LOOP
    v_total_points := v_total_points + calculate_daily_achievable_points(v_user.id, p_date);
  END LOOP;

  RETURN v_total_points;
END;
$$;

-- Notification helper for scheduled tasks
CREATE OR REPLACE FUNCTION notify_scheduled_task(
  p_task_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task record;
BEGIN
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;

  IF FOUND AND v_task.assigned_to IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_task.assigned_to,
      'Task Reminder',
      'Task "' || v_task.title || '" is scheduled for today',
      'task'
    );
  END IF;
END;
$$;

-- Notification helper for task deadlines
CREATE OR REPLACE FUNCTION notify_task_deadline(
  p_task_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task record;
BEGIN
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;

  IF FOUND AND v_task.assigned_to IS NOT NULL AND v_task.status != 'completed' THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_task.assigned_to,
      'Task Deadline',
      'Task "' || v_task.title || '" is due soon!',
      'warning'
    );
  END IF;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION add_bonus_points TO authenticated;
GRANT EXECUTE ON FUNCTION reset_all_points TO authenticated;
GRANT EXECUTE ON FUNCTION initialize_daily_goals_for_today TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_team_achievable_points TO authenticated;
GRANT EXECUTE ON FUNCTION notify_scheduled_task TO authenticated;
GRANT EXECUTE ON FUNCTION notify_task_deadline TO authenticated;
