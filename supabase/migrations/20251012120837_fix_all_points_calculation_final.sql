/*
  # KOMPLETTE NEUSCHREIBUNG DER PUNKTEBERECHNUNG
  
  ## Klare Logik (FINALE VERSION):
  
  ### Punktevergabe pro Task:
  - Room Cleaning: 5 Punkte
  - Small Cleaning: 3 Punkte
  - Andere Tasks: Wert aus points_value Feld
  - Deadline Bonus: +1 Punkt (wenn innerhalb Deadline erledigt)
  - Reopen Penalty: -1 Punkt pro Reopen
  - Sekundärer Mitarbeiter: 50% von ALLEM (Basis + Bonus + Penalty zusammen, dann halbiert)
  
  ### Erreichbare Punkte (theoretically_achievable_points):
  - Basis-Punkte der Task (ohne Penalty)
  - + Deadline Bonus (+1) wenn Task eine Deadline hat
  - Bei geteilten Tasks: Jeder bekommt 50% der erreichbaren Punkte
  - Bei unassigned Tasks: Gleichmäßig auf alle checked-in Staff verteilt
  - Check-in: +5 Punkte (wenn approved)
  - WICHTIG: Completed Tasks MÜSSEN inkludiert sein!
  
  ### Erreichte Punkte (achieved_points):
  - Summe aus points_history für den Tag
  - Beinhaltet Check-in Punkte, Task-Punkte, manuelle Punkte, Penalties
  
  ### Team Points:
  - Erreichbar: Summe aller individuellen erreichbaren Punkte
  - Erreicht: Summe aller individuellen erreichten Punkte
*/

-- ==========================================
-- 1. EINZELNE USER: ERREICHBARE PUNKTE
-- ==========================================
CREATE OR REPLACE FUNCTION calculate_daily_achievable_points(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points numeric := 0;
  v_checkin_points integer := 0;
  v_task_points numeric := 0;
  v_has_checked_in boolean := false;
  v_checked_in_staff_count integer := 0;
BEGIN
  -- Prüfe ob User heute approved check-in hat
  SELECT EXISTS (
    SELECT 1 FROM check_ins
    WHERE user_id = p_user_id
    AND DATE(check_in_time) = p_date
    AND status = 'approved'
  ) INTO v_has_checked_in;

  -- Ohne Check-in keine Punkte erreichbar
  IF NOT v_has_checked_in THEN
    RETURN 0;
  END IF;

  -- Check-in Punkte
  v_checkin_points := 5;
  v_total_points := v_checkin_points;

  -- Anzahl Staff mit approved check-in (für unassigned tasks)
  SELECT COUNT(DISTINCT user_id)
  INTO v_checked_in_staff_count
  FROM check_ins
  WHERE DATE(check_in_time) = p_date
  AND status = 'approved'
  AND user_id IN (SELECT id FROM profiles WHERE role = 'staff');

  -- Zähle Punkte aus ALLEN Tasks (completed, in_progress, pending)
  -- WICHTIG: cancelled und archived ausschließen
  SELECT COALESCE(SUM(
    CASE
      -- Primary assigned to this user
      WHEN assigned_to = p_user_id THEN
        CASE
          -- Geteilte Task: 50% der Basis + 50% des Deadline Bonus
          WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
            ((COALESCE(initial_points_value, points_value)::numeric / 2.0) + 
             (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END))
          -- Solo Task: 100% Basis + Deadline Bonus
          ELSE
            (COALESCE(initial_points_value, points_value)::numeric + 
             (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
        END
      
      -- Secondary assigned to this user: 50% Basis + 50% Deadline Bonus
      WHEN secondary_assigned_to = p_user_id THEN
        ((COALESCE(initial_points_value, points_value)::numeric / 2.0) + 
         (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END))
      
      -- Unassigned task: Verteilt auf alle checked-in staff
      WHEN assigned_to IS NULL AND v_checked_in_staff_count > 0 THEN
        ((COALESCE(initial_points_value, points_value)::numeric + 
          (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)) / v_checked_in_staff_count)
      
      ELSE 0
    END
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status NOT IN ('cancelled', 'archived');

  v_total_points := v_total_points + v_task_points;

  RETURN ROUND(v_total_points)::integer;
END;
$$;

-- ==========================================
-- 2. EINZELNE USER: ERREICHTE PUNKTE
-- ==========================================
CREATE OR REPLACE FUNCTION calculate_daily_achieved_points(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_achieved_points integer := 0;
BEGIN
  -- Einfach: Summe aller points_change aus points_history für diesen Tag
  SELECT COALESCE(SUM(points_change), 0)
  INTO v_achieved_points
  FROM points_history
  WHERE user_id = p_user_id
  AND DATE(created_at) = p_date;

  RETURN v_achieved_points;
END;
$$;

-- ==========================================
-- 3. TEAM: ERREICHBARE PUNKTE
-- ==========================================
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
  -- Summiere die erreichbaren Punkte aller Staff-Mitglieder
  FOR v_user_id IN 
    SELECT id FROM profiles WHERE role = 'staff'
  LOOP
    v_total_points := v_total_points + calculate_daily_achievable_points(v_user_id, p_date);
  END LOOP;

  RETURN v_total_points;
END;
$$;

-- ==========================================
-- 4. TEAM: ERREICHTE PUNKTE
-- ==========================================
CREATE OR REPLACE FUNCTION calculate_team_daily_achieved_points(
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points integer := 0;
BEGIN
  -- Summiere die erreichten Punkte aller Staff-Mitglieder
  SELECT COALESCE(SUM(points_change), 0)
  INTO v_total_points
  FROM points_history ph
  JOIN profiles p ON ph.user_id = p.id
  WHERE DATE(ph.created_at) = p_date
  AND p.role = 'staff';

  RETURN v_total_points;
END;
$$;

-- ==========================================
-- 5. UPDATE DAILY POINT GOALS
-- ==========================================
CREATE OR REPLACE FUNCTION update_daily_point_goals(
  p_user_id uuid DEFAULT NULL,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_achievable integer;
  v_achieved integer;
  v_percentage numeric;
  v_color_status text;
BEGIN
  -- Wenn kein User angegeben, alle Staff-User updaten
  IF p_user_id IS NULL THEN
    FOR v_user_id IN 
      SELECT id FROM profiles WHERE role = 'staff'
    LOOP
      PERFORM update_daily_point_goals(v_user_id, p_date);
    END LOOP;
    RETURN;
  END IF;

  -- Berechne erreichbare und erreichte Punkte
  v_achievable := calculate_daily_achievable_points(p_user_id, p_date);
  v_achieved := calculate_daily_achieved_points(p_user_id, p_date);

  -- Berechne Prozentsatz
  IF v_achievable > 0 THEN
    v_percentage := (v_achieved::numeric / v_achievable::numeric) * 100;
  ELSE
    v_percentage := 0;
  END IF;

  -- Bestimme Farbe basierend auf Prozentsatz
  IF v_achievable = 0 THEN
    v_color_status := 'gray';
  ELSIF v_percentage >= 95 THEN
    v_color_status := 'dark_green';
  ELSIF v_percentage >= 90 THEN
    v_color_status := 'green';
  ELSIF v_percentage >= 83 THEN
    v_color_status := 'orange';
  ELSIF v_percentage >= 74 THEN
    v_color_status := 'yellow';
  ELSE
    v_color_status := 'red';
  END IF;

  -- Insert or Update
  INSERT INTO daily_point_goals (
    user_id,
    goal_date,
    theoretically_achievable_points,
    achieved_points,
    percentage,
    color_status
  ) VALUES (
    p_user_id,
    p_date,
    v_achievable,
    v_achieved,
    v_percentage,
    v_color_status
  )
  ON CONFLICT (user_id, goal_date)
  DO UPDATE SET
    theoretically_achievable_points = v_achievable,
    achieved_points = v_achieved,
    percentage = v_percentage,
    color_status = v_color_status,
    updated_at = now();
END;
$$;

-- ==========================================
-- 6. INITIALIZE DAILY GOALS FOR TODAY
-- ==========================================
CREATE OR REPLACE FUNCTION initialize_daily_goals_for_today()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM update_daily_point_goals(NULL, CURRENT_DATE);
END;
$$;

-- ==========================================
-- 7. MONATLICHER FORTSCHRITT
-- ==========================================
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
  v_percentage numeric;
  v_color_status text;
BEGIN
  -- Summiere alle Tagesziele des Monats
  SELECT 
    COALESCE(SUM(theoretically_achievable_points), 0),
    COALESCE(SUM(achieved_points), 0)
  INTO v_total_achievable, v_total_achieved
  FROM daily_point_goals
  WHERE user_id = p_user_id
  AND EXTRACT(YEAR FROM goal_date) = p_year
  AND EXTRACT(MONTH FROM goal_date) = p_month;

  -- Prozentsatz berechnen
  IF v_total_achievable > 0 THEN
    v_percentage := (v_total_achieved::numeric / v_total_achievable::numeric) * 100;
  ELSE
    v_percentage := 0;
  END IF;

  -- Farbe bestimmen
  IF v_total_achievable = 0 THEN
    v_color_status := 'gray';
  ELSIF v_percentage >= 95 THEN
    v_color_status := 'dark_green';
  ELSIF v_percentage >= 90 THEN
    v_color_status := 'green';
  ELSIF v_percentage >= 83 THEN
    v_color_status := 'orange';
  ELSIF v_percentage >= 74 THEN
    v_color_status := 'yellow';
  ELSE
    v_color_status := 'red';
  END IF;

  RETURN jsonb_build_object(
    'total_achievable', v_total_achievable,
    'total_achieved', v_total_achieved,
    'percentage', v_percentage,
    'color_status', v_color_status
  );
END;
$$;

-- Initialisiere Punkteziele für heute
SELECT initialize_daily_goals_for_today();
