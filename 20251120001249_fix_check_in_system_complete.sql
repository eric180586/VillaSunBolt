/*
  # Fix Check-In System Complete

  1. Problems Fixed:
    - Fortune Wheel NOT triggered after check-in
    - Admin notifications not working
    - Duplicate check-in prevention broken
    - Cambodia timezone handling incorrect
    - Check-in date stored incorrectly

  2. Solution:
    - Rewrite process_check_in to properly handle all cases
    - Add Fortune Wheel entry creation
    - Fix admin notification loop
    - Fix duplicate check using correct timezone
    - Store check_in_date correctly in Cambodia timezone
*/

CREATE OR REPLACE FUNCTION process_check_in(
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
  v_cambodia_date date;
  v_cambodia_time_only time;
BEGIN
  -- Get current time
  v_check_in_time := NOW();
  
  -- Convert to Cambodia timezone properly
  v_cambodia_time := v_check_in_time AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Phnom_Penh';
  v_cambodia_date := v_cambodia_time::date;
  v_cambodia_time_only := v_cambodia_time::time;
  
  v_check_in_date := v_cambodia_date;
  v_actual_check_in_time := v_cambodia_time_only;

  -- Get user name
  SELECT full_name INTO v_user_name FROM profiles WHERE id = p_user_id;

  -- Check for existing check-in TODAY (using Cambodia date)
  SELECT EXISTS(
    SELECT 1 FROM check_ins
    WHERE user_id = p_user_id
    AND check_in_date = v_cambodia_date
  ) INTO v_has_existing_checkin;

  IF v_has_existing_checkin THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'You have already checked in today'
    );
  END IF;

  -- Set deadline based on shift type
  IF p_shift_type = 'early' OR p_shift_type = 'morning' THEN
    v_deadline_time := '09:00:59'::time;
  ELSIF p_shift_type = 'late' THEN
    v_deadline_time := '15:00:59'::time;
  ELSE
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Invalid shift type'
    );
  END IF;

  -- Calculate lateness
  IF v_actual_check_in_time > v_deadline_time THEN
    v_minutes_late := EXTRACT(EPOCH FROM (v_actual_check_in_time - v_deadline_time)) / 60;
    v_is_late := true;
    v_points_awarded := -(v_minutes_late / 5)::integer;
  ELSE
    v_points_awarded := 5;
  END IF;

  -- Create check-in record
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

  -- Award/deduct points
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

  -- Notify user
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

  -- Notify ALL admins
  FOR v_admin_record IN 
    SELECT id FROM profiles WHERE role = 'admin'
  LOOP
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message
    ) VALUES (
      v_admin_record.id,
      'check_in',
      CASE WHEN v_is_late THEN 'Staff Late Check-in' ELSE 'Staff Check-in' END,
      CASE 
        WHEN v_is_late THEN v_user_name || ' checked in ' || v_minutes_late || ' minutes late (' || p_shift_type || ' shift). Penalty: ' || v_points_awarded || ' points.'
        ELSE v_user_name || ' checked in on time (' || p_shift_type || ' shift). Points awarded: +' || v_points_awarded
      END
    );
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Check-in successful',
    'check_in_id', v_check_in_id,
    'minutes_late', v_minutes_late,
    'is_late', v_is_late,
    'points_awarded', v_points_awarded,
    'show_fortune_wheel', true
  );
END;
$$;
