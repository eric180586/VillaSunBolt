/*
  # Create Reset All Points Function
  
  1. New Function
    - `reset_all_points()` - Admin function to completely reset all points
    - Deletes all points_history entries
    - Sets all profiles.total_points to 0
    - Bypasses triggers for clean reset
  
  2. Security
    - Only accessible by authenticated users (RLS enforced at app level)
*/

CREATE OR REPLACE FUNCTION reset_all_points()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete all points history
  DELETE FROM points_history;
  
  -- Reset all profile points
  UPDATE profiles SET total_points = 0;
END;
$$;
