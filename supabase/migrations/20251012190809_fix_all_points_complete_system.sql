/*
  # Komplettes Punktesystem Fix - FINALE VERSION
  
  ## Änderungen:
  
  1. **daily_point_goals Tabelle erweitern**
     - Füge team_achievable_points hinzu
     - Füge team_points_earned hinzu
  
  2. **Alle Berechnungsfunktionen korrigieren**
     - Individual achievable/achieved
     - Team achievable/achieved (SQL-Fehler behoben)
  
  3. **Automatische Trigger**
     - Bei Check-ins
     - Bei Points History
     - Bei Tasks
*/

-- ==========================================
-- 1. TABELLE ERWEITERN
-- ==========================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'daily_point_goals' AND column_name = 'team_achievable_points'
  ) THEN
    ALTER TABLE daily_point_goals ADD COLUMN team_achievable_points integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'daily_point_goals' AND column_name = 'team_points_earned'
  ) THEN
    ALTER TABLE daily_point_goals ADD COLUMN team_points_earned integer DEFAULT 0;
  END IF;
END $$;

-- ==========================================
-- 2. INDIVIDUAL: ERREICHBARE PUNKTE
-- ==========================================
CREATE OR REPLACE FUNCTION calculate_individual_daily_achievable_points(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points numeric := 0;
  v_has_shift boolean := false;
  v_task_points numeric := 0;
BEGIN
  -- Prüfe ob User heute eingeplant ist (nicht 'off')
  SELECT EXISTS (
    SELECT 1 
    FROM weekly_schedules ws
    CROSS JOIN jsonb_array_elements(ws.shifts) AS shift
    WHERE ws.staff_id = p_user_id
    AND ws.is_published = true
    AND (shift->>'date')::date = p_date
    AND shift->>'shift' != 'off'
  ) INTO v_has_shift;

  -- Wenn kein Shift, keine Punkte erreichbar
  IF NOT v_has_shift THEN
    RETURN 0;
  END IF;

  -- Check-in Punkte: 5
  v_total_points := 5;

  -- Assigned Tasks (primary oder secondary)
  SELECT COALESCE(SUM(
    CASE
      -- Shared Task: Halbe Punkte + halber Deadline-Bonus
      WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to AND 
           (assigned_to = p_user_id OR secondary_assigned_to = p_user_id) THEN
        ((COALESCE(initial_points_value, points_value)::numeric / 2) + 
         (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END))
      -- Solo Task: Volle Punkte + voller Deadline-Bonus
      WHEN assigned_to = p_user_id THEN
        (COALESCE(initial_points_value, points_value)::numeric + 
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
      ELSE 0
    END
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND (assigned_to = p_user_id OR secondary_assigned_to = p_user_id)
  AND status NOT IN ('cancelled', 'archived');

  v_total_points := v_total_points + v_task_points;

  -- Unassigned Tasks: Volle Punkte für jeden
  SELECT COALESCE(SUM(
    (COALESCE(initial_points_value, points_value)::numeric + 
     (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND assigned_to IS NULL
  AND status NOT IN ('cancelled', 'archived');

  v_total_points := v_total_points + v_task_points;

  RETURN ROUND(v_total_points)::integer;
END;
$$;

-- ==========================================
-- 3. INDIVIDUAL: ERREICHTE PUNKTE
-- ==========================================
CREATE OR REPLACE FUNCTION calculate_individual_daily_achieved_points(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points integer := 0;
BEGIN
  SELECT COALESCE(SUM(points_change), 0)
  INTO v_total_points
  FROM points_history
  WHERE user_id = p_user_id
  AND DATE(created_at) = p_date;

  RETURN v_total_points;
END;
$$;

-- ==========================================
-- 4. TEAM: ERREICHBARE PUNKTE (SQL-FIX)
-- ==========================================
CREATE OR REPLACE FUNCTION calculate_team_daily_achievable_points(
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points numeric := 0;
  v_scheduled_staff_count integer := 0;
  v_checkin_base integer := 0;
  v_assigned_tasks_points numeric := 0;
  v_unassigned_tasks_points numeric := 0;
BEGIN
  -- Anzahl geplanter Staff für heute (shift != 'off')
  SELECT COUNT(DISTINCT ws.staff_id)
  INTO v_scheduled_staff_count
  FROM weekly_schedules ws
  CROSS JOIN jsonb_array_elements(ws.shifts) AS shift
  JOIN profiles p ON ws.staff_id = p.id
  WHERE ws.is_published = true
  AND (shift->>'date')::date = p_date
  AND shift->>'shift' != 'off'
  AND p.role = 'staff';

  -- Check-in: Jeder kann einchecken → Anzahl × 5
  v_checkin_base := 5 * v_scheduled_staff_count;

  -- Assigned Tasks: Jede Task nur 1×
  SELECT COALESCE(SUM(
    CASE
      WHEN assigned_to IS NOT NULL AND secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
        (COALESCE(initial_points_value, points_value)::numeric + 
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
      WHEN assigned_to IS NOT NULL THEN
        (COALESCE(initial_points_value, points_value)::numeric + 
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
      ELSE 0
    END
  ), 0)
  INTO v_assigned_tasks_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND assigned_to IS NOT NULL
  AND status NOT IN ('cancelled', 'archived');

  -- Unassigned Tasks: Jede Task nur 1×
  SELECT COALESCE(SUM(
    (COALESCE(initial_points_value, points_value)::numeric + 
     (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
  ), 0)
  INTO v_unassigned_tasks_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND assigned_to IS NULL
  AND status NOT IN ('cancelled', 'archived');

  v_total_points := v_checkin_base + v_assigned_tasks_points + v_unassigned_tasks_points;

  RETURN ROUND(v_total_points)::integer;
END;
$$;

-- ==========================================
-- 5. TEAM: ERREICHTE PUNKTE
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
  SELECT COALESCE(SUM(ph.points_change), 0)
  INTO v_total_points
  FROM points_history ph
  JOIN profiles p ON ph.user_id = p.id
  WHERE DATE(ph.created_at) = p_date
  AND p.role = 'staff';

  RETURN v_total_points;
END;
$$;

-- ==========================================
-- 6. UPDATE FUNKTION
-- ==========================================
CREATE OR REPLACE FUNCTION initialize_daily_goals_for_today()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user record;
  v_achievable integer;
  v_achieved integer;
  v_team_achievable integer;
  v_team_achieved integer;
  v_percentage numeric;
  v_color text;
BEGIN
  -- Berechne Team-Punkte einmal
  v_team_achievable := calculate_team_daily_achievable_points(CURRENT_DATE);
  v_team_achieved := calculate_team_daily_achieved_points(CURRENT_DATE);

  -- Für alle Staff-Mitglieder
  FOR v_user IN 
    SELECT id FROM profiles WHERE role = 'staff'
  LOOP
    -- Berechne individuelle Punkte
    v_achievable := calculate_individual_daily_achievable_points(v_user.id, CURRENT_DATE);
    v_achieved := calculate_individual_daily_achieved_points(v_user.id, CURRENT_DATE);
    
    -- Berechne Prozentsatz
    IF v_achievable > 0 THEN
      v_percentage := (v_achieved::numeric / v_achievable::numeric) * 100;
    ELSE
      v_percentage := 0;
    END IF;

    -- Bestimme Farbe
    IF v_achievable = 0 THEN
      v_color := 'gray';
    ELSIF v_percentage >= 95 THEN
      v_color := 'dark_green';
    ELSIF v_percentage >= 90 THEN
      v_color := 'light_green';
    ELSIF v_percentage >= 70 THEN
      v_color := 'yellow';
    ELSIF v_percentage >= 50 THEN
      v_color := 'orange';
    ELSE
      v_color := 'red';
    END IF;

    -- Insert oder Update
    INSERT INTO daily_point_goals (
      user_id,
      goal_date,
      theoretically_achievable_points,
      achieved_points,
      team_achievable_points,
      team_points_earned,
      percentage,
      color_status,
      updated_at
    )
    VALUES (
      v_user.id,
      CURRENT_DATE,
      v_achievable,
      v_achieved,
      v_team_achievable,
      v_team_achieved,
      v_percentage,
      v_color,
      now()
    )
    ON CONFLICT (user_id, goal_date)
    DO UPDATE SET
      theoretically_achievable_points = v_achievable,
      achieved_points = v_achieved,
      team_achievable_points = v_team_achievable,
      team_points_earned = v_team_achieved,
      percentage = v_percentage,
      color_status = v_color,
      updated_at = now();
  END LOOP;
END;
$$;

-- ==========================================
-- 7. TRIGGER ERSTELLEN
-- ==========================================
CREATE OR REPLACE FUNCTION trigger_update_daily_goals()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM initialize_daily_goals_for_today();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS update_daily_goals_on_checkin ON check_ins;
CREATE TRIGGER update_daily_goals_on_checkin
  AFTER INSERT OR UPDATE OR DELETE ON check_ins
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_update_daily_goals();

DROP TRIGGER IF EXISTS update_daily_goals_on_points ON points_history;
CREATE TRIGGER update_daily_goals_on_points
  AFTER INSERT OR UPDATE OR DELETE ON points_history
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_update_daily_goals();

DROP TRIGGER IF EXISTS update_daily_goals_on_tasks ON tasks;
CREATE TRIGGER update_daily_goals_on_tasks
  AFTER INSERT OR UPDATE OR DELETE ON tasks
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_update_daily_goals();

-- Initialisiere für heute
SELECT initialize_daily_goals_for_today();
