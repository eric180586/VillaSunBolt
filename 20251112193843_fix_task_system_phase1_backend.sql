/*
  # Fix Task System - Phase 1: Backend Kritisch
  
  1. Fixes
    - get_team_daily_task_counts() verwendet jetzt due_date statt created_at
    - Templates werden auf neutrale Werte gesetzt
    
  2. Changes
    - Funktion get_team_daily_task_counts() komplett neu geschrieben
    - Templates: status, due_date, completed_at, assigned_to auf NULL/pending
*/

-- 1. Fix get_team_daily_task_counts() - Use due_date instead of created_at
CREATE OR REPLACE FUNCTION get_team_daily_task_counts()
RETURNS TABLE(total_tasks bigint, completed_tasks bigint)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*)::bigint as total_tasks,
    COUNT(*) FILTER (WHERE status = 'completed')::bigint as completed_tasks
  FROM tasks
  WHERE DATE(due_date AT TIME ZONE 'Asia/Phnom_Penh') = CURRENT_DATE
  AND is_template = false
  AND status != 'archived';
END;
$$;

-- 2. Cleanup Template Tasks - Set neutral values
UPDATE tasks
SET
  status = 'pending',
  due_date = NULL,
  completed_at = NULL,
  assigned_to = NULL,
  secondary_assigned_to = NULL
WHERE is_template = true;
