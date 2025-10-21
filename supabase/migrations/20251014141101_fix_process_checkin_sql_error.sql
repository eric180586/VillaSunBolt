/*
  # Fix process_check_in SQL Error

  ## Problem
  - Current function uses jsonb_array_elements() in WHERE clause
  - PostgreSQL error: "set-returning functions are not allowed in WHERE"
  - Check-in is completely broken
  
  ## Solution
  - Rewrite shift detection logic using LATERAL join
  - Use proper JSON querying without set-returning functions in WHERE
  - Simplify logic for better performance and reliability
  
  ## Changes
  - Complete rewrite of process_check_in function
  - Fixed shift detection from schedule
  - Proper JSONB array handling
*/

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
  v_today_date text;
BEGIN
  v_check_in_time := now();
  v_today_date := DATE(v_check_in_time AT TIME ZONE 'Asia/Phnom_Penh')::text;
  
  -- Auto-detect shift if not provided
  IF p_shift_type IS NULL THEN
    -- Check schedule for today using proper JSON querying
    SELECT shift_info->>'shift' INTO v_schedule_shift
    FROM weekly_schedules ws,
         LATERAL jsonb_array_elements(ws.shifts) AS shift_info
    WHERE ws.staff_id = p_user_id
      AND ws.is_published = true
      AND shift_info->>'date' = v_today_date
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
  
  -- Create check-in record with late_reason (pending approval)
  INSERT INTO check_ins (user_id, check_in_time, shift_type, is_late, minutes_late, points_awarded, late_reason, admin_approved)
  VALUES (p_user_id, v_check_in_time, v_shift_type, v_is_late, v_minutes_late, v_points, p_late_reason, false)
  RETURNING id INTO v_check_in_id;
  
  -- Send notification to admins about new check-in
  INSERT INTO notifications (user_id, title, message, type, priority)
  SELECT 
    id,
    'New Check-In',
    (SELECT full_name FROM profiles WHERE id = p_user_id) || ' has checked in and is waiting for approval',
    'checkin_pending',
    'high'
  FROM profiles
  WHERE role = 'admin';
  
  -- Return result (points NOT awarded yet - waiting for admin approval)
  RETURN jsonb_build_object(
    'check_in_id', v_check_in_id,
    'is_late', v_is_late,
    'minutes_late', v_minutes_late,
    'points_awarded', v_points,
    'penalty_points', v_penalty_points,
    'total_points', v_points + v_penalty_points,
    'admin_approved', false,
    'message', 'Check-in submitted, waiting for admin approval'
  );
END;
$$;
