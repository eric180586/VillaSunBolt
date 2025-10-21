/*
  # Fix Achievable Points - Include Checklists

  ## Problem
  - `calculate_daily_achievable_points` only counts Tasks
  - Checklists are NOT included in theoretically_achievable_points
  - This makes percentage calculations incorrect when only checklists exist

  ## Solution
  - Add checklists to the calculation
  - For each checklist_instance on p_date:
    - Get points_value from checklists table
    - Count unique contributors (completed_by_id from items JSONB)
    - Divide points by contributor count
    - Add to total achievable points

  ## Example
  - Check-in: 5 points
  - Task 1: 10 points
  - Checklist (12 points, 3 contributors): 4 points per person
  - Total achievable for one contributor: 5 + 10 + 4 = 19 points
*/

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

  -- Check-in Punkte (WICHTIG: aktuell 0, früher 5)
  v_checkin_points := 0;
  v_total_points := v_checkin_points;

  -- Anzahl Staff mit approved check-in (für unassigned tasks)
  SELECT COUNT(DISTINCT user_id)
  INTO v_checked_in_staff_count
  FROM check_ins
  WHERE DATE(check_in_time) = p_date
  AND status = 'approved'
  AND user_id IN (SELECT id FROM profiles WHERE role = 'staff');

  -- ==========================================
  -- TASKS: Zähle Punkte aus ALLEN Tasks
  -- ==========================================
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

  -- ==========================================
  -- CHECKLISTS: Zähle Punkte aus Checklists
  -- ==========================================
  SELECT COALESCE(SUM(
    CASE
      -- Check if user is a contributor in this checklist_instance
      WHEN EXISTS (
        SELECT 1
        FROM jsonb_array_elements(ci.items) AS item
        WHERE (item->>'completed_by_id')::uuid = p_user_id
      ) THEN
        -- Calculate points per contributor
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
          ELSE 0
        END
      ELSE 0
    END
  ), 0)
  INTO v_checklist_points
  FROM checklist_instances ci
  JOIN checklists c ON ci.checklist_id = c.id
  WHERE DATE(ci.instance_date) = p_date
  AND ci.status NOT IN ('cancelled');

  v_total_points := v_total_points + v_checklist_points;

  RETURN ROUND(v_total_points)::integer;
END;
$$;
