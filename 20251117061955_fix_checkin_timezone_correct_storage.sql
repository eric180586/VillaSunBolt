/*
  # Fix Check-In Timezone Storage
  
  1. Problem
    - check_in_time speichert Cambodia Zeit als UTC
    - Beim Anzeigen wird nochmal +7h addiert → 20:08 statt 13:08
  
  2. Solution
    - Speichere NOW() (echte UTC Zeit)
    - Konvertiere nur für Berechnungen zu Cambodia Zeit
    - Display macht dann automatisch die korrekte Konvertierung
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
  END IF;

  -- Insert check-in record with ACTUAL UTC time
  INSERT INTO check_ins (
    user_id,
    check_in_time,
    shift_type,
    late_reason,
    check_in_date,
    is_late,
    minutes_late,
    status,
    points_awarded
  ) VALUES (
    p_user_id,
    v_check_in_time,  -- Store actual UTC time
    p_shift_type,
    p_late_reason,
    v_check_in_date,  -- Store Cambodia date
    v_is_late,
    v_minutes_late,
    'pending',
    0
  )
  RETURNING id INTO v_check_in_id;

  -- Send notification to USER
  INSERT INTO notifications (
    user_id,
    type,
    title,
    message
  ) VALUES (
    p_user_id,
    'check_in',
    'Check-in Submitted',
    'Your check-in has been submitted and is awaiting admin approval.'
  );

  -- Send notification to ALL ADMINS for approval
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
        'Check-in Approval Required',
        v_user_name || ' checked in ' || v_minutes_late || ' minutes late (' || p_shift_type || ' shift). Please review and approve.'
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
        'Check-in Approval Required',
        v_user_name || ' checked in on time (' || p_shift_type || ' shift). Please review and approve.'
      );
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Check-in submitted, awaiting admin approval',
    'check_in_id', v_check_in_id,
    'minutes_late', v_minutes_late,
    'is_late', v_is_late
  );
END;
$$;
