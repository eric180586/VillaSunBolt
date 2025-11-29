/*
  # Update Check-In System with Admin Approval

  1. Changes to Tables
    - Modify `check_ins` table
      - Add `status` (text) - 'pending', 'approved', 'rejected'
      - Add `approved_by` (uuid) - Admin who approved
      - Add `approved_at` (timestamptz) - When approved
      - Modify points logic to only award after approval

  2. Security
    - Admins can update check-in status
    - Staff can only create check-ins

  3. Notes
    - Points are now awarded only when admin approves
    - Staff submits check-in request, admin reviews and approves
*/

-- Add new columns to check_ins table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'check_ins' AND column_name = 'status'
  ) THEN
    ALTER TABLE check_ins ADD COLUMN status text DEFAULT 'pending';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'check_ins' AND column_name = 'approved_by'
  ) THEN
    ALTER TABLE check_ins ADD COLUMN approved_by uuid REFERENCES profiles(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'check_ins' AND column_name = 'approved_at'
  ) THEN
    ALTER TABLE check_ins ADD COLUMN approved_at timestamptz;
  END IF;
END $$;

-- Update RLS policies
DROP POLICY IF EXISTS "Admins can delete check-ins" ON check_ins;

CREATE POLICY "Admins can update check-ins"
  ON check_ins
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Update process_check_in function to NOT award points immediately
DROP FUNCTION IF EXISTS process_check_in(uuid, text);

CREATE OR REPLACE FUNCTION process_check_in(
  p_user_id uuid,
  p_shift_type text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_check_in_time timestamptz;
  v_shift_start_time time;
  v_minutes_late integer := 0;
  v_is_late boolean := false;
  v_points integer := 5;
  v_check_in_id uuid;
BEGIN
  v_check_in_time := now();
  
  -- Determine shift start time (9:00 for früh, 15:00 for spät)
  IF p_shift_type = 'früh' THEN
    v_shift_start_time := '09:00:00'::time;
  ELSE
    v_shift_start_time := '15:00:00'::time;
  END IF;
  
  -- Calculate if late and by how much
  IF v_check_in_time::time > v_shift_start_time THEN
    v_is_late := true;
    v_minutes_late := EXTRACT(EPOCH FROM (v_check_in_time::time - v_shift_start_time)) / 60;
    
    -- Deduct 1 point per full 5 minutes late
    v_points := 5 - (v_minutes_late / 5)::integer;
    
    -- Minimum 0 points
    IF v_points < 0 THEN
      v_points := 0;
    END IF;
  END IF;
  
  -- Create check-in record with PENDING status
  INSERT INTO check_ins (user_id, check_in_time, shift_type, is_late, minutes_late, points_awarded, status)
  VALUES (p_user_id, v_check_in_time, p_shift_type, v_is_late, v_minutes_late, v_points, 'pending')
  RETURNING id INTO v_check_in_id;
  
  -- Create notification for admins
  INSERT INTO notifications (user_id, title, message, type)
  SELECT 
    id,
    'Neue Check-In Anfrage',
    (SELECT full_name FROM profiles WHERE id = p_user_id) || ' hat sich eingecheckt und wartet auf Bestätigung',
    'check_in'
  FROM profiles
  WHERE role = 'admin';
  
  RETURN jsonb_build_object(
    'check_in_id', v_check_in_id,
    'is_late', v_is_late,
    'minutes_late', v_minutes_late,
    'points_awarded', v_points,
    'status', 'pending'
  );
END;
$$;

-- Function to approve check-in
CREATE OR REPLACE FUNCTION approve_check_in(
  p_check_in_id uuid,
  p_admin_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_check_in record;
  v_reason text;
BEGIN
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
    'check_in_approved'
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'points_awarded', v_check_in.points_awarded
  );
END;
$$;

-- Function to reject check-in
CREATE OR REPLACE FUNCTION reject_check_in(
  p_check_in_id uuid,
  p_admin_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_check_in record;
BEGIN
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
    'check_in_rejected'
  );
  
  RETURN jsonb_build_object(
    'success', true
  );
END;
$$;
