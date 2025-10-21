/*
  # Prevent Duplicate Check-ins Same Day

  ## Problem
  - Users can check-in multiple times per day
  - Leads to duplicate points being awarded
  - Example: Sunny checked in 3 times and got 15 points instead of 5

  ## Solution
  - Add check at beginning of process_check_in to prevent duplicates
  - Return error if user already checked in today
  - Only allow one check-in per user per day
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
  v_existing_checkin_count integer;
BEGIN
  v_check_in_time := now();
  v_today_date := DATE(v_check_in_time AT TIME ZONE 'Asia/Phnom_Penh')::text;

  -- CHECK: Prevent duplicate check-ins on same day
  SELECT COUNT(*) INTO v_existing_checkin_count
  FROM check_ins
  WHERE user_id = p_user_id
  AND DATE(check_in_time AT TIME ZONE 'Asia/Phnom_Penh')::text = v_today_date;

  IF v_existing_checkin_count > 0 THEN
    RAISE EXCEPTION 'Du hast heute bereits eingecheckt. Nur ein Check-in pro Tag erlaubt.';
  END IF;

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
    
    v_points := 5 - (v_minutes_late / 5)::integer;
    
    IF v_points < 0 THEN
      v_points := 0;
    END IF;
    
    IF v_minutes_late >= 25 THEN
      v_penalty_points := -5;
    END IF;
  END IF;

  -- Create check-in record
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
