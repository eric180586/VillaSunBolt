/*
  # Add Test Helper Function - Reset Check-in

  ## Purpose
  - Allows resetting a user's check-in to test the fortune wheel again
  - Admin-only function for testing purposes

  ## Function
  - `reset_user_checkin_today`: Deletes today's check-in and fortune wheel spins for a user
  - Useful for testing the check-in flow and fortune wheel multiple times
*/

CREATE OR REPLACE FUNCTION reset_user_checkin_today(
  p_user_id uuid,
  p_admin_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_today_date text;
  v_check_ins_deleted integer;
  v_spins_deleted integer;
BEGIN
  -- Verify admin role
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = p_admin_id
    AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can reset check-ins';
  END IF;

  v_today_date := DATE(now() AT TIME ZONE 'Asia/Phnom_Penh')::text;

  -- Delete fortune wheel spins for today's check-ins
  WITH todays_checkins AS (
    SELECT id FROM check_ins
    WHERE user_id = p_user_id
    AND DATE(check_in_time AT TIME ZONE 'Asia/Phnom_Penh')::text = v_today_date
  )
  DELETE FROM fortune_wheel_spins
  WHERE check_in_id IN (SELECT id FROM todays_checkins);

  GET DIAGNOSTICS v_spins_deleted = ROW_COUNT;

  -- Delete today's check-ins
  DELETE FROM check_ins
  WHERE user_id = p_user_id
  AND DATE(check_in_time AT TIME ZONE 'Asia/Phnom_Penh')::text = v_today_date;

  GET DIAGNOSTICS v_check_ins_deleted = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', true,
    'check_ins_deleted', v_check_ins_deleted,
    'spins_deleted', v_spins_deleted,
    'message', 'Check-in and fortune wheel spins reset successfully'
  );
END;
$$;

-- Grant permission to authenticated users (but function checks for admin role internally)
GRANT EXECUTE ON FUNCTION reset_user_checkin_today(uuid, uuid) TO authenticated;
