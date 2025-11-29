/*
  # Fix reset_all_points function - Add WHERE clause
  
  1. Changes
    - Add WHERE clause to UPDATE to avoid Supabase error
    - Use WHERE true to update all rows safely
*/

CREATE OR REPLACE FUNCTION reset_all_points()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_role text;
BEGIN
  SELECT role INTO v_admin_role
  FROM profiles
  WHERE id = auth.uid();

  IF v_admin_role != 'admin' THEN
    RAISE EXCEPTION 'Only admins can reset all points';
  END IF;

  UPDATE profiles SET total_points = 0 WHERE true;
  DELETE FROM points_history WHERE true;
  DELETE FROM daily_point_goals WHERE true;
  DELETE FROM monthly_point_goals WHERE true;
END;
$$;

GRANT EXECUTE ON FUNCTION reset_all_points() TO authenticated;
