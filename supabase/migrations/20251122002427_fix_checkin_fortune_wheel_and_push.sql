/*
  # Fix Check-In: Fortune Wheel & Push Notifications
  
  1. Changes:
    - Add push notification call to process_check_in function
    - Ensure Fortune Wheel appears after check-in
    - Add proper notification translations
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
  v_cambodia_time timestamp;
  v_points_awarded integer := 0;
  v_notification_id uuid;
BEGIN
  v_check_in_time := NOW();
  
  -- Convert UTC to Cambodia time
  v_cambodia_time := v_check_in_time AT TIME ZONE 'Asia/Phnom_Penh';
  v_check_in_date := v_cambodia_time::date;
  v_actual_check_in_time := v_cambodia_time::time;

  SELECT full_name INTO v_user_name FROM profiles WHERE id = p_user_id;

  -- Check if already checked in today
  SELECT EXISTS(
    SELECT 1 FROM check_ins
    WHERE user_id = p_user_id
    AND check_in_date = v_check_in_date
  ) INTO v_has_existing_checkin;

  IF v_has_existing_checkin THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'You have already checked in today',
      'check_in_id', NULL,
      'show_fortune_wheel', false
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
      'message', 'Invalid shift type',
      'check_in_id', NULL,
      'show_fortune_wheel', false
    );
  END IF;

  -- Calculate if late
  IF v_actual_check_in_time > v_deadline_time THEN
    v_minutes_late := EXTRACT(EPOCH FROM (v_actual_check_in_time - v_deadline_time)) / 60;
    v_is_late := true;
    v_points_awarded := -(v_minutes_late / 5)::integer;
  ELSE
    v_points_awarded := 5;
  END IF;

  -- Insert check-in record
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

  -- Update user points
  UPDATE profiles
  SET total_points = total_points + v_points_awarded
  WHERE id = p_user_id;

  -- Record in points history
  INSERT INTO points_history (
    user_id,
    points_change,
    category,
    reason
  ) VALUES (
    p_user_id,
    v_points_awarded,
    'check_in',
    CASE 
      WHEN v_is_late THEN 'Check-in ' || v_minutes_late || ' minutes late'
      ELSE 'Punctual check-in'
    END
  );

  -- Notify user with translations
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
  )
  RETURNING id INTO v_notification_id;

  -- Add notification translations
  INSERT INTO notification_translations (notification_id, language, title, message)
  VALUES 
    (v_notification_id, 'en', 
      CASE WHEN v_is_late THEN 'Check-in Late' ELSE 'Check-in Successful' END,
      CASE WHEN v_is_late THEN 'You checked in ' || v_minutes_late || ' minutes late. Points: ' || v_points_awarded
           ELSE 'You checked in on time! Points awarded: +' || v_points_awarded END),
    (v_notification_id, 'de',
      CASE WHEN v_is_late THEN 'Verspäteter Check-in' ELSE 'Check-in erfolgreich' END,
      CASE WHEN v_is_late THEN 'Du hast dich ' || v_minutes_late || ' Minuten verspätet eingecheckt. Punkte: ' || v_points_awarded
           ELSE 'Du hast dich pünktlich eingecheckt! Punkte vergeben: +' || v_points_awarded END),
    (v_notification_id, 'km',
      CASE WHEN v_is_late THEN 'ចូលយឺត' ELSE 'ចូលជោគជ័យ' END,
      CASE WHEN v_is_late THEN 'អ្នកបានចូលយឺត ' || v_minutes_late || ' នាទី។ ពិន្ទុ៖ ' || v_points_awarded
           ELSE 'អ្នកបានចូលទាន់ពេល! ពិន្ទុ៖ +' || v_points_awarded END);

  -- Send push notification to user
  PERFORM send_push_notification(
    p_user_id,
    v_notification_id
  );

  -- Notify admins
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
    )
    RETURNING id INTO v_notification_id;

    -- Add admin notification translations
    INSERT INTO notification_translations (notification_id, language, title, message)
    VALUES 
      (v_notification_id, 'en',
        CASE WHEN v_is_late THEN 'Staff Late Check-in' ELSE 'Staff Check-in' END,
        CASE WHEN v_is_late THEN v_user_name || ' checked in ' || v_minutes_late || ' minutes late (' || p_shift_type || ' shift). Penalty: ' || v_points_awarded || ' points.'
             ELSE v_user_name || ' checked in on time (' || p_shift_type || ' shift). Points awarded: +' || v_points_awarded END),
      (v_notification_id, 'de',
        CASE WHEN v_is_late THEN 'Mitarbeiter verspäteter Check-in' ELSE 'Mitarbeiter Check-in' END,
        CASE WHEN v_is_late THEN v_user_name || ' hat sich ' || v_minutes_late || ' Minuten verspätet eingecheckt (' || p_shift_type || ' Schicht). Strafe: ' || v_points_awarded || ' Punkte.'
             ELSE v_user_name || ' hat sich pünktlich eingecheckt (' || p_shift_type || ' Schicht). Punkte vergeben: +' || v_points_awarded END),
      (v_notification_id, 'km',
        CASE WHEN v_is_late THEN 'បុគ្គលិកចូលយឺត' ELSE 'បុគ្គលិកចូល' END,
        CASE WHEN v_is_late THEN v_user_name || ' បានចូលយឺត ' || v_minutes_late || ' នាទី (' || p_shift_type || ' វេន)។ ពិន័យ៖ ' || v_points_awarded || ' ពិន្ទុ។'
             ELSE v_user_name || ' បានចូលទាន់ពេល (' || p_shift_type || ' វេន)។ ពិន្ទុ៖ +' || v_points_awarded END);

    -- Send push notification to admin
    PERFORM send_push_notification(
      v_admin_record.id,
      v_notification_id
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
