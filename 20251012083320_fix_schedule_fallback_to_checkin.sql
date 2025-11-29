/*
  # Fix: Schedule-basiert mit Check-In Fallback

  ## Problem
  Die schedules-Tabelle ist leer, aber das System benötigt Schedule-Daten.

  ## Lösung
  - Primär: Schedules verwenden (wenn vorhanden)
  - Fallback: Approved Check-Ins verwenden (wenn keine Schedules)
  - Dies ermöglicht dem System zu funktionieren bis Schedules erstellt werden

  ## Logik bleibt gleich
  - Nicht-zugewiesene Tasks: VOLLE Punkte für JEDEN im Schedule/Check-In
  - Zugewiesene Tasks: Nur für zugewiesene Person(en)
  - Bei Zuweisung: ALLE anderen werden neu berechnet und verlieren diese Punkte
*/

-- Funktion mit Schedule-Fallback auf Check-In
CREATE OR REPLACE FUNCTION calculate_daily_achievable_points(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points integer := 0;
  v_checkin_points integer := 0;
  v_task_points integer := 0;
  v_has_schedule boolean := false;
  v_has_approved_checkin boolean := false;
  v_is_eligible boolean := false;
BEGIN
  -- Prüfen ob Mitarbeiter heute einen SCHEDULE hat
  SELECT EXISTS (
    SELECT 1 FROM schedules
    WHERE staff_id = p_user_id
    AND DATE(start_time) = p_date
  ) INTO v_has_schedule;

  -- Fallback: Prüfen ob approved Check-In vorhanden (wenn keine Schedules)
  IF NOT v_has_schedule THEN
    SELECT EXISTS (
      SELECT 1 FROM check_ins
      WHERE user_id = p_user_id
      AND DATE(check_in_time) = p_date
      AND status = 'approved'
    ) INTO v_has_approved_checkin;
  END IF;

  -- Berechtigt wenn Schedule ODER approved Check-In
  v_is_eligible := v_has_schedule OR v_has_approved_checkin;

  -- Keine Punkte wenn nicht berechtigt
  IF NOT v_is_eligible THEN
    RETURN 0;
  END IF;

  -- Pünktlichkeits-Punkte (5 Punkte wenn berechtigt)
  v_checkin_points := 5;
  v_total_points := v_total_points + v_checkin_points;

  -- Task-Punkte berechnen
  SELECT COALESCE(SUM(
    CASE
      -- Task ist diesem User HAUPTSÄCHLICH zugewiesen
      WHEN assigned_to = p_user_id THEN
        CASE
          -- Mit 2. Mitarbeiter: 50% Split
          WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
            (points_value / 2.0) + (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END)
          -- Alleine: volle Punkte
          ELSE
            points_value + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
        END

      -- Task ist diesem User ALS ZWEITER zugewiesen
      WHEN secondary_assigned_to = p_user_id THEN
        (points_value / 2.0) + (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END)

      -- Task ist NICHT zugewiesen: volle Punkte für JEDEN der berechtigt ist
      WHEN assigned_to IS NULL THEN
        points_value + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)

      ELSE 0
    END
  ), 0)::integer
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status NOT IN ('completed', 'cancelled');

  v_total_points := v_total_points + v_task_points;

  RETURN v_total_points;
END;
$$;

-- Team-Berechnung mit Fallback
CREATE OR REPLACE FUNCTION calculate_team_daily_achievable_points(
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points integer := 0;
  v_checkin_points integer := 0;
  v_task_points integer := 0;
  v_eligible_staff_count integer := 0;
  v_scheduled_count integer := 0;
  v_checkedin_count integer := 0;
BEGIN
  -- Anzahl Mitarbeiter im Schedule für heute
  SELECT COUNT(DISTINCT staff_id)
  INTO v_scheduled_count
  FROM schedules
  WHERE DATE(start_time) = p_date
  AND staff_id IN (SELECT id FROM profiles WHERE role = 'staff');

  -- Fallback: Anzahl mit approved Check-In (wenn keine Schedules)
  IF v_scheduled_count = 0 THEN
    SELECT COUNT(DISTINCT user_id)
    INTO v_checkedin_count
    FROM check_ins
    WHERE DATE(check_in_time) = p_date
    AND status = 'approved'
    AND user_id IN (SELECT id FROM profiles WHERE role = 'staff');
  END IF;

  -- Berechtigte = Schedules ODER Check-Ins
  v_eligible_staff_count := GREATEST(v_scheduled_count, v_checkedin_count);

  -- Pünktlichkeits-Punkte: Anzahl berechtigter Mitarbeiter × 5
  v_checkin_points := v_eligible_staff_count * 5;
  v_total_points := v_total_points + v_checkin_points;

  -- Task-Punkte: Jede Aufgabe NUR EINMAL
  SELECT COALESCE(SUM(
    points_value + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status NOT IN ('completed', 'cancelled');

  v_total_points := v_total_points + v_task_points;

  RETURN v_total_points;
END;
$$;

-- Hilfsfunktion mit Fallback für Task-Änderungen
CREATE OR REPLACE FUNCTION recalculate_all_staff_points_for_date(p_date date)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_staff_id uuid;
  v_has_schedules boolean;
BEGIN
  -- Prüfen ob Schedules für dieses Datum existieren
  SELECT EXISTS (
    SELECT 1 FROM schedules
    WHERE DATE(start_time) = p_date
    LIMIT 1
  ) INTO v_has_schedules;

  IF v_has_schedules THEN
    -- Schedules vorhanden: Nur Staff mit Schedule neu berechnen
    FOR v_staff_id IN
      SELECT DISTINCT staff_id
      FROM schedules
      WHERE DATE(start_time) = p_date
      AND staff_id IN (SELECT id FROM profiles WHERE role = 'staff')
    LOOP
      PERFORM update_daily_point_goals(v_staff_id, p_date);
    END LOOP;
  ELSE
    -- Keine Schedules: Alle Staff mit approved Check-In neu berechnen
    FOR v_staff_id IN
      SELECT DISTINCT user_id
      FROM check_ins
      WHERE DATE(check_in_time) = p_date
      AND status = 'approved'
      AND user_id IN (SELECT id FROM profiles WHERE role = 'staff')
    LOOP
      PERFORM update_daily_point_goals(v_staff_id, p_date);
    END LOOP;
  END IF;
END;
$$;

-- Alle Punkte für heute neu berechnen
SELECT recalculate_all_staff_points_for_date(CURRENT_DATE);
