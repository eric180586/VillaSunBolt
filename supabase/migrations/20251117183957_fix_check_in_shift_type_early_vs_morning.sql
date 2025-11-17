/*
  # Fix Check-In Shift Type Mismatch
  
  1. Problem
    - Frontend uses 'early' and 'late'
    - Backend function expects 'morning' and 'late'
    - CRITICAL BUG preventing check-ins
  
  2. Solution
    - Change function to accept 'early' instead of 'morning'
    - Update all logic accordingly
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
  v_check_in_time := NOW();
  v_cambodia_time := v_check_in_time AT TIME ZONE 'Asia/Phnom_Penh';
  v_check_in_date := DATE(v_cambodia_time);
  v_actual_check_in_time := v_cambodia_time::time;

  SELECT full_name INTO v_user_name FROM profiles WHERE id = p_user_id;

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

  -- FIXED: Accept 'early' instead of 'morning'
  IF p_shift_type = 'early' THEN
    v_deadline_time := '09:00:59'::time;
  ELSIF p_shift_type = 'late' THEN
    v_deadline_time := '15:00:59'::time;
  ELSE
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Invalid shift type. Must be early or late.'
    );
  END IF;

  IF v_actual_check_in_time > v_deadline_time THEN
    v_minutes_late := EXTRACT(EPOCH FROM (v_actual_check_in_time - v_deadline_time)) / 60;
    v_is_late := true;
    v_points_awarded := -(v_minutes_late / 5)::integer;
  ELSE
    v_points_awarded := 5;
  END IF;

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
    'check_in',
    p_user_id
  );

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
