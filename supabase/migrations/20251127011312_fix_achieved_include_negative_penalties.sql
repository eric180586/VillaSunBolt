/*
  # Fix Achieved Points - Include Negative Penalties

  ## THE PROBLEM:
  The calculate_achieved_points() function sets negative values to 0.
  This means penalties (late check-in, missed patrols) are not reflected in achieved!

  ## CORRECT BEHAVIOR:
  - User checks in late: -116 penalty
  - User completes task: +12 points
  - achieved = -104 (not 0!)
  - percentage = -104/32 = -325% (shows they messed up badly)

  ## THE FIX:
  Remove the "IF v_achieved_points < 0 THEN v_achieved_points := 0" logic.
  Allow negative achieved points.
*/

CREATE OR REPLACE FUNCTION calculate_achieved_points(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_achieved_points integer := 0;
BEGIN
  -- Sum ALL points (positive AND negative) earned on this date
  SELECT COALESCE(SUM(points_change), 0) INTO v_achieved_points
  FROM points_history
  WHERE user_id = p_user_id
    AND DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date;

  -- Return as-is (can be negative!)
  RETURN v_achieved_points;
END;
$$;

COMMENT ON FUNCTION calculate_achieved_points IS 
'Calculates achieved points including penalties (can be negative if user has more penalties than earned points)';
