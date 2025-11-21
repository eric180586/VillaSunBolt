/*
  # Fix get_team_daily_task_counts to include daily recurring tasks
  
  The function now includes:
  - Tasks with due_date = today
  - Tasks with recurrence = 'daily' (regardless of due_date or is_template)
  - Excludes archived tasks
*/

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
  WHERE status != 'archived'
  AND (
    recurrence = 'daily'
    OR DATE(due_date AT TIME ZONE 'Asia/Phnom_Penh') = CURRENT_DATE
  );
END;
$$;
