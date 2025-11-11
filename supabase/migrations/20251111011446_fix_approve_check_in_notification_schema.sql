/*
  # Fix approve_check_in to use correct notification schema

  notifications table has:
  - user_id
  - title (required)
  - message
  - type
  - is_read
  - link
  - created_at

  NO priority column!
*/

CREATE OR REPLACE FUNCTION public.approve_check_in(
  p_check_in_id uuid,
  p_admin_id uuid,
  p_custom_points integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_check_in record;
  v_deadline_time time;
  v_actual_time time;
  v_minutes_late integer := 0;
  v_points_awarded integer := 0;
  v_points_penalty integer := 0;
  v_reason text;
  v_check_in_date date;
  v_category text;
BEGIN
  -- Get check-in data
  SELECT * INTO v_check_in
  FROM check_ins
  WHERE id = p_check_in_id;

  IF v_check_in IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Check-in not found');
  END IF;

  -- Get the date
  v_check_in_date := v_check_in.check_in_date;
  IF v_check_in_date IS NULL THEN
    v_check_in_date := DATE(v_check_in.check_in_time AT TIME ZONE 'Asia/Phnom_Penh');
  END IF;

  -- Determine deadline based on shift type
  IF v_check_in.shift_type = 'morning' THEN
    v_deadline_time := '09:00:59'::time;
  ELSIF v_check_in.shift_type = 'late' THEN
    v_deadline_time := '15:00:59'::time;
  ELSE
    v_deadline_time := '09:00:59'::time;
  END IF;

  -- Get actual check-in time
  v_actual_time := (v_check_in.check_in_time AT TIME ZONE 'Asia/Phnom_Penh')::time;

  -- Use custom points if provided by admin
  IF p_custom_points IS NOT NULL THEN
    v_points_awarded := p_custom_points;
    v_reason := 'Check-in approved with custom points: ' || p_custom_points || ' points';
    v_category := CASE WHEN p_custom_points >= 0 THEN 'bonus' ELSE 'deduction' END;
  ELSE
    -- Calculate if late and by how many minutes
    IF v_actual_time > v_deadline_time THEN
      v_minutes_late := EXTRACT(EPOCH FROM (v_actual_time - v_deadline_time)) / 60;
      v_points_penalty := -(v_minutes_late / 5)::integer;
      v_points_awarded := v_points_penalty;
      v_reason := 'Late check-in (' || v_minutes_late || ' min late): ' || v_points_penalty || ' points';
      v_category := 'deduction';
    ELSE
      v_points_awarded := 5;
      v_reason := 'Punctual check-in: +5 points';
      v_category := 'bonus';
    END IF;
  END IF;

  -- Update check-in record
  UPDATE check_ins
  SET 
    status = 'approved',
    approved_by = p_admin_id,
    approved_at = now(),
    points_awarded = v_points_awarded,
    minutes_late = v_minutes_late,
    is_late = (v_minutes_late > 0)
  WHERE id = p_check_in_id;

  -- Award/deduct points
  INSERT INTO points_history (
    user_id,
    points_change,
    reason,
    category,
    created_by
  ) VALUES (
    v_check_in.user_id,
    v_points_awarded,
    v_reason,
    v_category,
    p_admin_id
  );

  -- Update daily point goals
  PERFORM update_daily_point_goals_for_user(v_check_in.user_id, v_check_in_date);

  -- Send notification
  IF v_minutes_late > 0 AND p_custom_points IS NULL THEN
    INSERT INTO notifications (
      user_id,
      title,
      message,
      type
    ) VALUES (
      v_check_in.user_id,
      'Check-in Approved',
      'You were ' || v_minutes_late || ' minutes late. Penalty: ' || v_points_penalty || ' points.',
      'warning'
    );
  ELSE
    INSERT INTO notifications (
      user_id,
      title,
      message,
      type
    ) VALUES (
      v_check_in.user_id,
      'Check-in Approved',
      v_points_awarded || ' points awarded!',
      'success'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Check-in approved successfully',
    'points_awarded', v_points_awarded,
    'minutes_late', v_minutes_late
  );
END;
$$;
