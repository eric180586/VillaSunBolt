/*
  ============================================================================
  FINALE FREIGEGEBENE VERSION - PUNKTESYSTEM
  ============================================================================

  # KORREKTES PUNKTESYSTEM - FINALE APPROVED VERSION

  Datum: 17. Oktober 2025
  Version: 1.0 FINAL
  Status: APPROVED

  ## REQUIREMENTS:

  ### INDIVIDUAL ERREICHBARE PUNKTE:
  1. Check-in: 0 Punkte
  2. Assigned Solo Task: 100% initial_points_value + 1 Deadline-Bonus
  3. Shared Task: 50% initial_points_value + 0.5 Deadline-Bonus
  4. Unassigned Task: 100% initial_points_value + 1 Deadline-Bonus (für JEDEN)
  5. Checklists: Volle Punktzahl oder aufgeteilt nach Contributors
  6. Patrol Rounds: Nur bei zugewiesenen Rounds

  ### TEAM ERREICHBARE PUNKTE:
  1. Check-in: 0 × Anzahl geplanter Staff
  2. Tasks: Jede Task NUR 1× gezählt
  3. Checklists: Jede Checklist NUR 1× gezählt
  4. Patrol Rounds: Jede Round NUR 1× gezählt

  ============================================================================
*/

-- Füge team_achievable_points und team_points_earned hinzu falls noch nicht vorhanden
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

-- Füge points_value zu checklists hinzu
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklists' AND column_name = 'points_value'
  ) THEN
    ALTER TABLE checklists ADD COLUMN points_value integer DEFAULT 10;
  END IF;
END $$;

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
BEGIN
  -- Prüfe ob User heute approved check-in hat
  SELECT EXISTS (
    SELECT 1 FROM check_ins
    WHERE user_id = p_user_id
    AND DATE(check_in_time AT TIME ZONE 'Asia/Phnom_Penh') = p_date
    AND status = 'approved'
  ) INTO v_has_checked_in;

  IF NOT v_has_checked_in THEN
    RETURN 0;
  END IF;

  -- Check-in Punkte: 0
  v_checkin_points := 0;
  v_total_points := v_checkin_points;

  -- TASKS
  SELECT COALESCE(SUM(
    CASE
      WHEN assigned_to = p_user_id THEN
        CASE
          WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
            ((COALESCE(initial_points_value, points_value)::numeric / 2.0) +
             (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END))
          ELSE
            (COALESCE(initial_points_value, points_value)::numeric +
             (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
        END
      WHEN secondary_assigned_to = p_user_id THEN
        ((COALESCE(initial_points_value, points_value)::numeric / 2.0) +
         (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END))
      WHEN assigned_to IS NULL THEN
        (COALESCE(initial_points_value, points_value)::numeric +
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
      ELSE 0
    END
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date AT TIME ZONE 'Asia/Phnom_Penh') = p_date
  AND status NOT IN ('cancelled', 'archived');

  v_total_points := v_total_points + v_task_points;

  -- CHECKLISTS
  SELECT COALESCE(SUM(
    CASE
      WHEN EXISTS (
        SELECT 1
        FROM jsonb_array_elements(ci.items) AS item
        WHERE (item->>'completed_by_id')::uuid = p_user_id
      ) THEN
        CASE
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
          ELSE c.points_value::numeric
        END
      WHEN NOT EXISTS (
        SELECT 1
        FROM jsonb_array_elements(ci.items) AS item
        WHERE item->>'completed_by_id' IS NOT NULL
          AND item->>'completed_by_id' != 'null'
      ) THEN
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

  -- PATROL ROUNDS
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
  -- Anzahl geplanter Staff
  SELECT COUNT(DISTINCT user_id)
  INTO v_scheduled_staff_count
  FROM check_ins
  WHERE DATE(check_in_time AT TIME ZONE 'Asia/Phnom_Penh') = p_date
  AND status = 'approved'
  AND user_id IN (SELECT id FROM profiles WHERE role = 'staff');

  -- Check-in: 0 × Anzahl Staff
  v_checkin_base := 0 * v_scheduled_staff_count;

  -- TASKS: Jede Task NUR 1×
  SELECT COALESCE(SUM(
    COALESCE(initial_points_value, points_value)::numeric +
    (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
  ), 0)
  INTO v_tasks_points
  FROM tasks
  WHERE DATE(due_date AT TIME ZONE 'Asia/Phnom_Penh') = p_date
  AND status NOT IN ('cancelled', 'archived');

  -- CHECKLISTS: Jede Checklist NUR 1×
  SELECT COALESCE(SUM(c.points_value), 0)
  INTO v_checklists_points
  FROM checklist_instances ci
  JOIN checklists c ON ci.checklist_id = c.id
  WHERE DATE(ci.instance_date) = p_date
  AND ci.status NOT IN ('cancelled');

  -- PATROL ROUNDS: Jede Round NUR 1×
  SELECT COALESCE(SUM(3), 0)
  INTO v_patrol_points
  FROM patrol_rounds
  WHERE DATE(date) = p_date;

  v_total_points := v_checkin_base + v_tasks_points + v_checklists_points + v_patrol_points;

  RETURN ROUND(v_total_points)::integer;
END;
$$;

-- ============================================================================
-- 3. INDIVIDUAL ERREICHTE PUNKTE
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
  SELECT COALESCE(SUM(points_change), 0)
  INTO v_total_points
  FROM points_history
  WHERE user_id = p_user_id
  AND DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date;

  RETURN v_total_points;
END;
$$;

-- ============================================================================
-- 4. TEAM ERREICHTE PUNKTE
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
  SELECT COALESCE(SUM(ph.points_change), 0)
  INTO v_total_points
  FROM points_history ph
  JOIN profiles p ON ph.user_id = p.id
  WHERE DATE(ph.created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date
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
  v_team_achievable := calculate_team_daily_achievable_points(CURRENT_DATE);
  v_team_achieved := calculate_team_daily_achieved_points(CURRENT_DATE);

  FOR v_user IN
    SELECT id FROM profiles WHERE role = 'staff'
  LOOP
    v_achievable := calculate_daily_achievable_points(v_user.id, CURRENT_DATE);
    v_achieved := calculate_individual_daily_achieved_points(v_user.id, CURRENT_DATE);

    IF v_achievable > 0 THEN
      v_percentage := (v_achieved::numeric / v_achievable::numeric) * 100;
    ELSE
      v_percentage := 0;
    END IF;

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

DROP TRIGGER IF EXISTS update_daily_goals_on_checklists ON checklist_instances;
CREATE TRIGGER update_daily_goals_on_checklists
  AFTER INSERT OR UPDATE OR DELETE ON checklist_instances
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_update_daily_goals();

DROP TRIGGER IF EXISTS update_daily_goals_on_patrol ON patrol_rounds;
CREATE TRIGGER update_daily_goals_on_patrol
  AFTER INSERT OR UPDATE OR DELETE ON patrol_rounds
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_update_daily_goals();

-- Initialisierung für heute
SELECT initialize_daily_goals_for_today();