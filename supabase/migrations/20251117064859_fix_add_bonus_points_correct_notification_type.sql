/*
  # Fix add_bonus_points - Use Correct Notification Type
  
  1. Changes
    - Use 'points_earned' for fortune wheel (it's in allowed list)
    - Keep everything else the same
*/

DROP FUNCTION IF EXISTS public.add_bonus_points(uuid, integer, text);

CREATE OR REPLACE FUNCTION public.add_bonus_points(
  p_user_id uuid,
  p_points integer,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_role text;
  v_user_name text;
  v_is_fortune_wheel boolean;
BEGIN
  -- Get caller's role
  SELECT role INTO v_caller_role
  FROM profiles
  WHERE id = auth.uid();

  -- Check if this is a fortune wheel bonus (user adding their own points)
  v_is_fortune_wheel := (p_user_id = auth.uid() AND p_reason LIKE '%Glücksrad%');

  -- Only allow if:
  -- 1. Admin/super_admin adding points for anyone
  -- 2. User adding their own fortune wheel bonus
  IF NOT (v_caller_role IN ('admin', 'super_admin') OR v_is_fortune_wheel) THEN
    RAISE EXCEPTION 'Unauthorized to add bonus points';
  END IF;

  -- Get user name
  SELECT full_name INTO v_user_name
  FROM profiles
  WHERE id = p_user_id;

  IF v_user_name IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  -- Add bonus points with CORRECT column names
  INSERT INTO points_history (
    user_id,
    points_change,
    reason,
    category,
    created_by
  ) VALUES (
    p_user_id,
    p_points,
    p_reason,
    'fortune_wheel',
    auth.uid()
  );

  -- Send notification to user with ALLOWED type
  INSERT INTO notifications (
    user_id,
    type,
    title,
    message
  ) VALUES (
    p_user_id,
    'points_earned',
    'Bonus Points Received',
    'You received ' || p_points || ' bonus points! Reason: ' || p_reason
  );

  -- If admin added points, log it
  IF v_caller_role IN ('admin', 'super_admin') AND NOT v_is_fortune_wheel THEN
    -- Notify admins about the manual bonus
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message
    )
    SELECT 
      id,
      'points_earned',
      'Admin Added Bonus Points',
      'Admin added ' || p_points || ' bonus points to ' || v_user_name || '. Reason: ' || p_reason
    FROM profiles
    WHERE role = 'admin';
  END IF;

  RETURN jsonb_build_object('success', true, 'points_added', p_points);
END;
$$;
