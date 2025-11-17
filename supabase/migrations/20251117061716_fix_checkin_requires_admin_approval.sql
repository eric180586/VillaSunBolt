/*
  # Fix Check-In System - Require Admin Approval
  
  1. Changes
    - Check-ins start with status 'pending' instead of auto-approved
    - Admin must approve check-ins via CheckInApproval component
    - Points are awarded AFTER approval, not immediately
    - Notifications inform admin of pending check-ins
  
  2. Security
    - Only admins can approve check-ins
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
    v_minutes_late := EXTRACT(EPOCH FROM (v_actual_check_in_time - v_deadline_time)) / 60;
    v_is_late := true;
  END IF;

  -- Insert check-in record with PENDING status (awaiting admin approval)
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
    v_check_in_time,
    p_shift_type,
    p_late_reason,
    v_check_in_date,
    v_is_late,
    v_minutes_late,
    'pending',  -- Status pending until admin approves
    0  -- Points will be awarded upon approval
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
