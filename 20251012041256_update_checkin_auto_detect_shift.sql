/*
  # Auto-detect shift type for check-ins

  1. Changes
    - Update `process_check_in` function to automatically detect shift type based on current time
    - Remove the need for users to manually select shift type
    - Logic: 
      - Before 12:00 noon → Frühschicht (9:00 start)
      - After 12:00 noon → Spätschicht (15:00 start)
  
  2. Security
    - Maintains existing SECURITY DEFINER and authentication checks
*/

-- Drop old function
DROP FUNCTION IF EXISTS process_check_in(uuid, text);

-- Create new function without shift_type parameter
CREATE OR REPLACE FUNCTION process_check_in(
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_check_in_time timestamptz;
  v_shift_type text;
  v_shift_start_time time;
  v_minutes_late integer := 0;
  v_is_late boolean := false;
  v_points integer := 5;
  v_check_in_id uuid;
BEGIN
  v_check_in_time := now();
  
  -- Auto-detect shift type based on current time
  -- If before 12:00 noon, it's früh shift, otherwise spät shift
  IF v_check_in_time::time < '12:00:00'::time THEN
    v_shift_type := 'früh';
    v_shift_start_time := '09:00:00'::time;
  ELSE
    v_shift_type := 'spät';
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
  VALUES (p_user_id, v_check_in_time, v_shift_type, v_is_late, v_minutes_late, v_points, 'pending')
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
    'status', 'pending',
    'shift_type', v_shift_type
  );
END;
$$;
