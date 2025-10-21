-- ============================================================================
-- FIX FEHLENDE FUNKTIONEN - Villa Sun App
-- ============================================================================
-- Kopiere diese komplette Datei in den Supabase SQL Editor und führe sie aus
-- URL: https://supabase.com/dashboard/project/vmfvvjzgzmmkigpxynii/sql/new
-- ============================================================================

-- 1. FEHLENDE SPALTEN IN CHECKLIST_INSTANCES
-- ============================================================================
DO $$
BEGIN
  -- instance_date Spalte
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklist_instances' AND column_name = 'instance_date'
  ) THEN
    ALTER TABLE checklist_instances ADD COLUMN instance_date date DEFAULT CURRENT_DATE;
  END IF;
END $$;

-- 2. FEHLENDE SPALTEN IN DAILY_POINT_GOALS
-- ============================================================================
DO $$
BEGIN
  -- team_achievable_points Spalte
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'daily_point_goals' AND column_name = 'team_achievable_points'
  ) THEN
    ALTER TABLE daily_point_goals ADD COLUMN team_achievable_points integer DEFAULT 0;
  END IF;

  -- team_points_earned Spalte
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'daily_point_goals' AND column_name = 'team_points_earned'
  ) THEN
    ALTER TABLE daily_point_goals ADD COLUMN team_points_earned integer DEFAULT 0;
  END IF;
END $$;

-- 3. FEHLENDE FUNKTION: get_team_daily_task_counts
-- ============================================================================
CREATE OR REPLACE FUNCTION get_team_daily_task_counts(p_date date DEFAULT CURRENT_DATE)
RETURNS TABLE (
  total_tasks bigint,
  completed_tasks bigint,
  pending_tasks bigint,
  in_progress_tasks bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*)::bigint as total_tasks,
    COUNT(*) FILTER (WHERE status = 'completed')::bigint as completed_tasks,
    COUNT(*) FILTER (WHERE status = 'pending')::bigint as pending_tasks,
    COUNT(*) FILTER (WHERE status = 'in_progress')::bigint as in_progress_tasks
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status != 'archived';
END;
$$;

-- 4. ÜBERPRÜFE OB process_check_in EXISTIERT (sollte schon da sein)
-- ============================================================================
-- Falls es fehlt, hier nochmal erstellen:
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
  v_existing_checkin uuid;
BEGIN
  -- Prüfe ob heute schon eingecheckt
  SELECT id INTO v_existing_checkin
  FROM check_ins
  WHERE user_id = p_user_id
  AND DATE(check_in_time AT TIME ZONE 'Asia/Phnom_Penh') = DATE(p_check_in_time AT TIME ZONE 'Asia/Phnom_Penh')
  LIMIT 1;

  IF v_existing_checkin IS NOT NULL THEN
    RAISE EXCEPTION 'Already checked in today';
  END IF;

  -- Finde Schedule für heute
  SELECT * INTO v_schedule
  FROM schedules
  WHERE staff_id = p_user_id
  AND DATE(start_time AT TIME ZONE 'Asia/Phnom_Penh') = DATE(p_check_in_time AT TIME ZONE 'Asia/Phnom_Penh')
  ORDER BY start_time
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No schedule found for today';
  END IF;

  -- Erkenne Schicht-Typ
  IF EXTRACT(HOUR FROM v_schedule.start_time) < 14 THEN
    v_shift_type := 'früh';
  ELSE
    v_shift_type := 'spät';
  END IF;

  -- Berechne Verspätung
  IF p_check_in_time > v_schedule.start_time THEN
    v_is_late := true;
    v_minutes_late := EXTRACT(EPOCH FROM (p_check_in_time - v_schedule.start_time)) / 60;
    v_points_awarded := GREATEST(5 - (v_minutes_late / 5)::integer, 0);
  END IF;

  -- Erstelle Check-in
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

  -- Auto-genehmige wenn pünktlich und gebe Punkte
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

-- ============================================================================
-- FERTIG! ✅
-- ============================================================================
-- Die folgenden Funktionen wurden erstellt/aktualisiert:
-- - get_team_daily_task_counts()
-- - process_check_in()
--
-- Die folgenden Spalten wurden hinzugefügt:
-- - checklist_instances.instance_date
-- - daily_point_goals.team_achievable_points
-- - daily_point_goals.team_points_earned
-- ============================================================================
