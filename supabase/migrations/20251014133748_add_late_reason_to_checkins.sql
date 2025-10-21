/*
  # Add Late Reason to Check-Ins

  ## Problem
  - When staff check in late, they cannot provide an explanation
  - Admin cannot see why the staff member was late
  
  ## Solution
  - Add late_reason field to check_ins table
  - Update process_check_in function to accept and store the reason
  - Frontend will prompt for reason when check-in is late
  
  ## Changes
  - Add late_reason column (text, nullable)
  - Update process_check_in function signature
*/

-- Add late_reason column to check_ins
ALTER TABLE check_ins
ADD COLUMN IF NOT EXISTS late_reason text;

-- Update the process_check_in function to accept late_reason
CREATE OR REPLACE FUNCTION process_check_in(
  p_user_id uuid,
  p_shift_type text DEFAULT NULL,
  p_late_reason text DEFAULT NULL
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
  v_penalty_points integer := 0;
  v_check_in_id uuid;
  v_reason text;
  v_shift_type text;
  v_schedule_shift text;
BEGIN
  v_check_in_time := now();
  
  -- Auto-detect shift if not provided
  IF p_shift_type IS NULL THEN
    -- Check schedule for today
    SELECT 
      CASE 
        WHEN (shifts -> (
          SELECT jsonb_array_elements(shifts)::jsonb ->> 'date'
          FROM weekly_schedules
          WHERE staff_id = p_user_id
            AND is_published = true
          LIMIT 1
        ) @> jsonb_build_object('date', DATE(v_check_in_time)::text))
        THEN (
          SELECT jsonb_array_elements(shifts)::jsonb ->> 'shift'
          FROM weekly_schedules ws
          WHERE ws.staff_id = p_user_id
            AND ws.is_published = true
            AND jsonb_array_elements(ws.shifts)::jsonb ->> 'date' = DATE(v_check_in_time)::text
          LIMIT 1
        )
        ELSE NULL
      END
    INTO v_schedule_shift
    FROM weekly_schedules
    WHERE staff_id = p_user_id
      AND is_published = true
    LIMIT 1;
    
    -- If scheduled shift found, use it; otherwise detect based on time
    IF v_schedule_shift = 'early' THEN
      v_shift_type := 'früh';
    ELSIF v_schedule_shift = 'late' THEN
      v_shift_type := 'spät';
    ELSIF v_check_in_time::time < '13:00:00'::time THEN
      v_shift_type := 'früh';
    ELSE
      v_shift_type := 'spät';
    END IF;
  ELSE
    v_shift_type := p_shift_type;
  END IF;
  
  -- Determine shift start time
  IF v_shift_type = 'früh' THEN
    v_shift_start_time := '09:00:00'::time;
  ELSE
    v_shift_start_time := '15:00:00'::time;
  END IF;
  
  -- Calculate if late and by how much
  IF v_check_in_time::time > v_shift_start_time THEN
    v_is_late := true;
    v_minutes_late := EXTRACT(EPOCH FROM (v_check_in_time::time - v_shift_start_time)) / 60;
    
    -- Calculate bonus points (1 point less per 5 min late)
    v_points := 5 - (v_minutes_late / 5)::integer;
    
    -- Minimum 0 points for bonus
    IF v_points < 0 THEN
      v_points := 0;
    END IF;
    
    -- PENALTY: 25+ minutes late = -5 additional points
    IF v_minutes_late >= 25 THEN
      v_penalty_points := -5;
    END IF;
  END IF;
  
  -- Create check-in record with late_reason
  INSERT INTO check_ins (user_id, check_in_time, shift_type, is_late, minutes_late, points_awarded, late_reason)
  VALUES (p_user_id, v_check_in_time, v_shift_type, v_is_late, v_minutes_late, v_points, p_late_reason)
  RETURNING id INTO v_check_in_id;
  
  -- Award positive points if any
  IF v_points > 0 THEN
    v_reason := 'Pünktliches Einchecken - ' || v_shift_type || 'schicht';
    
    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (p_user_id, v_points, v_reason, 'punctuality', p_user_id);
  END IF;
  
  -- Apply penalty if late >= 25 minutes
  IF v_penalty_points < 0 THEN
    v_reason := 'Verspätetes Einchecken (' || v_minutes_late || ' Min.) - ' || v_shift_type || 'schicht';
    
    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (p_user_id, v_penalty_points, v_reason, 'penalty', p_user_id);
  END IF;
  
  RETURN jsonb_build_object(
    'check_in_id', v_check_in_id,
    'is_late', v_is_late,
    'minutes_late', v_minutes_late,
    'points_awarded', v_points,
    'penalty_points', v_penalty_points,
    'total_points', v_points + v_penalty_points
  );
END;
$$;
