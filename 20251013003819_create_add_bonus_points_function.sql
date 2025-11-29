/*
  # Create function to add bonus points from fortune wheel

  1. New Function
    - `add_bonus_points` - Adds bonus points to user's profile and daily goals
    - Takes user_id, points amount, and reason as parameters
    - Updates both profile total points and today's daily goal points

  2. Security
    - Only authenticated users can call this for themselves
*/

CREATE OR REPLACE FUNCTION add_bonus_points(
  p_user_id uuid,
  p_points integer,
  p_reason text DEFAULT 'Bonus Points'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_today date;
  v_result jsonb;
BEGIN
  IF auth.uid() != p_user_id THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized'
    );
  END IF;

  v_today := CURRENT_DATE;

  UPDATE profiles
  SET total_points = total_points + p_points
  WHERE id = p_user_id;

  INSERT INTO daily_point_goals (
    staff_id,
    goal_date,
    points_earned
  )
  VALUES (
    p_user_id,
    v_today,
    p_points
  )
  ON CONFLICT (staff_id, goal_date)
  DO UPDATE SET
    points_earned = daily_point_goals.points_earned + p_points;

  v_result := jsonb_build_object(
    'success', true,
    'points_added', p_points,
    'reason', p_reason
  );

  RETURN v_result;
END;
$$;
