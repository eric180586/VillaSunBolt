/*
  # Fix Check-In Notifications - Use Correct Type

  1. Problem
    - Used 'checkin_late' and 'checkin_success' but only 'check_in' is allowed
    
  2. Solution
    - Use 'check_in' type for all check-in notifications
    - Differentiate by title and message content
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
  v_points_awarded integer := 0;
  v_points_penalty integer := 0;
  v_has_existing_checkin boolean;
  v_reason text;
  v_actual_check_in_time time;
  v_user_name text;
  v_admin_record record;
BEGIN
  -- Get current time in Cambodia timezone
  v_check_in_time := now() AT TIME ZONE 'Asia/Phnom_Penh';
  v_check_in_date := DATE(v_check_in_time);
  v_actual_check_in_time := v_check_in_time::time;

  -- Get user name for notifications
  SELECT full_name INTO v_user_name FROM profiles WHERE id = p_user_id;

  -- Check for existing check-in today
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

  -- Calculate if late and by how many minutes
  IF v_actual_check_in_time > v_deadline_time THEN
    -- Calculate minutes late
    v_minutes_late := EXTRACT(EPOCH FROM (v_actual_check_in_time - v_deadline_time)) / 60;
    
    -- Calculate penalty: -1 per full 5 minutes
    v_points_penalty := -(v_minutes_late / 5)::integer;
    
    v_points_awarded := v_points_penalty;
    v_reason := 'Late check-in (' || v_minutes_late || ' min late): ' || v_points_penalty || ' points';
  ELSE
    -- On time: +5 points
    v_points_awarded := 5;
    v_reason := 'Punctual check-in: +5 points';
  END IF;

  -- Insert check-in record and get ID
  INSERT INTO check_ins (
    user_id,
    check_in_time,
    shift_type,
    late_reason,
    check_in_date
  ) VALUES (
    p_user_id,
    v_check_in_time,
    p_shift_type,
    p_late_reason,
    v_check_in_date
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
    v_reason,
    'check_in',
    p_user_id
  );

  -- Update daily point goals
  PERFORM update_daily_point_goals_for_user(p_user_id, v_check_in_date);

  -- Send notification to USER
  IF v_minutes_late > 0 THEN
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message
    ) VALUES (
      p_user_id,
      'check_in',
      'Late Check-in',
      'You checked in ' || v_minutes_late || ' minutes late. Penalty: ' || v_points_penalty || ' points.'
    );
  ELSE
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message
    ) VALUES (
      p_user_id,
      'check_in',
      'Check-in Successful',
      'Check-in successful! +5 points awarded.'
    );
  END IF;

  -- Send notification to ALL ADMINS
  FOR v_admin_record IN 
    SELECT id FROM profiles WHERE role = 'admin'
  LOOP
    IF v_minutes_late > 0 THEN
      INSERT INTO notifications (
        user_id,
        type,
        title,
        message
      ) VALUES (
        v_admin_record.id,
        'check_in',
        'Staff Late Check-in',
        v_user_name || ' checked in ' || v_minutes_late || ' minutes late (' || p_shift_type || ' shift). Penalty: ' || v_points_penalty || ' points.'
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
        v_user_name || ' checked in on time (' || p_shift_type || ' shift). +5 points awarded.'
      );
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Check-in successful',
    'check_in_id', v_check_in_id,
    'points_awarded', v_points_awarded,
    'minutes_late', v_minutes_late
  );
END;
$$;
