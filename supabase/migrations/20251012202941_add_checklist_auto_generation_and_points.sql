/*
  # Checklisten Auto-Generierung und Punkte-Integration
  
  ## Features:
  1. Automatische Generierung von checklist_instances basierend auf recurrence
  2. Checklisten-Punkte in daily_point_goals integrieren
  3. Trigger für automatische Instance-Erstellung
  
  ## Ablauf:
  - Daily Checklists werden täglich um 00:00 Kambodscha-Zeit generiert
  - Punkte werden in achievable_points eingerechnet
  - Bei Completion werden Punkte in points_history eingetragen
*/

-- ==========================================
-- 1. FUNKTION: Generiere Checklist Instance
-- ==========================================
CREATE OR REPLACE FUNCTION generate_checklist_instance(
  p_checklist_id uuid,
  p_target_date date
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_checklist record;
  v_instance_id uuid;
  v_existing_id uuid;
BEGIN
  -- Hole Checklist Template
  SELECT * INTO v_checklist
  FROM checklists
  WHERE id = p_checklist_id AND is_template = true;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Checklist template not found';
  END IF;
  
  -- Prüfe ob bereits eine Instance für dieses Datum existiert
  SELECT id INTO v_existing_id
  FROM checklist_instances
  WHERE checklist_id = p_checklist_id
  AND instance_date = p_target_date;
  
  IF v_existing_id IS NOT NULL THEN
    RETURN v_existing_id;
  END IF;
  
  -- Erstelle neue Instance
  INSERT INTO checklist_instances (
    checklist_id,
    instance_date,
    items,
    status
  )
  VALUES (
    p_checklist_id,
    p_target_date,
    v_checklist.items,
    'pending'
  )
  RETURNING id INTO v_instance_id;
  
  -- Update last_generated_date
  UPDATE checklists
  SET last_generated_date = now()
  WHERE id = p_checklist_id;
  
  RETURN v_instance_id;
END;
$$;

-- ==========================================
-- 2. FUNKTION: Generiere alle fälligen Checklisten
-- ==========================================
CREATE OR REPLACE FUNCTION generate_due_checklists()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_checklist record;
  v_today date;
  v_count integer := 0;
  v_should_generate boolean;
BEGIN
  v_today := current_date_cambodia();
  
  FOR v_checklist IN 
    SELECT * FROM checklists 
    WHERE is_template = true
  LOOP
    v_should_generate := false;
    
    -- Prüfe ob generiert werden soll basierend auf recurrence
    CASE v_checklist.recurrence
      WHEN 'daily' THEN
        v_should_generate := true;
      WHEN 'one_time' THEN
        -- Nur wenn due_date heute ist und noch nicht generiert
        IF DATE(v_checklist.due_date) = v_today AND v_checklist.last_generated_date IS NULL THEN
          v_should_generate := true;
        END IF;
      WHEN 'weekly' THEN
        -- Generiere wenn due_date's Wochentag = heute's Wochentag
        IF EXTRACT(DOW FROM v_checklist.due_date) = EXTRACT(DOW FROM v_today) THEN
          v_should_generate := true;
        END IF;
      WHEN 'bi_weekly' THEN
        -- Generiere jede 2. Woche
        IF EXTRACT(DOW FROM v_checklist.due_date) = EXTRACT(DOW FROM v_today) AND
           MOD(EXTRACT(WEEK FROM v_today)::integer, 2) = 0 THEN
          v_should_generate := true;
        END IF;
      WHEN 'monthly' THEN
        -- Generiere am gleichen Tag des Monats
        IF EXTRACT(DAY FROM v_checklist.due_date) = EXTRACT(DAY FROM v_today) THEN
          v_should_generate := true;
        END IF;
    END CASE;
    
    -- Generiere Instance
    IF v_should_generate THEN
      PERFORM generate_checklist_instance(v_checklist.id, v_today);
      v_count := v_count + 1;
    END IF;
  END LOOP;
  
  RETURN v_count;
END;
$$;

-- ==========================================
-- 3. UPDATE: Berechne Checklist-Punkte mit
-- ==========================================
CREATE OR REPLACE FUNCTION calculate_team_daily_achievable_points(
  p_date date DEFAULT NULL
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
  v_checklist_points numeric := 0;
  v_target_date date;
BEGIN
  v_target_date := COALESCE(p_date, current_date_cambodia());

  -- Anzahl arbeitender Staff
  SELECT COUNT(DISTINCT ws.staff_id)
  INTO v_scheduled_staff_count
  FROM weekly_schedules ws
  CROSS JOIN jsonb_array_elements(ws.shifts) AS shift
  JOIN profiles p ON ws.staff_id = p.id
  WHERE ws.is_published = true
  AND (shift->>'date')::date = v_target_date
  AND shift->>'shift' != 'off'
  AND p.role = 'staff';

  v_checkin_base := 5 * v_scheduled_staff_count;

  -- Assigned Tasks
  SELECT COALESCE(SUM(
    CASE
      WHEN assigned_to IS NOT NULL AND secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
        (COALESCE(NULLIF(initial_points_value, 0), points_value)::numeric + 
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
      WHEN assigned_to IS NOT NULL THEN
        (COALESCE(NULLIF(initial_points_value, 0), points_value)::numeric + 
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
      ELSE 0
    END
  ), 0)
  INTO v_assigned_tasks_points
  FROM tasks
  WHERE DATE(due_date) = v_target_date
  AND assigned_to IS NOT NULL
  AND status NOT IN ('cancelled', 'archived');

  -- Unassigned Tasks
  SELECT COALESCE(SUM(
    (COALESCE(NULLIF(initial_points_value, 0), points_value)::numeric + 
     (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
  ), 0)
  INTO v_unassigned_tasks_points
  FROM tasks
  WHERE DATE(due_date) = v_target_date
  AND assigned_to IS NULL
  AND status NOT IN ('cancelled', 'archived');

  -- Checklisten-Punkte
  SELECT COALESCE(SUM(c.points_value), 0)
  INTO v_checklist_points
  FROM checklist_instances ci
  JOIN checklists c ON ci.checklist_id = c.id
  WHERE ci.instance_date = v_target_date
  AND ci.status != 'cancelled';

  v_total_points := v_checkin_base + v_assigned_tasks_points + v_unassigned_tasks_points + v_checklist_points;

  RETURN ROUND(v_total_points)::integer;
END;
$$;

-- ==========================================
-- 4. UPDATE: Individual mit Checklisten
-- ==========================================
CREATE OR REPLACE FUNCTION calculate_individual_daily_achievable_points(
  p_user_id uuid,
  p_date date DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points numeric := 0;
  v_has_shift boolean := false;
  v_task_points numeric := 0;
  v_checklist_points numeric := 0;
  v_target_date date;
BEGIN
  v_target_date := COALESCE(p_date, current_date_cambodia());

  SELECT EXISTS (
    SELECT 1 
    FROM weekly_schedules ws
    CROSS JOIN jsonb_array_elements(ws.shifts) AS shift
    WHERE ws.staff_id = p_user_id
    AND ws.is_published = true
    AND (shift->>'date')::date = v_target_date
    AND shift->>'shift' != 'off'
  ) INTO v_has_shift;

  IF NOT v_has_shift THEN
    RETURN 0;
  END IF;

  v_total_points := 5;

  -- Assigned Tasks
  SELECT COALESCE(SUM(
    CASE
      WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to AND 
           (assigned_to = p_user_id OR secondary_assigned_to = p_user_id) THEN
        ((COALESCE(NULLIF(initial_points_value, 0), points_value)::numeric / 2) + 
         (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END))
      WHEN assigned_to = p_user_id THEN
        (COALESCE(NULLIF(initial_points_value, 0), points_value)::numeric + 
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
      ELSE 0
    END
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date) = v_target_date
  AND (assigned_to = p_user_id OR secondary_assigned_to = p_user_id)
  AND status NOT IN ('cancelled', 'archived');

  v_total_points := v_total_points + v_task_points;

  -- Unassigned Tasks (jeder kann sie nehmen)
  SELECT COALESCE(SUM(
    (COALESCE(NULLIF(initial_points_value, 0), points_value)::numeric + 
     (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date) = v_target_date
  AND assigned_to IS NULL
  AND status NOT IN ('cancelled', 'archived');

  v_total_points := v_total_points + v_task_points;

  -- Checklisten (alle Checklisten können theoretisch von diesem User gemacht werden)
  SELECT COALESCE(SUM(c.points_value), 0)
  INTO v_checklist_points
  FROM checklist_instances ci
  JOIN checklists c ON ci.checklist_id = c.id
  WHERE ci.instance_date = v_target_date
  AND ci.status != 'cancelled';

  v_total_points := v_total_points + v_checklist_points;

  RETURN ROUND(v_total_points)::integer;
END;
$$;

-- ==========================================
-- 5. Generiere Checklisten für heute
-- ==========================================
SELECT generate_due_checklists();

-- ==========================================
-- 6. Update Daily Goals mit neuen Checklisten
-- ==========================================
SELECT initialize_daily_goals_for_today();
