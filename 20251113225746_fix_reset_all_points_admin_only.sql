/*
  # Fix reset_all_points function - Allow admin role
  
  1. Changes
    - Change super_admin check to admin
    - Remove log_admin_action call (function doesn't exist)
    - Keep the reset logic intact
*/

CREATE OR REPLACE FUNCTION reset_all_points()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_role text;
BEGIN
  -- Get caller's role
  SELECT role INTO v_admin_role
  FROM profiles
  WHERE id = auth.uid();

  -- Only admin can reset all points
  IF v_admin_role != 'admin' THEN
    RAISE EXCEPTION 'Only admins can reset all points';
  END IF;

  -- Reset points
  UPDATE profiles SET total_points = 0;
  DELETE FROM points_history;
  DELETE FROM daily_point_goals;
  DELETE FROM monthly_point_goals;
END;
$$;

GRANT EXECUTE ON FUNCTION reset_all_points() TO authenticated;
