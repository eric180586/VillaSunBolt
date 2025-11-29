/*
  # Fix Check-In: Manual Approval Required
  
  ## Problem
  - Check-Ins werden automatisch approved (status = 'approved')
  - Punkte werden automatisch vergeben (penalty points)
  - Admin hat keine Kontrolle
  
  ## Solution
  - Check-Ins erhalten status = 'pending'
  - KEINE automatische Punktevergabe
  - Admin muss JEDEN Check-In manuell freigeben
  - Nur bei Admin-Approval werden Punkte vergeben
  
  ## Changes
  1. process_check_in: Status auf 'pending' setzen
  2. process_check_in: KEINE automatische Punktevergabe
  3. Notification an Admin bei jedem Check-In
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
  v_shift_type text;
  v_schedule_shift text;
  v_today_date text;
  v_existing_checkin_count integer;
  v_user_name text;
BEGIN
  v_check_in_time := now();
  v_today_date := DATE(v_check_in_time AT TIME ZONE 'Asia/Phnom_Penh')::text;
  
  -- Check for existing check-in today
  SELECT COUNT(*) INTO v_existing_checkin_count
  FROM check_ins
  WHERE user_id = p_user_id
  AND DATE(check_in_time AT TIME ZONE 'Asia/Phnom_Penh')::text = v_today_date;
  
  IF v_existing_checkin_count > 0 THEN
    RAISE EXCEPTION 'Du hast heute bereits eingecheckt. Nur ein Check-in pro Tag erlaubt.';
  END IF;
  
  -- Get user name for notification
  SELECT full_name INTO v_user_name
  FROM profiles
  WHERE id = p_user_id;
  
  -- Auto-detect shift if not provided
  IF p_shift_type IS NULL THEN
    SELECT (shift_data->>'shift')
    INTO v_schedule_shift
    FROM weekly_schedules ws,
    jsonb_array_elements(ws.shifts) AS shift_data
    WHERE ws.staff_id = p_user_id
    AND ws.is_published = true
    AND shift_data->>'date' = v_today_date
    LIMIT 1;
    
    IF v_schedule_shift = 'early' THEN
      v_shift_type := 'früh';
    ELSIF v_schedule_shift = 'late' THEN
      v_shift_type := 'spät';
    ELSIF (v_check_in_time AT TIME ZONE 'Asia/Phnom_Penh')::time < '13:00:00'::time THEN
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
  
  -- Calculate lateness (in Cambodia timezone)
  IF (v_check_in_time AT TIME ZONE 'Asia/Phnom_Penh')::time > v_shift_start_time THEN
    v_is_late := true;
    v_minutes_late := EXTRACT(EPOCH FROM ((v_check_in_time AT TIME ZONE 'Asia/Phnom_Penh')::time - v_shift_start_time)) / 60;
    
    -- Calculate potential points (will be shown to admin)
    v_points := 5 - (v_minutes_late / 5)::integer;
    IF v_points < 0 THEN
      v_points := 0;
    END IF;
    
    -- Calculate penalty for 25+ minutes late
    IF v_minutes_late >= 25 THEN
      v_penalty_points := -5;
    END IF;
  END IF;
  
  -- Create check-in with PENDING status (requires admin approval)
  INSERT INTO check_ins (
    user_id, 
    check_in_time, 
    check_in_date, 
    shift_type, 
    is_late, 
    minutes_late, 
    points_awarded, 
    late_reason, 
    status
  )
  VALUES (
    p_user_id, 
    v_check_in_time, 
    v_today_date, 
    v_shift_type, 
    v_is_late, 
    v_minutes_late, 
    v_points,  -- Potential points (not awarded yet)
    p_late_reason, 
    'pending'  -- PENDING - requires admin approval
  )
  RETURNING id INTO v_check_in_id;
  
  -- Send notification to ALL admins
  INSERT INTO notifications (user_id, title, message, type, priority)
  SELECT 
    p.id,
    'Neuer Check-In',
    v_user_name || ' hat sich ' || 
    CASE 
      WHEN v_is_late THEN v_minutes_late::text || ' Min. zu spät '
      ELSE 'pünktlich '
    END ||
    'eingecheckt (' || v_shift_type || 'schicht) und wartet auf Freigabe.',
    'checkin_pending',
    'high'
  FROM profiles p
  WHERE p.role = 'admin';
  
  -- Return result (NO points awarded yet - waiting for admin approval)
  RETURN jsonb_build_object(
    'check_in_id', v_check_in_id,
    'is_late', v_is_late,
    'minutes_late', v_minutes_late,
    'points_awarded', v_points,
    'penalty_points', v_penalty_points,
    'total_points', v_points + v_penalty_points,
    'status', 'pending',
    'message', 'Check-in eingereicht. Warte auf Admin-Freigabe.'
  );
END;
$$;
