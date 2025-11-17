/*
  # Fix Fortune Wheel - Notify Admin
  
  1. Changes
    - Admin receives notification when user wins fortune wheel points
    - Both check-in and fortune wheel notifications go to admin
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

  -- Send notification to user
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

  -- Send notification to ALL ADMINS (for both fortune wheel and manual bonuses)
  INSERT INTO notifications (
    user_id,
    type,
    title,
    message
  )
  SELECT 
    id,
    'points_earned',
    CASE 
      WHEN v_is_fortune_wheel THEN 'Fortune Wheel Bonus'
      ELSE 'Admin Added Bonus Points'
    END,
    CASE 
      WHEN v_is_fortune_wheel THEN v_user_name || ' won ' || p_points || ' points from Fortune Wheel!'
      ELSE 'Admin added ' || p_points || ' bonus points to ' || v_user_name || '. Reason: ' || p_reason
    END
  FROM profiles
  WHERE role = 'admin';

  RETURN jsonb_build_object('success', true, 'points_added', p_points);
END;
$$;
