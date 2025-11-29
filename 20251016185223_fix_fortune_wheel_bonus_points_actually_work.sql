/*
  # Fix Fortune Wheel Bonus Points
  
  ## Problem
  - add_bonus_points function uses wrong table schema
  - Uses staff_id (doesn't exist) instead of user_id
  - Uses points_earned (doesn't exist) instead of achieved_points
  - Doesn't use points_history (standard way to track points)
  - Auth check is wrong (blocks users from adding their own points)
  
  ## Solution
  - Use points_history for all point changes
  - Remove broken daily_point_goals update
  - Remove auth check (users can add bonus from fortune wheel)
  - Update daily goals via standard mechanism
*/

CREATE OR REPLACE FUNCTION add_bonus_points(
  p_user_id uuid,
  p_points integer,
  p_reason text DEFAULT 'Glücksrad Bonus'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_today_date date;
BEGIN
  -- Get today's date in Cambodia timezone
  v_today_date := (now() AT TIME ZONE 'Asia/Phnom_Penh')::date;
  
  -- Add points to points_history (standard way)
  INSERT INTO points_history (
    user_id, 
    points_change, 
    reason, 
    category, 
    created_by
  )
  VALUES (
    p_user_id, 
    p_points, 
    p_reason, 
    'bonus', 
    p_user_id
  );
  
  -- Update daily point goals (this will recalculate everything correctly)
  PERFORM update_daily_point_goals(p_user_id, v_today_date);
  
  RETURN jsonb_build_object(
    'success', true,
    'points_added', p_points,
    'reason', p_reason
  );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION add_bonus_points TO authenticated;
