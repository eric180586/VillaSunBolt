/*
  # Fix Check-in Points Logic - FINAL

  1. New Logic (CORRECT)
    - Frühschicht: bis 9:00:59 → +5 Punkte
    - Ab 9:01:00 → -1 Punkt (kein +5)
    - Ab 9:06:00 → -2 Punkte
    - Ab 9:11:00 → -3 Punkte
    
    - Spätschicht: bis 15:00:59 → +5 Punkte
    - Ab 15:01:00 → -1 Punkt (kein +5)
    - Ab 15:06:00 → -2 Punkte
    - Ab 15:11:00 → -3 Punkte
  
  2. Key Changes
    - NO +5 Punkte wenn zu spät
    - Nur Minuspunkte ab der ersten Sekunde nach Deadline
*/

-- Drop old process_check_in function
DROP FUNCTION IF EXISTS process_check_in(uuid, text, text);

-- Create new process_check_in with correct logic
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
  v_deadline_time time;
  v_minutes_late integer := 0;
  v_points_awarded integer := 0;
  v_points_penalty integer := 0;
  v_has_existing_checkin boolean;
  v_reason text;
  v_actual_check_in_time time;
BEGIN
  -- Get current time in Cambodia timezone
  v_check_in_time := now() AT TIME ZONE 'Asia/Phnom_Penh';
  v_check_in_date := DATE(v_check_in_time);
  v_actual_check_in_time := v_check_in_time::time;

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
    -- Calculate minutes late (from deadline + 1 second)
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

  -- Insert check-in record
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
  );

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

  -- Send notification if late
  IF v_minutes_late > 0 THEN
    INSERT INTO notifications (
      user_id,
      type,
      message,
      priority
    ) VALUES (
      p_user_id,
      'checkin_late',
      'You checked in ' || v_minutes_late || ' minutes late. Penalty: ' || v_points_penalty || ' points.',
      'medium'
    );
  ELSE
    INSERT INTO notifications (
      user_id,
      type,
      message,
      priority
    ) VALUES (
      p_user_id,
      'checkin_success',
      'Check-in successful! +5 points awarded.',
      'low'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Check-in successful',
    'points_awarded', v_points_awarded,
    'minutes_late', v_minutes_late
  );
END;
$$;