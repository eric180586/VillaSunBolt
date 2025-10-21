/*
  # Punkteberechnung basierend auf SCHEDULE statt Check-In

  ## Problem
  - Aktuell: Nur eingecheckte Mitarbeiter zählen
  - Richtig: Alle GEPLANTEN Mitarbeiter (im Schedule) zählen für theoretisch erreichbare Punkte

  ## Logik
  - Individuell: Wenn im Schedule → kann Check-In Punkte + Tasks bekommen
  - Team: ALLE geplanten Staff-Mitarbeiter × (Check-In + Tasks)
  - Admins: Komplett aus Bewertung raus

  ## Beispiel (heute 12. Oktober)
  - 4 Staff geplant (Chita, ET, Sophavdy, Sopheaktra)
  - Check-In: 4 × 5 = 20 Punkte theoretisch erreichbar
  - Tasks: 3 × 5 = 15 Punkte
  - Deadlines: 3 × 1 = 3 Punkte
  - TEAM TOTAL: 38 Punkte theoretisch erreichbar
*/

-- Hilfsfunktion: Prüfe ob User heute im Schedule ist
CREATE OR REPLACE FUNCTION user_is_scheduled_today(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_scheduled boolean := false;
  v_week_start date;
  v_day_name text;
BEGIN
  -- Berechne Montag dieser Woche (ISO-Woche beginnt Montag)
  v_week_start := date_trunc('week', p_date)::date;
  
  -- Wenn Sonntag (day=0), dann gehört es zur vorherigen Woche in ISO
  IF EXTRACT(DOW FROM p_date) = 0 THEN
    v_week_start := v_week_start - interval '7 days';
  END IF;

  -- Tag-Name (lowercase)
  v_day_name := LOWER(TO_CHAR(p_date, 'Day'));
  v_day_name := TRIM(v_day_name);

  -- Prüfe ob User in weekly_schedules für diese Woche einen Nicht-Off Shift hat
  SELECT EXISTS (
    SELECT 1
    FROM weekly_schedules ws,
         jsonb_array_elements(ws.shifts) as shift
    WHERE ws.staff_id = p_user_id
    AND ws.week_start_date = v_week_start
    AND shift->>'day' = v_day_name
    AND shift->>'shift' != 'off'
  ) INTO v_is_scheduled;

  RETURN v_is_scheduled;
END;
$$;

-- Individuelle Punkte: Basierend auf SCHEDULE
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
  v_is_scheduled boolean := false;
  v_user_role text;
BEGIN
  -- Hole User Role
  SELECT role INTO v_user_role FROM profiles WHERE id = p_user_id;

  -- Admins sind komplett raus aus der Bewertung
  IF v_user_role = 'admin' THEN
    RETURN 0;
  END IF;

  -- Prüfe ob User heute geplant ist
  v_is_scheduled := user_is_scheduled_today(p_user_id, p_date);

  -- Wenn im Schedule → Check-In Punkte möglich
  IF v_is_scheduled THEN
    v_checkin_points := 5;
  END IF;

  v_total_points := v_total_points + v_checkin_points;

  -- Task-Punkte wenn im Schedule
  IF v_is_scheduled THEN
    SELECT COALESCE(SUM(
      CASE
        WHEN assigned_to = p_user_id THEN
          CASE
            WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
              (points_value / 2) + (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END)
            ELSE
              points_value + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
          END
        WHEN secondary_assigned_to = p_user_id THEN
          (points_value / 2) + (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END)
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
  END IF;

  RETURN v_total_points;
END;
$$;

-- Team-Punkte: Summe aller geplanten Staff (ohne Admins)
CREATE OR REPLACE FUNCTION calculate_team_daily_achievable_points(
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points integer := 0;
  v_user_id uuid;
BEGIN
  -- Für jeden STAFF-Mitarbeiter (keine Admins): Summiere ihre Punkte
  FOR v_user_id IN 
    SELECT id FROM profiles WHERE role = 'staff'
  LOOP
    v_total_points := v_total_points + calculate_daily_achievable_points(v_user_id, p_date);
  END LOOP;

  RETURN v_total_points;
END;
$$;

-- Update alle daily_point_goals
SELECT update_daily_point_goals(NULL, CURRENT_DATE);
