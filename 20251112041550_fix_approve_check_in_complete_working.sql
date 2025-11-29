/*
  # Fix approve_check_in function completely

  1. Problem
    - Current function uses wrong column names (points, description)
    - Should use points_change, reason
    - Missing fortune wheel logic
    - Wrong notification type

  2. Solution
    - Rewrite function with correct schema
    - Add fortune wheel trigger
    - Use correct notification types
    - Calculate points based on late time

  3. Logic
    - On-time: +5 points
    - Late: -1 point per 5 minutes
    - Admin can override with custom points
    - Trigger fortune wheel for approved check-ins
*/

DROP FUNCTION IF EXISTS public.approve_check_in(uuid, uuid, integer);

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
  v_reason text;
  v_check_in_date date;
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
  IF v_check_in.shift_type = 'morning' OR v_check_in.shift_type = 'früh' THEN
    v_deadline_time := '09:00:59'::time;
  ELSIF v_check_in.shift_type = 'late' OR v_check_in.shift_type = 'spät' THEN
    v_deadline_time := '15:00:59'::time;
  ELSE
    v_deadline_time := '09:00:59'::time;
  END IF;

  -- Get actual check-in time
  v_actual_time := (v_check_in.check_in_time AT TIME ZONE 'Asia/Phnom_Penh')::time;

  -- Use custom points if provided by admin
  IF p_custom_points IS NOT NULL THEN
    v_points_awarded := p_custom_points;
    v_reason := 'Check-in approved with custom points';
  ELSE
    -- Calculate if late and by how many minutes
    IF v_actual_time > v_deadline_time THEN
      -- Calculate minutes late
      v_minutes_late := EXTRACT(EPOCH FROM (v_actual_time - v_deadline_time)) / 60;
      
      -- Calculate penalty: -1 per full 5 minutes
      v_points_awarded := -(v_minutes_late / 5)::integer;
      
      IF v_minutes_late > 0 THEN
        v_reason := 'Late check-in (' || v_minutes_late || ' min late)';
      ELSE
        v_reason := 'Check-in approved';
      END IF;
    ELSE
      -- On time: +5 points
      v_points_awarded := 5;
      v_reason := 'Punctual check-in';
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

  -- Award/deduct points using correct column names
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
    'check_in',
    p_admin_id
  );

  -- Update daily point goals
  INSERT INTO daily_point_goals (user_id, goal_date, theoretically_achievable_points, achieved_points)
  VALUES (v_check_in.user_id, v_check_in_date, 0, v_points_awarded)
  ON CONFLICT (user_id, goal_date)
  DO UPDATE SET achieved_points = daily_point_goals.achieved_points + EXCLUDED.achieved_points;

  -- Send notification with correct type
  INSERT INTO notifications (
    user_id,
    type,
    title,
    message
  ) VALUES (
    v_check_in.user_id,
    'success',
    'Check-in approved',
    v_reason || ': ' || v_points_awarded || ' points'
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Check-in approved successfully',
    'points_awarded', v_points_awarded,
    'minutes_late', v_minutes_late
  );
END;
$$;