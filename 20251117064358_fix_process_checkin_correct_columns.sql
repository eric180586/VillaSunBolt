/*
  # Fix process_check_in Function - Correct Column Names
  
  1. Changes
    - Use points_change instead of points
    - Use reason instead of description
    - Use category 'check_in' (not checkin_late/checkin_on_time)
    - Use created_by instead of letting it be NULL
*/

CREATE OR REPLACE FUNCTION public.process_check_in(
  p_user_id uuid,
  p_shift_type text,
  p_late_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_check_in_time timestamptz;
  v_check_in_date date;
  v_check_in_id uuid;
  v_deadline_time time;
  v_minutes_late integer := 0;
  v_has_existing_checkin boolean;
  v_actual_check_in_time time;
  v_user_name text;
  v_admin_record record;
  v_is_late boolean := false;
  v_cambodia_time timestamptz;
  v_points_awarded integer := 0;
BEGIN
  -- Get ACTUAL current time (UTC)
  v_check_in_time := NOW();
  
  -- Convert to Cambodia timezone for calculations
  v_cambodia_time := v_check_in_time AT TIME ZONE 'Asia/Phnom_Penh';
  v_check_in_date := DATE(v_cambodia_time);
  v_actual_check_in_time := v_cambodia_time::time;

  -- Get user name for notifications
  SELECT full_name INTO v_user_name FROM profiles WHERE id = p_user_id;

  -- Check for existing check-in today (using Cambodia date)
  SELECT EXISTS(
    SELECT 1 FROM check_ins
    WHERE user_id = p_user_id
    AND DATE(check_in_time AT TIME ZONE 'Asia/Phnom_Penh') = v_check_in_date
  ) INTO v_has_existing_checkin;

  IF v_has_existing_checkin THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'You have already checked in today'
    );
  END IF;

  -- Determine deadline based on shift type
  IF p_shift_type = 'morning' THEN
    v_deadline_time := '09:00:59'::time;
  ELSIF p_shift_type = 'late' THEN
    v_deadline_time := '15:00:59'::time;
  ELSE
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Invalid shift type. Must be morning or late.'
    );
  END IF;

  -- Calculate if late and by how many minutes (using Cambodia time)
  IF v_actual_check_in_time > v_deadline_time THEN
    v_minutes_late := EXTRACT(EPOCH FROM (v_actual_check_in_time - v_deadline_time)) / 60;
    v_is_late := true;
    -- Penalty: -1 point per 5 minutes late
    v_points_awarded := -(v_minutes_late / 5)::integer;
  ELSE
    -- On time: +5 points
    v_points_awarded := 5;
  END IF;

  -- Insert check-in record with APPROVED status and immediate points
  INSERT INTO check_ins (
    user_id,
    check_in_time,
    shift_type,
    late_reason,
    check_in_date,
    is_late,
    minutes_late,
    status,
    points_awarded,
    approved_at
  ) VALUES (
    p_user_id,
    v_check_in_time,
    p_shift_type,
    p_late_reason,
    v_check_in_date,
    v_is_late,
    v_minutes_late,
    'approved',
    v_points_awarded,
    NOW()
  )
  RETURNING id INTO v_check_in_id;

  -- Award points immediately with CORRECT column names
  INSERT INTO points_history (
    user_id,
    points_change,
    reason,
    category,
    created_by
  ) VALUES (
    p_user_id,
    v_points_awarded,
    CASE 
      WHEN v_is_late THEN 'Late check-in (' || v_minutes_late || ' min late): ' || v_points_awarded || ' points penalty'
      ELSE 'On-time check-in: +' || v_points_awarded || ' points'
    END,
    'check_in',  -- Use allowed category
    p_user_id
  );

  -- Send notification to USER
  INSERT INTO notifications (
    user_id,
    type,
    title,
    message
  ) VALUES (
    p_user_id,
    'check_in',
    CASE WHEN v_is_late THEN 'Check-in Late' ELSE 'Check-in Successful' END,
    CASE 
      WHEN v_is_late THEN 'You checked in ' || v_minutes_late || ' minutes late. Points: ' || v_points_awarded
      ELSE 'You checked in on time! Points awarded: +' || v_points_awarded
    END
  );

  -- Send notification to ADMINS (informational only)
  FOR v_admin_record IN 
    SELECT id FROM profiles WHERE role = 'admin'
  LOOP
    IF v_is_late THEN
      INSERT INTO notifications (
        user_id,
        type,
        title,
        message
      ) VALUES (
        v_admin_record.id,
        'check_in',
        'Staff Late Check-in',
        v_user_name || ' checked in ' || v_minutes_late || ' minutes late (' || p_shift_type || ' shift). Penalty: ' || v_points_awarded || ' points.'
      );
    ELSE
      INSERT INTO notifications (
        user_id,
        type,
        title,
        message
      ) VALUES (
        v_admin_record.id,
        'check_in',
        'Staff Check-in',
        v_user_name || ' checked in on time (' || p_shift_type || ' shift). Points awarded: +' || v_points_awarded
      );
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Check-in successful',
    'check_in_id', v_check_in_id,
    'minutes_late', v_minutes_late,
    'is_late', v_is_late,
    'points_awarded', v_points_awarded
  );
END;
$$;
