/*
  # Korrektur: Punkteberechnung basierend auf Dienstplan mit vollem Punktepotential

  ## Änderungen

  1. **Check-In Punkte basieren auf DIENSTPLAN (schedules), nicht auf check_ins**
     - Jeder Mitarbeiter mit Schedule für den Tag kann 5 Punkte erreichen

  2. **Nicht-zugewiesene Aufgaben: VOLLE Punkte für JEDEN Mitarbeiter**
     - Jeder Staff im Dienstplan kann alle nicht-zugewiesenen Aufgaben theoretisch übernehmen
     - Erst bei Zuweisung werden Punkte von anderen abgezogen

  3. **Deadline-Bonus: +1 Punkt**

  4. **Farbsystem:**
     - 0/0: Grau (keine Ampelfarbe)
     - < 73%: Rot
     - 74-82%: Gelb
     - 83-89%: Orange
     - 90-94%: Grün
     - 95%+: Dunkelgrün

  ## Beispiel

  **Vor Zuweisung (3 Aufgaben à 5 Punkte, alle mit Deadline):**
  - Sophaktra: 5 (Pünktlichkeit) + 15 (3×5 Aufgaben) + 3 (3×1 Deadline) = 23 Punkte

  **Nach Zuweisung (Mitarbeiter A übernimmt Aufgabe 1):**
  - Mitarbeiter A: 5 + 5 + 1 + 5 + 1 + 5 + 1 = 23 Punkte (behält alle)
  - Mitarbeiter B, C, D: 5 + 5 + 1 + 5 + 1 = 17 Punkte (Aufgabe 1 weg)

  **Team-Berechnung:**
  - Jede Aufgabe zählt NUR EINMAL: 20 (4×5 Pünktlichkeit) + 15 (3×5 Aufgaben) + 3 (3×1 Deadline) = 38 Punkte
*/

-- Funktion zur Berechnung der theoretisch erreichbaren Punkte - KORREKTE VERSION
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
BEGIN
  -- Prüfen ob Mitarbeiter heute einen DIENSTPLAN hat (nicht check-in!)
  SELECT EXISTS (
    SELECT 1 FROM schedules
    WHERE staff_id = p_user_id
    AND DATE(start_time) = p_date
  ) INTO v_has_schedule;

  -- Check-In Punkte basieren auf Dienstplan
  IF v_has_schedule THEN
    v_checkin_points := 5;
  END IF;

  v_total_points := v_total_points + v_checkin_points;

  -- Punkte aus Tasks mit KORREKTER LOGIK:
  -- 1. Zugewiesene Tasks: Volle oder halbe Punkte (je nach secondary)
  -- 2. NICHT-zugewiesene Tasks: VOLLE Punkte für JEDEN mit Schedule
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

      -- Task ist NICHT zugewiesen UND User hat Schedule: VOLLE PUNKTE
      WHEN assigned_to IS NULL AND v_has_schedule THEN
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

-- Funktion zur Berechnung der Team-Punkte (jede Aufgabe zählt nur EINMAL)
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
  v_scheduled_staff_count integer := 0;
BEGIN
  -- Anzahl Mitarbeiter im Dienstplan für heute
  SELECT COUNT(DISTINCT staff_id)
  INTO v_scheduled_staff_count
  FROM schedules
  WHERE DATE(start_time) = p_date
  AND staff_id IN (SELECT id FROM profiles WHERE role = 'staff');

  -- Check-In Punkte: Anzahl geplanter Mitarbeiter × 5
  v_checkin_points := v_scheduled_staff_count * 5;
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

-- Update Farbsystem mit neuen Schwellenwerten
CREATE OR REPLACE FUNCTION update_daily_point_goals(
  p_user_id uuid DEFAULT NULL,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user record;
  v_achievable integer;
  v_achieved integer;
  v_percentage numeric;
  v_color text;
BEGIN
  -- Wenn kein User angegeben, für alle Staff-Mitglieder updaten
  FOR v_user IN
    SELECT id FROM profiles
    WHERE (p_user_id IS NULL OR id = p_user_id)
    AND role = 'staff'
  LOOP
    -- Berechne erreichbare und erreichte Punkte
    v_achievable := calculate_daily_achievable_points(v_user.id, p_date);
    v_achieved := calculate_daily_achieved_points(v_user.id, p_date);

    -- Berechne Prozentsatz
    IF v_achievable > 0 THEN
      v_percentage := (v_achieved::numeric / v_achievable::numeric) * 100;
    ELSE
      v_percentage := 0;
    END IF;

    -- Bestimme Ampelfarbe mit NEUEN Schwellenwerten
    IF v_achievable = 0 THEN
      v_color := 'gray';  -- 0/0 = Grau
    ELSIF v_percentage >= 95 THEN
      v_color := 'dark_green';  -- 95%+ = Dunkelgrün
    ELSIF v_percentage >= 90 THEN
      v_color := 'green';  -- 90-94% = Grün
    ELSIF v_percentage >= 83 THEN
      v_color := 'orange';  -- 83-89% = Orange
    ELSIF v_percentage >= 74 THEN
      v_color := 'yellow';  -- 74-82% = Gelb
    ELSE
      v_color := 'red';  -- < 73% = Rot
    END IF;

    -- Insert oder Update
    INSERT INTO daily_point_goals (
      user_id,
      goal_date,
      theoretically_achievable_points,
      achieved_points,
      percentage,
      color_status,
      updated_at
    )
    VALUES (
      v_user.id,
      p_date,
      v_achievable,
      v_achieved,
      v_percentage,
      v_color,
      now()
    )
    ON CONFLICT (user_id, goal_date)
    DO UPDATE SET
      theoretically_achievable_points = v_achievable,
      achieved_points = v_achieved,
      percentage = v_percentage,
      color_status = v_color,
      updated_at = now();
  END LOOP;
END;
$$;

-- Funktion zur Initialisierung der täglichen Ziele für alle Staff
CREATE OR REPLACE FUNCTION initialize_daily_goals_for_today()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM update_daily_point_goals(NULL, CURRENT_DATE);
END;
$$;

-- Update Monatsprogress-Funktion mit neuen Farbschwellenwerten
CREATE OR REPLACE FUNCTION calculate_monthly_progress(
  p_user_id uuid,
  p_year integer DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::integer,
  p_month integer DEFAULT EXTRACT(MONTH FROM CURRENT_DATE)::integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_achievable integer := 0;
  v_total_achieved integer := 0;
  v_percentage numeric := 0;
  v_color text;
BEGIN
  -- Summiere alle Tage des Monats
  SELECT
    COALESCE(SUM(theoretically_achievable_points), 0),
    COALESCE(SUM(achieved_points), 0)
  INTO v_total_achievable, v_total_achieved
  FROM daily_point_goals
  WHERE user_id = p_user_id
  AND EXTRACT(YEAR FROM goal_date) = p_year
  AND EXTRACT(MONTH FROM goal_date) = p_month;

  -- Berechne Prozentsatz
  IF v_total_achievable > 0 THEN
    v_percentage := (v_total_achieved::numeric / v_total_achievable::numeric) * 100;
  END IF;

  -- Bestimme Farbe
  IF v_total_achievable = 0 THEN
    v_color := 'gray';
  ELSIF v_percentage >= 95 THEN
    v_color := 'dark_green';
  ELSIF v_percentage >= 90 THEN
    v_color := 'green';
  ELSIF v_percentage >= 83 THEN
    v_color := 'orange';
  ELSIF v_percentage >= 74 THEN
    v_color := 'yellow';
  ELSE
    v_color := 'red';
  END IF;

  RETURN jsonb_build_object(
    'user_id', p_user_id,
    'year', p_year,
    'month', p_month,
    'total_achievable', v_total_achievable,
    'total_achieved', v_total_achieved,
    'percentage', ROUND(v_percentage, 2),
    'achieved_90_percent', v_percentage >= 90,
    'color_status', v_color
  );
END;
$$;
