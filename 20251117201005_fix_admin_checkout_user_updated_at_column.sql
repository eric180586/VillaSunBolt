/*
  # Fix admin_checkout_user Function
  
  1. Problem
    - Function references non-existent column updated_at in check_ins table
    
  2. Solution
    - Remove updated_at reference from UPDATE statement
*/

CREATE OR REPLACE FUNCTION admin_checkout_user(
  p_admin_id uuid,
  p_user_id uuid,
  p_checkout_time timestamptz DEFAULT NOW(),
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_role text;
  v_check_in_id uuid;
  v_check_in_time timestamptz;
  v_user_name text;
BEGIN
  -- Verify admin
  SELECT role INTO v_admin_role FROM profiles WHERE id = p_admin_id;
  
  IF v_admin_role != 'admin' THEN
    RAISE EXCEPTION 'Nur Admins können Mitarbeiter auschecken';
  END IF;
  
  -- Get user name
  SELECT full_name INTO v_user_name FROM profiles WHERE id = p_user_id;
  
  -- Get today's check-in
  SELECT id, check_in_time INTO v_check_in_id, v_check_in_time
  FROM check_ins
  WHERE user_id = p_user_id
    AND DATE(check_in_time AT TIME ZONE 'Asia/Phnom_Penh') = DATE(NOW() AT TIME ZONE 'Asia/Phnom_Penh')
    AND check_out_time IS NULL;
  
  IF v_check_in_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'No active check-in found');
  END IF;
  
  -- Update check-out time (removed updated_at)
  UPDATE check_ins
  SET check_out_time = p_checkout_time
  WHERE id = v_check_in_id;
  
  -- Notify user
  INSERT INTO notifications (user_id, type, title, message)
  VALUES (
    p_user_id,
    'info',
    'Checked Out',
    'Admin checked you out' || CASE WHEN p_reason IS NOT NULL THEN ': ' || p_reason ELSE '' END
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'User checked out successfully'
  );
END;
$$;
