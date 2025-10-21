/*
  # Fix Task Counting to Use Cambodia Timezone
  
  1. Problem
    - get_team_daily_task_counts() uses CURRENT_DATE (server UTC date)
    - But Cambodia is UTC+7, so at 6:56am Cambodia time it's already tomorrow
    - Dashboard shows 0/0 tasks because it's looking at wrong date
    
  2. Solution
    - Create helper function current_date_cambodia()
    - Drop and recreate get_team_daily_task_counts() to use Cambodia date
    - This ensures dashboard always shows tasks for TODAY in Cambodia time
*/

-- Create helper function to get current date in Cambodia timezone
CREATE OR REPLACE FUNCTION current_date_cambodia()
RETURNS date
LANGUAGE sql
STABLE
AS $$
  SELECT DATE(NOW() AT TIME ZONE 'Asia/Phnom_Penh');
$$;

-- Drop old function
DROP FUNCTION IF EXISTS get_team_daily_task_counts(date);

-- Recreate with Cambodia timezone support
CREATE OR REPLACE FUNCTION get_team_daily_task_counts(p_date date DEFAULT NULL)
RETURNS TABLE (
  date date,
  total_tasks integer,
  completed_tasks integer,
  pending_tasks integer
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_target_date date;
BEGIN
  -- Use provided date or TODAY IN CAMBODIA (not server UTC date)
  v_target_date := COALESCE(p_date, current_date_cambodia());
  
  -- Return live counts from tasks table
  RETURN QUERY
  SELECT 
    v_target_date as date,
    -- Total: all tasks for this date except cancelled
    COUNT(*)::integer as total_tasks,
    -- Completed: tasks that are completed OR archived
    COUNT(*) FILTER (WHERE status IN ('completed', 'archived'))::integer as completed_tasks,
    -- Pending: tasks not yet completed
    COUNT(*) FILTER (WHERE status NOT IN ('completed', 'archived', 'cancelled'))::integer as pending_tasks
  FROM tasks
  WHERE DATE(due_date AT TIME ZONE 'Asia/Phnom_Penh') = v_target_date
  AND status NOT IN ('cancelled');
  
  -- If no tasks exist, return 0/0/0
  IF NOT FOUND THEN
    RETURN QUERY SELECT v_target_date, 0::integer, 0::integer, 0::integer;
  END IF;
END;
$$;

COMMENT ON FUNCTION current_date_cambodia() IS 
'Returns the current date in Cambodia timezone (Asia/Phnom_Penh)';

COMMENT ON FUNCTION get_team_daily_task_counts(date) IS 
'Returns task counts for a specific date. Uses Cambodia timezone by default when no date provided.';

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION current_date_cambodia() TO authenticated;
GRANT EXECUTE ON FUNCTION get_team_daily_task_counts(date) TO authenticated;
