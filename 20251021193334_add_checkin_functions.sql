/*
  Fügt Check-in Funktionen hinzu
  
  - process_check_in()
  - approve_check_in()
  - reject_check_in()
  - Fehlende Spalten
*/

-- Fehlende Spalten zu check_ins hinzufügen
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'check_ins' AND column_name = 'photo_url'
  ) THEN
    ALTER TABLE check_ins ADD COLUMN photo_url text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'check_ins' AND column_name = 'late_reason'
  ) THEN
    ALTER TABLE check_ins ADD COLUMN late_reason text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'check_ins' AND column_name = 'status'
  ) THEN
    ALTER TABLE check_ins ADD COLUMN status text DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'check_ins' AND column_name = 'approved_by'
  ) THEN
    ALTER TABLE check_ins ADD COLUMN approved_by uuid REFERENCES auth.users(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'check_ins' AND column_name = 'approved_at'
  ) THEN
    ALTER TABLE check_ins ADD COLUMN approved_at timestamptz;
  END IF;
END $$;

-- Process Check-in Function
CREATE OR REPLACE FUNCTION process_check_in(
  p_user_id uuid,
  p_check_in_time timestamptz,
  p_photo_url text DEFAULT NULL,
  p_late_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_schedule record;
  v_is_late boolean := false;
  v_minutes_late integer := 0;
  v_points_awarded integer := 5;
  v_check_in_id uuid;
  v_shift_type text;
BEGIN
  -- Find schedule for today
  SELECT * INTO v_schedule
  FROM schedules
  WHERE staff_id = p_user_id
  AND DATE(start_time) = DATE(p_check_in_time)
  ORDER BY start_time
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No schedule found for today';
  END IF;

  -- Detect shift type
  IF EXTRACT(HOUR FROM v_schedule.start_time) < 14 THEN
    v_shift_type := 'früh';
  ELSE
    v_shift_type := 'spät';
  END IF;

  -- Calculate lateness
  IF p_check_in_time > v_schedule.start_time THEN
    v_is_late := true;
    v_minutes_late := EXTRACT(EPOCH FROM (p_check_in_time - v_schedule.start_time)) / 60;
    v_points_awarded := GREATEST(5 - (v_minutes_late / 5)::integer, 0);
  END IF;

  -- Create check-in
  INSERT INTO check_ins (
    user_id,
    check_in_time,
    photo_url,
    shift_type,
    is_late,
    minutes_late,
    points_awarded,
    late_reason,
    status
  )
  VALUES (
    p_user_id,
    p_check_in_time,
    p_photo_url,
    v_shift_type,
    v_is_late,
    v_minutes_late,
    v_points_awarded,
    p_late_reason,
    CASE WHEN v_is_late THEN 'pending' ELSE 'approved' END
  )
  RETURNING id INTO v_check_in_id;

  -- Auto-approve if not late and award points
  IF NOT v_is_late AND v_points_awarded > 0 THEN
    INSERT INTO points_history (user_id, points_change, reason, category)
    VALUES (
      p_user_id,
      v_points_awarded,
      'Pünktlicher Check-in',
      'task_completed'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'check_in_id', v_check_in_id,
    'is_late', v_is_late,
    'minutes_late', v_minutes_late,
    'points_awarded', v_points_awarded,
    'status', CASE WHEN v_is_late THEN 'pending' ELSE 'approved' END
  );
END;
$$;

-- Approve Check-in Function
CREATE OR REPLACE FUNCTION approve_check_in(
  p_check_in_id uuid,
  p_admin_id uuid,
  p_custom_points integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check_in record;
  v_final_points integer;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = p_admin_id AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can approve check-ins';
  END IF;

  SELECT * INTO v_check_in FROM check_ins WHERE id = p_check_in_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Check-in not found';
  END IF;

  v_final_points := COALESCE(p_custom_points, v_check_in.points_awarded);

  -- Update status
  UPDATE check_ins
  SET
    status = 'approved',
    approved_by = p_admin_id,
    approved_at = now(),
    points_awarded = v_final_points
  WHERE id = p_check_in_id;

  -- Award points
  IF v_final_points > 0 THEN
    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (
      v_check_in.user_id,
      v_final_points,
      'Check-in genehmigt',
      'task_completed',
      p_admin_id
    );
  END IF;

  -- Notification
  INSERT INTO notifications (user_id, title, message, type)
  VALUES (
    v_check_in.user_id,
    'Check-in genehmigt',
    'Dein Check-in wurde genehmigt. +' || v_final_points || ' Punkte',
    'success'
  );

  RETURN jsonb_build_object('success', true, 'points_awarded', v_final_points);
END;
$$;

-- Reject Check-in Function
CREATE OR REPLACE FUNCTION reject_check_in(
  p_check_in_id uuid,
  p_admin_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check_in record;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = p_admin_id AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can reject check-ins';
  END IF;

  SELECT * INTO v_check_in FROM check_ins WHERE id = p_check_in_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Check-in not found';
  END IF;

  UPDATE check_ins
  SET
    status = 'rejected',
    approved_by = p_admin_id,
    approved_at = now(),
    points_awarded = 0
  WHERE id = p_check_in_id;

  INSERT INTO notifications (user_id, title, message, type)
  VALUES (
    v_check_in.user_id,
    'Check-in abgelehnt',
    'Dein Check-in wurde abgelehnt: ' || p_reason,
    'warning'
  );

  RETURN jsonb_build_object('success', true);
END;
$$;