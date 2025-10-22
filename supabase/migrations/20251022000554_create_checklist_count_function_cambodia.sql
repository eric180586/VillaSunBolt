/*
  # Create Checklist Counting Function with Cambodia Timezone
  
  1. Purpose
    - Provide consistent checklist counting using Cambodia timezone
    - Match the pattern used for task counting
    - Ensure dashboards always show correct data for Cambodia's "today"
    
  2. Function
    - get_team_daily_checklist_counts(p_date) - Returns checklist stats for a date
    - Defaults to current_date_cambodia() when no date provided
    - Returns total, completed, and pending checklist counts
*/

-- Create function to get checklist counts for a specific date
CREATE OR REPLACE FUNCTION get_team_daily_checklist_counts(p_date date DEFAULT NULL)
RETURNS TABLE (
  date date,
  total_checklists integer,
  completed_checklists integer,
  pending_checklists integer
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_target_date date;
BEGIN
  -- Use provided date or TODAY IN CAMBODIA
  v_target_date := COALESCE(p_date, current_date_cambodia());
  
  -- Return live counts from checklist_instances table
  RETURN QUERY
  SELECT 
    v_target_date as date,
    -- Total: all checklists for this date
    COUNT(*)::integer as total_checklists,
    -- Completed: checklists marked as completed
    COUNT(*) FILTER (WHERE status = 'completed')::integer as completed_checklists,
    -- Pending: checklists not yet completed
    COUNT(*) FILTER (WHERE status IN ('pending', 'in_progress'))::integer as pending_checklists
  FROM checklist_instances
  WHERE instance_date = v_target_date;
  
  -- If no checklists exist, return 0/0/0
  IF NOT FOUND THEN
    RETURN QUERY SELECT v_target_date, 0::integer, 0::integer, 0::integer;
  END IF;
END;
$$;

COMMENT ON FUNCTION get_team_daily_checklist_counts(date) IS 
'Returns checklist counts for a specific date. Uses Cambodia timezone by default when no date provided.';

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_team_daily_checklist_counts(date) TO authenticated;
