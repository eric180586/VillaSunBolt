/*
  # Secure Critical Admin Functions

  1. Updates
    - Add admin/super_admin checks to critical functions
    - Prevent unauthorized access to dangerous operations

  2. Functions Updated
    - reset_all_points: Only super_admin can reset all points
    - add_bonus_points: Only admin/super_admin can add bonus points
*/

-- Secure reset_all_points: Only super_admin can reset all points
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

  -- Only super_admin can reset all points
  IF v_admin_role != 'super_admin' THEN
    RAISE EXCEPTION 'Nur Super Admins können alle Punkte zurücksetzen';
  END IF;

  -- Log the action
  PERFORM log_admin_action(
    auth.uid(),
    'reset_all_points',
    'points_history',
    NULL,
    'System-weites Punkte Reset',
    NULL,
    NULL,
    'Alle Punkte wurden zurückgesetzt'
  );

  -- Reset points
  UPDATE profiles SET total_points = 0;
  DELETE FROM points_history;
  DELETE FROM daily_point_goals;
  DELETE FROM monthly_point_goals;
END;
$$;

-- Secure add_bonus_points: Only admin/super_admin can add bonus points
CREATE OR REPLACE FUNCTION add_bonus_points(
  p_user_id uuid,
  p_points integer,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_role text;
  v_user_name text;
BEGIN
  -- Get caller's role
  SELECT role INTO v_admin_role
  FROM profiles
  WHERE id = auth.uid();

  -- Only admin/super_admin can add bonus points
  IF v_admin_role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'Nur Admins können Bonuspunkte vergeben';
  END IF;

  -- Get user name
  SELECT full_name INTO v_user_name
  FROM profiles
  WHERE id = p_user_id;

  IF v_user_name IS NULL THEN
    RAISE EXCEPTION 'Benutzer nicht gefunden';
  END IF;

  -- Add bonus points
  INSERT INTO points_history (
    user_id,
    points,
    category,
    description,
    created_at
  )
  VALUES (
    p_user_id,
    p_points,
    'bonus',
    p_reason,
    now()
  );

  -- Update daily goals
  INSERT INTO daily_point_goals (user_id, goal_date, achievable_points, earned_points, created_at)
  VALUES (p_user_id, CURRENT_DATE, 0, p_points, now())
  ON CONFLICT (user_id, goal_date)
  DO UPDATE SET earned_points = daily_point_goals.earned_points + EXCLUDED.earned_points;

  -- Log the action
  PERFORM log_admin_action(
    auth.uid(),
    'add_bonus_points',
    'points_history',
    NULL,
    v_user_name,
    NULL,
    jsonb_build_object('points', p_points, 'reason', p_reason),
    p_reason
  );

  -- Send notification
  INSERT INTO notifications (
    user_id,
    title,
    message,
    type,
    created_at
  ) VALUES (
    p_user_id,
    'Bonuspunkte erhalten',
    'Du hast ' || p_points || ' Bonuspunkte erhalten! Grund: ' || p_reason,
    'bonus_points',
    now()
  );

  RETURN jsonb_build_object('success', true, 'points_added', p_points);
END;
$$;
