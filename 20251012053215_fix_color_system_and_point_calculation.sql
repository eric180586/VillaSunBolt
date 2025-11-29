/*
  # Korrektur: 5-Stufen Ampelsystem und Punkteberechnung
  
  ## Änderungen
  1. Ampel-Farbsystem auf 5 Stufen anpassen:
     - >95%: dunkelgrün (dark_green)
     - 90-94%: grün (green)
     - 83-89%: ocker (orange)
     - 73-82%: gelb (yellow)
     - <73%: rot (red)
  
  2. Nicht-zugewiesene Aufgaben für alle Staff als theoretisch erreichbar markieren
  
  3. Color_status Typ erweitern um dark_green und orange
*/

-- Aktualisiere daily_point_goals color_status Werte
DO $$
BEGIN
  -- Ändere alle bestehenden 'green' zu dark_green wenn >95%
  UPDATE daily_point_goals
  SET color_status = 'dark_green'
  WHERE percentage > 95 AND color_status = 'green';
  
  -- Ändere alle zwischen 90-95% zu green
  UPDATE daily_point_goals
  SET color_status = 'green'
  WHERE percentage >= 90 AND percentage <= 95 AND color_status != 'green';
  
  -- Ändere alle zwischen 83-89% zu orange
  UPDATE daily_point_goals
  SET color_status = 'orange'
  WHERE percentage >= 83 AND percentage < 90;
  
  -- Ändere alle zwischen 73-82% zu yellow
  UPDATE daily_point_goals
  SET color_status = 'yellow'
  WHERE percentage >= 73 AND percentage < 83;
  
  -- Ändere alle <73% zu red
  UPDATE daily_point_goals
  SET color_status = 'red'
  WHERE percentage < 73;
END $$;

-- Funktion zum Berechnen der erreichbaren Punkte - KORRIGIERT
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
  v_task_points integer := 0;
  v_checkin_points integer := 5;
  v_has_schedule boolean := false;
BEGIN
  -- Prüfen ob Mitarbeiter heute einen Schedule hat
  SELECT EXISTS (
    SELECT 1 FROM schedules
    WHERE staff_id = p_user_id
    AND DATE(start_time) = p_date
  ) INTO v_has_schedule;

  -- Wenn kein Schedule, keine Punkte erreichbar
  IF NOT v_has_schedule THEN
    RETURN 0;
  END IF;

  -- Check-In Punkte (5 Punkte für Pünktlichkeit)
  v_total_points := v_total_points + v_checkin_points;

  -- Punkte aus ALLEN Tasks des Tages (auch nicht-zugewiesene)
  SELECT COALESCE(SUM(
    CASE 
      -- Task ist diesem User zugewiesen
      WHEN assigned_to = p_user_id THEN
        CASE 
          WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
            -- Bei 2 Mitarbeitern: halbe Punkte + ggf. halber Deadline-Bonus
            (points_value / 2) + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
          ELSE
            -- Vollständige Punkte + ggf. Deadline-Bonus
            points_value + (CASE WHEN due_date IS NOT NULL THEN 2 ELSE 0 END)
        END
      
      -- Task ist zweitem User zugewiesen
      WHEN secondary_assigned_to = p_user_id THEN
        (points_value / 2) + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
      
      -- Task ist NICHT zugewiesen - zählt für ALLE Staff mit Schedule
      WHEN assigned_to IS NULL THEN
        points_value + (CASE WHEN due_date IS NOT NULL THEN 2 ELSE 0 END)
      
      ELSE 0
    END
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status NOT IN ('completed', 'cancelled');

  v_total_points := v_total_points + v_task_points;

  RETURN v_total_points;
END;
$$;

-- Update der daily_point_goals mit neuem Farbsystem
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

    -- Bestimme Ampelfarbe (5-Stufen-System)
    IF v_percentage > 95 THEN
      v_color := 'dark_green';
    ELSIF v_percentage >= 90 THEN
      v_color := 'green';
    ELSIF v_percentage >= 83 THEN
      v_color := 'orange';
    ELSIF v_percentage >= 73 THEN
      v_color := 'yellow';
    ELSE
      v_color := 'red';
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

-- Aktualisiere Monatsfortschritts-Funktion mit neuem Farbsystem
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
  v_achieved_90_percent boolean := false;
  v_color_status text;
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

  -- Prüfe ob 90% erreicht
  v_achieved_90_percent := v_percentage >= 90;

  -- Bestimme Farbe
  IF v_percentage > 95 THEN
    v_color_status := 'dark_green';
  ELSIF v_percentage >= 90 THEN
    v_color_status := 'green';
  ELSIF v_percentage >= 83 THEN
    v_color_status := 'orange';
  ELSIF v_percentage >= 73 THEN
    v_color_status := 'yellow';
  ELSE
    v_color_status := 'red';
  END IF;

  RETURN jsonb_build_object(
    'user_id', p_user_id,
    'year', p_year,
    'month', p_month,
    'total_achievable', v_total_achievable,
    'total_achieved', v_total_achieved,
    'percentage', ROUND(v_percentage, 2),
    'achieved_90_percent', v_achieved_90_percent,
    'color_status', v_color_status
  );
END;
$$;

-- Aktualisiere Team-Monatsfortschritt mit neuem Farbsystem
CREATE OR REPLACE FUNCTION calculate_team_monthly_progress(
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
  v_achieved_90_percent boolean := false;
  v_color_status text;
BEGIN
  -- Summiere für alle Staff-Mitglieder
  SELECT 
    COALESCE(SUM(theoretically_achievable_points), 0),
    COALESCE(SUM(achieved_points), 0)
  INTO v_total_achievable, v_total_achieved
  FROM daily_point_goals
  WHERE EXTRACT(YEAR FROM goal_date) = p_year
  AND EXTRACT(MONTH FROM goal_date) = p_month
  AND user_id IN (SELECT id FROM profiles WHERE role = 'staff');

  -- Berechne Prozentsatz
  IF v_total_achievable > 0 THEN
    v_percentage := (v_total_achieved::numeric / v_total_achievable::numeric) * 100;
  END IF;

  -- Prüfe ob 90% erreicht
  v_achieved_90_percent := v_percentage >= 90;

  -- Bestimme Farbe
  IF v_percentage > 95 THEN
    v_color_status := 'dark_green';
  ELSIF v_percentage >= 90 THEN
    v_color_status := 'green';
  ELSIF v_percentage >= 83 THEN
    v_color_status := 'orange';
  ELSIF v_percentage >= 73 THEN
    v_color_status := 'yellow';
  ELSE
    v_color_status := 'red';
  END IF;

  RETURN jsonb_build_object(
    'year', p_year,
    'month', p_month,
    'total_achievable', v_total_achievable,
    'total_achieved', v_total_achieved,
    'percentage', ROUND(v_percentage, 2),
    'achieved_90_percent', v_achieved_90_percent,
    'team_event_unlocked', v_achieved_90_percent,
    'color_status', v_color_status
  );
END;
$$;
