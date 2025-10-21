/*
  # Fix Deadline Bonus: Change from 1 to 2 Points
  
  ## Changes:
  1. **Tasks**: Deadline bonus 1 → 2 points (0.5 → 1 for shared)
  2. **Checklists**: Add deadline bonus 2 points to checklist calculation
  3. **Update calculate_individual_achievable_points()**: Fix task deadline bonus
  4. **Update calculate_team_achievable_points()**: Fix task deadline bonus
  
  ## Details:
  - Solo/Unassigned Task: base_points + 2 deadline bonus
  - Shared Task: (base_points / 2) + 1 deadline bonus
  - Checklist: base_points + 2 deadline bonus (then divided by contributors)
*/

-- ==========================================
-- 1. FIX: calculate_individual_achievable_points()
-- ==========================================
CREATE OR REPLACE FUNCTION calculate_individual_achievable_points(p_user_id uuid, p_date date)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task_points numeric := 0;
  v_checklist_points numeric := 0;
  v_patrol_points numeric := 0;
BEGIN
  -- ==========================================
  -- A) TASKS: Solo = base + 2, Shared = (base/2) + 1, Unassigned = base + 2
  -- ==========================================
  SELECT COALESCE(SUM(
    CASE
      -- ==========================================
      -- Primary assigned to this user
      -- ==========================================
      WHEN assigned_to = p_user_id THEN
        CASE
          -- Shared Task: 50% Basis + 1 Deadline Bonus (war 0.5)
          WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
            ((COALESCE(NULLIF(initial_points_value, 0), points_value)::numeric / 2.0) +
             (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
          -- Solo Task: 100% Basis + 2 Deadline Bonus (war 1)
          ELSE
            (COALESCE(NULLIF(initial_points_value, 0), points_value)::numeric +
             (CASE WHEN due_date IS NOT NULL THEN 2 ELSE 0 END))
        END

      -- ==========================================
      -- Secondary assigned to this user: 50% + 1 Deadline (war 0.5)
      -- ==========================================
      WHEN secondary_assigned_to = p_user_id THEN
        ((COALESCE(NULLIF(initial_points_value, 0), points_value)::numeric / 2.0) +
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))

      -- ==========================================
      -- Unassigned task: VOLLE PUNKTE + 2 Deadline für JEDEN! (war 1)
      -- ==========================================
      WHEN assigned_to IS NULL THEN
        (COALESCE(NULLIF(initial_points_value, 0), points_value)::numeric +
         (CASE WHEN due_date IS NOT NULL THEN 2 ELSE 0 END))

      ELSE 0
    END
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE status IN ('pending', 'in_progress', 'completed', 'waiting_approval')
  AND (assigned_to = p_user_id OR secondary_assigned_to = p_user_id OR assigned_to IS NULL);

  -- ==========================================
  -- B) CHECKLISTS: (base + 2 deadline) ÷ contributors
  -- ==========================================
  SELECT COALESCE(SUM(
    CASE
      -- Wenn niemand dran arbeitet: Volle Punkte + Deadline
      WHEN NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(ci.items) item 
        WHERE item->>'completed_by_id' IS NOT NULL 
        AND item->>'completed_by_id' != ''
      ) THEN
        c.points_value + (CASE WHEN c.due_date IS NOT NULL THEN 2 ELSE 0 END)
      
      -- Wenn andere arbeiten und noch offene Items: (Punkte + Deadline) ÷ (Contributors + 1)
      WHEN EXISTS (
        SELECT 1 FROM jsonb_array_elements(ci.items) item 
        WHERE (item->>'is_completed')::boolean = false OR item->>'is_completed' IS NULL
      ) THEN
        (c.points_value + (CASE WHEN c.due_date IS NOT NULL THEN 2 ELSE 0 END))::numeric / 
        (
          (SELECT COUNT(DISTINCT item->>'completed_by_id')
           FROM jsonb_array_elements(ci.items) item 
           WHERE item->>'completed_by_id' IS NOT NULL 
           AND item->>'completed_by_id' != '') + 1
        )
      
      ELSE 0
    END
  ), 0)
  INTO v_checklist_points
  FROM checklist_instances ci
  JOIN checklists c ON c.id = ci.checklist_id
  WHERE ci.instance_date = p_date
  AND ci.status IN ('pending', 'in_progress');

  -- ==========================================
  -- C) PATROL ROUNDS: Nur zugewiesene
  -- ==========================================
  SELECT COALESCE(SUM(pr.points_value), 0)
  INTO v_patrol_points
  FROM patrol_rounds pr
  WHERE pr.date = p_date
  AND pr.assigned_to = p_user_id
  AND pr.status IN ('pending', 'in_progress', 'completed', 'waiting_approval');

  RETURN (v_task_points + v_checklist_points + v_patrol_points)::integer;
END;
$$;

-- ==========================================
-- 2. FIX: calculate_team_achievable_points()
-- ==========================================
CREATE OR REPLACE FUNCTION calculate_team_achievable_points(p_date date)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task_points numeric := 0;
  v_checklist_points numeric := 0;
  v_patrol_points numeric := 0;
BEGIN
  -- ==========================================
  -- A) TASKS: Jede Task NUR 1× gezählt + 2 Deadline (war 1)
  -- ==========================================
  SELECT COALESCE(SUM(
    COALESCE(NULLIF(initial_points_value, 0), points_value) + 
    (CASE WHEN due_date IS NOT NULL THEN 2 ELSE 0 END)
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE status IN ('pending', 'in_progress', 'completed', 'waiting_approval');

  -- ==========================================
  -- B) CHECKLISTS: Jede Checklist NUR 1× gezählt + 2 Deadline
  -- ==========================================
  SELECT COALESCE(SUM(
    c.points_value + (CASE WHEN c.due_date IS NOT NULL THEN 2 ELSE 0 END)
  ), 0)
  INTO v_checklist_points
  FROM checklist_instances ci
  JOIN checklists c ON c.id = ci.checklist_id
  WHERE ci.instance_date = p_date
  AND ci.status IN ('pending', 'in_progress');

  -- ==========================================
  -- C) PATROL ROUNDS: Jede Round NUR 1×
  -- ==========================================
  SELECT COALESCE(SUM(pr.points_value), 0)
  INTO v_patrol_points
  FROM patrol_rounds pr
  WHERE pr.date = p_date
  AND pr.status IN ('pending', 'in_progress', 'completed', 'waiting_approval');

  RETURN (v_task_points + v_checklist_points + v_patrol_points)::integer;
END;
$$;

-- ==========================================
-- 3. Punkte für alle User neu berechnen (nur für heute)
-- ==========================================
DO $$
DECLARE
  v_user record;
BEGIN
  FOR v_user IN SELECT id FROM profiles WHERE role IN ('staff', 'admin')
  LOOP
    UPDATE daily_point_goals
    SET 
      theoretically_achievable_points = calculate_individual_achievable_points(v_user.id, CURRENT_DATE),
      updated_at = NOW()
    WHERE user_id = v_user.id
    AND goal_date = CURRENT_DATE;
  END LOOP;
END $$;
