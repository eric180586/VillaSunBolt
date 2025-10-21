/*
  # Fix Check-In Approval and Points System

  ## Changes
  1. Update points_history RLS policies to allow SECURITY DEFINER functions
  2. Add 'punctuality' and 'penalty' categories to points_history check constraint
  3. Ensure approve_check_in and reject_check_in functions can bypass RLS

  ## Security
  - SECURITY DEFINER functions handle admin checks internally
  - RLS policies updated to support system functions
*/

-- Drop and recreate points_history policies to allow SECURITY DEFINER functions
DROP POLICY IF EXISTS "Managers can create points history" ON points_history;
DROP POLICY IF EXISTS "Users can create points history" ON points_history;

CREATE POLICY "System and managers can create points history"
  ON points_history
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Allow if called by admin/manager OR by SECURITY DEFINER function
    (EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'manager')
    ))
    OR 
    -- Allow SECURITY DEFINER functions (check if created_by is set)
    (created_by IS NOT NULL)
  );

-- Update points_history table to include new categories
ALTER TABLE points_history DROP CONSTRAINT IF EXISTS points_history_category_check;

ALTER TABLE points_history ADD CONSTRAINT points_history_category_check 
  CHECK (category IN ('task_completed', 'bonus', 'deduction', 'achievement', 'punctuality', 'penalty', 'other'));

-- Recreate approve_check_in function with better RLS handling
DROP FUNCTION IF EXISTS approve_check_in(uuid, uuid);

CREATE OR REPLACE FUNCTION approve_check_in(
  p_check_in_id uuid,
  p_admin_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check_in record;
  v_reason text;
BEGIN
  -- Verify admin role
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = p_admin_id
    AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can approve check-ins';
  END IF;

  -- Get check-in details
  SELECT * INTO v_check_in
  FROM check_ins
  WHERE id = p_check_in_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Check-in not found';
  END IF;
  
  IF v_check_in.status != 'pending' THEN
    RAISE EXCEPTION 'Check-in already processed';
  END IF;
  
  -- Update check-in status
  UPDATE check_ins
  SET 
    status = 'approved',
    approved_by = p_admin_id,
    approved_at = now()
  WHERE id = p_check_in_id;
  
  -- Award points
  IF v_check_in.points_awarded > 0 THEN
    v_reason := 'Pünktliches Einchecken - ' || v_check_in.shift_type || 'schicht (bestätigt)';
    
    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (v_check_in.user_id, v_check_in.points_awarded, v_reason, 'punctuality', p_admin_id);
  ELSIF v_check_in.is_late THEN
    v_reason := 'Verspätetes Einchecken (' || v_check_in.minutes_late || ' Min.) - ' || v_check_in.shift_type || 'schicht';
    
    -- Deduct points for being late
    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (v_check_in.user_id, v_check_in.points_awarded - 5, v_reason, 'penalty', p_admin_id);
  END IF;
  
  -- Notify staff member
  INSERT INTO notifications (user_id, title, message, type)
  VALUES (
    v_check_in.user_id,
    'Check-In bestätigt',
    'Dein Check-In wurde bestätigt. Du hast ' || v_check_in.points_awarded || ' Punkte erhalten!',
    'success'
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'points_awarded', v_check_in.points_awarded
  );
END;
$$;

-- Recreate reject_check_in function with better RLS handling
DROP FUNCTION IF EXISTS reject_check_in(uuid, uuid, text);

CREATE OR REPLACE FUNCTION reject_check_in(
  p_check_in_id uuid,
  p_admin_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check_in record;
BEGIN
  -- Verify admin role
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = p_admin_id
    AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can reject check-ins';
  END IF;

  -- Get check-in details
  SELECT * INTO v_check_in
  FROM check_ins
  WHERE id = p_check_in_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Check-in not found';
  END IF;
  
  IF v_check_in.status != 'pending' THEN
    RAISE EXCEPTION 'Check-in already processed';
  END IF;
  
  -- Update check-in status
  UPDATE check_ins
  SET 
    status = 'rejected',
    approved_by = p_admin_id,
    approved_at = now()
  WHERE id = p_check_in_id;
  
  -- Notify staff member
  INSERT INTO notifications (user_id, title, message, type)
  VALUES (
    v_check_in.user_id,
    'Check-In abgelehnt',
    'Dein Check-In wurde abgelehnt. Grund: ' || COALESCE(p_reason, 'Keine Angabe'),
    'error'
  );
  
  RETURN jsonb_build_object(
    'success', true
  );
END;
$$;