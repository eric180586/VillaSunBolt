/*
  ============================================================================
  ⚠️  FINALE FREIGEGEBENE VERSION - DO NOT OVERRIDE ⚠️
  ============================================================================

  # KORREKTES PUNKTESYSTEM - FINALE APPROVED VERSION

  Datum: 17. Oktober 2025
  Version: 1.0 FINAL
  Status: APPROVED - NICHT ÜBERSCHREIBEN!

  ## REQUIREMENTS (User-Approved):

  ### INDIVIDUAL ERREICHBARE PUNKTE (theoretically_achievable_points):

  1. **Check-in**: 0 Punkte (kein Bonus mehr)
  2. **Assigned Solo Task**: 100% initial_points_value + 1 Deadline-Bonus
  3. **Shared Task**: 50% initial_points_value + 0.5 Deadline-Bonus
  4. **Unassigned Task**: 100% initial_points_value + 1 Deadline-Bonus
     - WICHTIG: JEDER bekommt die vollen Punkte!
     - Solange bis jemand die Task übernimmt (assigned_to wird gesetzt)
     - Ab diesem Zeitpunkt werden die Punkte bei allen anderen entfernt
  5. **Checklists**: Volle Punktzahl solange 0 Contributors
     - Sobald X Teilnehmer mitwirken: Punktzahl aufgeteilt (points_value ÷ X)
  6. **Patrol Rounds**: Nur bei zugewiesenen Rounds (assigned_to = user_id)

  ### TEAM ERREICHBARE PUNKTE:

  1. **Check-in**: 0 × Anzahl geplanter Staff
  2. **Assigned Tasks**: Jede Task NUR 1× gezählt (nicht doppelt bei shared!)
  3. **Unassigned Tasks**: Jede Task NUR 1× gezählt
  4. **Checklists**: Jede Checklist NUR 1× gezählt
  5. **Patrol Rounds**: Jede Round NUR 1× gezählt

  ### ERREICHTE PUNKTE (achieved_points):

  - Summe aus points_history für den Tag
  - Beinhaltet: Tasks, Checklists, Patrol Rounds, Glücksrad, Verstöße, Admin-Boni

  ## BEISPIEL:

  ### Setup:
  - 3 Staff geplant: Anna, Ben, Clara (alle eingecheckt)
  - Task "Room 101": Unassigned, 10 Punkte, mit Deadline
  - Task "Pool": Anna solo, 8 Punkte, mit Deadline
  - Task "Laundry": Ben + Clara shared, 6 Punkte, mit Deadline
  - Checklist "Morning": 12 Punkte, Anna (4 items), Ben (3 items), Clara (5 items)
  - Patrol Round 11:00: Ben assigned, 3 Punkte

  ### ERREICHBARE PUNKTE (vor Task-Übernahme):
  - Anna: 0 (check-in) + 9 (pool solo) + 11 (room unassigned) + 4 (checklist ÷ 3) + 0 (patrol) = 24
  - Ben: 0 + 3.5 (laundry shared) + 11 (room unassigned) + 4 (checklist ÷ 3) + 3 (patrol) = 21.5
  - Clara: 0 + 3.5 (laundry shared) + 11 (room unassigned) + 4 (checklist ÷ 3) + 0 (patrol) = 18.5
  - Team: 0 + 9 + 7 + 11 + 12 + 3 = 42 (jede Task/Checklist/Round nur 1×!)

  ### ERREICHBARE PUNKTE (nach Ben übernimmt Room 101):
  - Anna: 0 + 9 + 0 (room assigned!) + 4 + 0 = 13 ⬇️ -11 Punkte!
  - Ben: 0 + 3.5 + 11 (room assigned!) + 4 + 3 = 21.5 ✅ gleich
  - Clara: 0 + 3.5 + 0 (room assigned!) + 4 + 0 = 7.5 ⬇️ -11 Punkte!
  - Team: 0 + 9 + 7 + 11 + 12 + 3 = 42 ✅ gleich (immer noch 1×!)

  ============================================================================
*/

-- ============================================================================
-- 1. INDIVIDUAL ERREICHBARE PUNKTE
-- ============================================================================
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
  v_checklist_points numeric := 0;
  v_patrol_points numeric := 0;
  v_has_checked_in boolean := false;
  v_checked_in_staff_count integer := 0;
BEGIN
  -- ==========================================
  -- Prüfe ob User heute approved check-in hat
  -- ==========================================
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

  -- ==========================================
  -- Check-in Punkte: 0 (APPROVED: kein Bonus)
  -- ==========================================
  v_checkin_points := 0;
  v_total_points := v_checkin_points;

  -- ==========================================
  -- TASKS: Assigned + Shared + Unassigned
  -- ==========================================

  -- Anzahl Staff mit approved check-in (für unassigned tasks)
  SELECT COUNT(DISTINCT user_id)
  INTO v_checked_in_staff_count
  FROM check_ins
  WHERE DATE(check_in_time) = p_date
  AND status = 'approved'
  AND user_id IN (SELECT id FROM profiles WHERE role = 'staff');

  SELECT COALESCE(SUM(
    CASE
      -- ==========================================
      -- Primary assigned to this user
      -- ==========================================
      WHEN assigned_to = p_user_id THEN
        CASE
          -- Shared Task: 50% Basis + 50% Deadline Bonus
          WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
            ((COALESCE(initial_points_value, points_value)::numeric / 2.0) +
             (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END))
          -- Solo Task: 100% Basis + 100% Deadline Bonus
          ELSE
            (COALESCE(initial_points_value, points_value)::numeric +
             (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
        END

      -- ==========================================
      -- Secondary assigned to this user: 50% + 50% Deadline
      -- ==========================================
      WHEN secondary_assigned_to = p_user_id THEN
        ((COALESCE(initial_points_value, points_value)::numeric / 2.0) +
         (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END))

      -- ==========================================
      -- Unassigned task: VOLLE PUNKTE für JEDEN!
      -- (bis jemand sie übernimmt)
      -- ==========================================
      WHEN assigned_to IS NULL THEN
        (COALESCE(initial_points_value, points_value)::numeric +
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))

      ELSE 0
    END
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status NOT IN ('cancelled', 'archived');

  v_total_points := v_total_points + v_task_points;

  -- ==========================================
  -- CHECKLISTS: Volle Punkte oder aufgeteilt
  -- ==========================================
  SELECT COALESCE(SUM(
    CASE
      -- Prüfe ob User ein Contributor in dieser Checklist ist
      WHEN EXISTS (
        SELECT 1
        FROM jsonb_array_elements(ci.items) AS item
        WHERE (item->>'completed_by_id')::uuid = p_user_id
      ) THEN
        -- Berechne Punkte pro Contributor
        CASE
          -- Contributors vorhanden: Aufteilen
          WHEN (
            SELECT COUNT(DISTINCT (item->>'completed_by_id')::uuid)
            FROM jsonb_array_elements(ci.items) AS item
            WHERE item->>'completed_by_id' IS NOT NULL
              AND item->>'completed_by_id' != 'null'
          ) > 0 THEN
            c.points_value::numeric / (
              SELECT COUNT(DISTINCT (item->>'completed_by_id')::uuid)
              FROM jsonb_array_elements(ci.items) AS item
              WHERE item->>'completed_by_id' IS NOT NULL
                AND item->>'completed_by_id' != 'null'
            )
          -- Keine Contributors: Volle Punkte (sollte nicht vorkommen wenn User Contributor ist)
          ELSE c.points_value::numeric
        END

      -- User ist KEIN Contributor, aber könnte es noch werden
      WHEN NOT EXISTS (
        SELECT 1
        FROM jsonb_array_elements(ci.items) AS item
        WHERE item->>'completed_by_id' IS NOT NULL
          AND item->>'completed_by_id' != 'null'
      ) THEN
        -- Noch keine Contributors: Volle Punkte für alle
        c.points_value::numeric

      ELSE 0
    END
  ), 0)
  INTO v_checklist_points
  FROM checklist_instances ci
  JOIN checklists c ON ci.checklist_id = c.id
  WHERE DATE(ci.instance_date) = p_date
  AND ci.status NOT IN ('cancelled');

  v_total_points := v_total_points + v_checklist_points;

  -- ==========================================
  -- PATROL ROUNDS: Nur zugewiesene Rounds
  -- ==========================================
  SELECT COALESCE(SUM(3), 0)
  INTO v_patrol_points
  FROM patrol_rounds
  WHERE DATE(date) = p_date
  AND assigned_to = p_user_id;

  v_total_points := v_total_points + v_patrol_points;

  RETURN ROUND(v_total_points)::integer;
END;
$$;

-- ============================================================================
-- 2. TEAM ERREICHBARE PUNKTE
-- ============================================================================
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
  v_tasks_points numeric := 0;
  v_checklists_points numeric := 0;
  v_patrol_points numeric := 0;
BEGIN
  -- ==========================================
  -- Anzahl geplanter Staff für heute
  -- ==========================================
  SELECT COUNT(DISTINCT user_id)
  INTO v_scheduled_staff_count
  FROM check_ins
  WHERE DATE(check_in_time) = p_date
  AND status = 'approved'
  AND user_id IN (SELECT id FROM profiles WHERE role = 'staff');

  -- ==========================================
  -- Check-in: 0 × Anzahl Staff (APPROVED)
  -- ==========================================
  v_checkin_base := 0 * v_scheduled_staff_count;

  -- ==========================================
  -- TASKS: Jede Task NUR 1× (assigned + unassigned)
  -- ==========================================
  SELECT COALESCE(SUM(
    COALESCE(initial_points_value, points_value)::numeric +
    (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
  ), 0)
  INTO v_tasks_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status NOT IN ('cancelled', 'archived');

  -- ==========================================
  -- CHECKLISTS: Jede Checklist NUR 1×
  -- ==========================================
  SELECT COALESCE(SUM(c.points_value), 0)
  INTO v_checklists_points
  FROM checklist_instances ci
  JOIN checklists c ON ci.checklist_id = c.id
  WHERE DATE(ci.instance_date) = p_date
  AND ci.status NOT IN ('cancelled');

  -- ==========================================
  -- PATROL ROUNDS: Jede Round NUR 1×
  -- ==========================================
  SELECT COALESCE(SUM(3), 0)
  INTO v_patrol_points
  FROM patrol_rounds
  WHERE DATE(date) = p_date;

  v_total_points := v_checkin_base + v_tasks_points + v_checklists_points + v_patrol_points;

  RETURN ROUND(v_total_points)::integer;
END;
$$;

-- ============================================================================
-- 3. INDIVIDUAL ERREICHTE PUNKTE (aus points_history)
-- ============================================================================
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
  -- Summe ALLER Einträge aus points_history
  -- Beinhaltet: Tasks, Checklists, Patrol, Glücksrad, Verstöße, Admin-Boni
  SELECT COALESCE(SUM(points_change), 0)
  INTO v_total_points
  FROM points_history
  WHERE user_id = p_user_id
  AND DATE(created_at) = p_date;

  RETURN v_total_points;
END;
$$;

-- ============================================================================
-- 4. TEAM ERREICHTE PUNKTE (Summe aller Staff)
-- ============================================================================
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
  -- Summe ALLER Staff points_history
  SELECT COALESCE(SUM(ph.points_change), 0)
  INTO v_total_points
  FROM points_history ph
  JOIN profiles p ON ph.user_id = p.id
  WHERE DATE(ph.created_at) = p_date
  AND p.role = 'staff';

  RETURN v_total_points;
END;
$$;

-- ============================================================================
-- 5. UPDATE FUNKTION FÜR daily_point_goals
-- ============================================================================
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
    v_achievable := calculate_daily_achievable_points(v_user.id, CURRENT_DATE);
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

-- ============================================================================
-- 6. TRIGGER FÜR DYNAMISCHE ANPASSUNG
-- ============================================================================

-- Trigger-Funktion
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

-- Trigger auf check_ins (approved check-in ändert erreichbare Punkte)
DROP TRIGGER IF EXISTS update_daily_goals_on_checkin ON check_ins;
CREATE TRIGGER update_daily_goals_on_checkin
  AFTER INSERT OR UPDATE OR DELETE ON check_ins
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_update_daily_goals();

-- Trigger auf points_history (erreichte Punkte ändern sich)
DROP TRIGGER IF EXISTS update_daily_goals_on_points ON points_history;
CREATE TRIGGER update_daily_goals_on_points
  AFTER INSERT OR UPDATE OR DELETE ON points_history
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_update_daily_goals();

-- Trigger auf tasks (assigned_to Änderung = erreichbare Punkte ändern!)
DROP TRIGGER IF EXISTS update_daily_goals_on_tasks ON tasks;
CREATE TRIGGER update_daily_goals_on_tasks
  AFTER INSERT OR UPDATE OR DELETE ON tasks
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_update_daily_goals();

-- Trigger auf checklist_instances (Contributors ändern = erreichbare Punkte ändern!)
DROP TRIGGER IF EXISTS update_daily_goals_on_checklists ON checklist_instances;
CREATE TRIGGER update_daily_goals_on_checklists
  AFTER INSERT OR UPDATE OR DELETE ON checklist_instances
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_update_daily_goals();

-- Trigger auf patrol_rounds (zugewiesene Rounds ändern = erreichbare Punkte ändern!)
DROP TRIGGER IF EXISTS update_daily_goals_on_patrol ON patrol_rounds;
CREATE TRIGGER update_daily_goals_on_patrol
  AFTER INSERT OR UPDATE OR DELETE ON patrol_rounds
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_update_daily_goals();

-- ============================================================================
-- 7. INITIALISIERUNG FÜR HEUTE
-- ============================================================================
SELECT initialize_daily_goals_for_today();

-- ============================================================================
-- VALIDIERUNGS-QUERIES (zum Testen)
-- ============================================================================

/*
-- Test 1: Individual Erreichbare Punkte
SELECT
  p.full_name,
  calculate_daily_achievable_points(p.id, CURRENT_DATE) as achievable
FROM profiles p
WHERE p.role = 'staff';

-- Test 2: Team Erreichbare Punkte
SELECT calculate_team_daily_achievable_points(CURRENT_DATE) as team_achievable;

-- Test 3: Individual Erreichte Punkte
SELECT
  p.full_name,
  calculate_individual_daily_achieved_points(p.id, CURRENT_DATE) as achieved
FROM profiles p
WHERE p.role = 'staff';

-- Test 4: Team Erreichte Punkte
SELECT calculate_team_daily_achieved_points(CURRENT_DATE) as team_achieved;

-- Test 5: Complete Overview
SELECT
  p.full_name,
  dpg.theoretically_achievable_points,
  dpg.achieved_points,
  dpg.percentage,
  dpg.color_status,
  dpg.team_achievable_points,
  dpg.team_points_earned
FROM daily_point_goals dpg
JOIN profiles p ON dpg.user_id = p.id
WHERE dpg.goal_date = CURRENT_DATE
ORDER BY p.full_name;
*/

-- ============================================================================
-- ⚠️  END OF FINAL APPROVED VERSION - DO NOT OVERRIDE ⚠️
-- ============================================================================
