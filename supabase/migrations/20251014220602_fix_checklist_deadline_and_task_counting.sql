/*
  # Fix Checklist Deadline und Task Counting System
  
  ## Probleme die behoben werden:
  1. Daily Checklist "Again and Again" hat Deadline 00:00 statt 10:00 Uhr
  2. Task Counter in team_daily_totals ist inkorrekt (Trigger-basiert, keine Decrements)
  3. Heutige Daten in team_daily_totals sind falsch
  
  ## Lösungen:
  1. Update checklist due_date auf 10:00 Uhr Kambodscha-Zeit
  2. Reset heutige falsche Daten
  3. Erstelle neue Funktion für On-Demand Berechnung (immer korrekt)
  4. Behalte alte Trigger/Table für Kompatibilität (wird später im Frontend ersetzt)
  
  ## Details:
  - Daily Checklist "Again and Again" → Deadline 10:00 Uhr Cambodia
  - Neue Funktion `get_team_daily_task_counts()` für korrekte Zählung
  - Reset team_daily_totals für heute
*/

-- ==========================================
-- 1. FIX: Checklist Deadline auf 10:00 Uhr
-- ==========================================

-- Update "Again and Again" checklist to have 10:00 deadline
UPDATE checklists
SET due_date = (
  -- Get today in Cambodia, add 10:00 time, convert back to UTC for storage
  (current_date_cambodia() + TIME '10:00:00') AT TIME ZONE 'Asia/Phnom_Penh' AT TIME ZONE 'UTC'
)
WHERE title = 'Again and Again' 
AND recurrence = 'daily'
AND is_template = true;

-- ==========================================
-- 2. RESET: Heutige falsche Daten
-- ==========================================

-- Delete today's incorrect data from team_daily_totals
DELETE FROM team_daily_totals
WHERE date = current_date_cambodia();

-- ==========================================
-- 3. NEUE FUNKTION: On-Demand Task Counting
-- ==========================================

-- This function ALWAYS returns correct counts by querying tasks table directly
-- No triggers, no stale data, no phantom tasks!
CREATE OR REPLACE FUNCTION get_team_daily_task_counts(p_date date DEFAULT NULL)
RETURNS TABLE (
  date date,
  total_tasks integer,
  completed_tasks integer
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_target_date date;
BEGIN
  -- Use provided date or today in Cambodia
  v_target_date := COALESCE(p_date, current_date_cambodia());
  
  -- Return live counts from tasks table
  RETURN QUERY
  SELECT 
    v_target_date as date,
    -- Total: all tasks for this date except cancelled
    COUNT(*)::integer as total_tasks,
    -- Completed: tasks that are completed OR archived
    COUNT(*) FILTER (WHERE status IN ('completed', 'archived'))::integer as completed_tasks
  FROM tasks
  WHERE DATE(due_date) = v_target_date
  AND status NOT IN ('cancelled');
  
  -- If no tasks exist, return 0/0
  IF NOT FOUND THEN
    RETURN QUERY SELECT v_target_date, 0::integer, 0::integer;
  END IF;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION get_team_daily_task_counts(date) TO authenticated;

-- ==========================================
-- 4. TEST: Verify the function works
-- ==========================================

-- Test the new function for today
SELECT * FROM get_team_daily_task_counts(current_date_cambodia());

-- Verify checklist deadline is now 10:00
SELECT 
  title,
  due_date AT TIME ZONE 'Asia/Phnom_Penh' as due_cambodia,
  EXTRACT(HOUR FROM (due_date AT TIME ZONE 'Asia/Phnom_Penh')) as hour_cambodia
FROM checklists
WHERE title = 'Again and Again' 
AND is_template = true;
