/*
  # Korrektur: Punkteberechnung basierend auf CHECK-IN statt Schedule

  ## Problem
  - Mitarbeiter haben approved check-ins aber keinen Schedule
  - Punkte sollten basierend auf CHECK-IN vergeben werden, nicht Schedule

  ## Lösung
  - Check-In Punkte: Wenn approved check-in existiert → 5 Punkte
  - Task-Punkte: Alle nicht-zugewiesenen Tasks sind für ALLE mit approved check-in verfügbar

  ## Beispiel (4 Tasks: 10+5+5+5=25 Punkte, alle mit Deadline)
  - Sopheaktra: 5 (Check-In) + 25 (Tasks) + 4 (Deadlines) = 34 Punkte erreichbar
  - Nach Check-In approval: 5 erreicht von 34 erreichbar
*/

-- Funktion zur Berechnung der theoretisch erreichbaren Punkte - BASIEREND AUF CHECK-IN
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
  v_has_checked_in boolean := false;
BEGIN
  -- Prüfen ob Mitarbeiter heute einen APPROVED CHECK-IN hat
  SELECT EXISTS (
    SELECT 1 FROM check_ins
    WHERE user_id = p_user_id
    AND DATE(check_in_time) = p_date
    AND status = 'approved'
  ) INTO v_has_checked_in;

  -- Check-In Punkte wenn approved check-in vorhanden
  IF v_has_checked_in THEN
    v_checkin_points := 5;
  END IF;

  v_total_points := v_total_points + v_checkin_points;

  -- Punkte aus Tasks mit KORREKTER LOGIK:
  -- 1. Zugewiesene Tasks: Volle oder halbe Punkte (je nach secondary)
  -- 2. NICHT-zugewiesene Tasks: VOLLE Punkte für JEDEN mit approved check-in
  SELECT COALESCE(SUM(
    CASE
      -- Task ist diesem User zugewiesen (hauptsächlich)
      WHEN assigned_to = p_user_id THEN
        CASE
          WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
            -- Bei 2 Mitarbeitern: halbe Punkte + ggf. halber Deadline-Bonus
            (points_value / 2) + (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END)
          ELSE
            -- Vollständige Punkte + ggf. Deadline-Bonus (+1 Punkt)
            points_value + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
        END

      -- Task ist zweitem User zugewiesen
      WHEN secondary_assigned_to = p_user_id THEN
        (points_value / 2) + (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END)

      -- Task ist NICHT zugewiesen UND User hat approved check-in: VOLLE PUNKTE
      WHEN assigned_to IS NULL AND v_has_checked_in THEN
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

-- Team-Berechnung basierend auf CHECK-INS (nicht Schedules)
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
  v_checked_in_staff_count integer := 0;
BEGIN
  -- Anzahl Mitarbeiter mit APPROVED CHECK-IN für heute
  SELECT COUNT(DISTINCT user_id)
  INTO v_checked_in_staff_count
  FROM check_ins
  WHERE DATE(check_in_time) = p_date
  AND status = 'approved'
  AND user_id IN (SELECT id FROM profiles WHERE role = 'staff');

  -- Check-In Punkte: Anzahl eingecheckter Mitarbeiter × 5
  v_checkin_points := v_checked_in_staff_count * 5;
  v_total_points := v_total_points + v_checkin_points;

  -- Task-Punkte: Jede Aufgabe zählt NUR EINMAL
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

-- Update alle daily_point_goals für heute
SELECT update_daily_point_goals(NULL, CURRENT_DATE);
