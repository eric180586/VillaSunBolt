/*
  # Create Checklist Count Function

  ## Overview
  Creates RPC function to count today's checklists (total and completed) for the admin dashboard.

  ## Function
  - get_team_daily_checklist_counts() - Returns today's checklist statistics
*/

CREATE OR REPLACE FUNCTION get_team_daily_checklist_counts()
RETURNS TABLE (
  total_checklists INTEGER,
  completed_checklists INTEGER,
  pending_checklists INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_today_start TIMESTAMPTZ;
  v_today_end TIMESTAMPTZ;
BEGIN
  -- Get today's date range in Cambodia timezone
  v_today_start := date_trunc('day', now() AT TIME ZONE 'Asia/Phnom_Penh') AT TIME ZONE 'Asia/Phnom_Penh';
  v_today_end := v_today_start + INTERVAL '1 day';

  RETURN QUERY
  SELECT
    COUNT(*)::INTEGER AS total_checklists,
    COUNT(*) FILTER (WHERE status = 'completed')::INTEGER AS completed_checklists,
    COUNT(*) FILTER (WHERE status IN ('pending', 'pending_review'))::INTEGER AS pending_checklists
  FROM checklist_instances
  WHERE created_at >= v_today_start
    AND created_at < v_today_end;
END;
$$;

COMMENT ON FUNCTION get_team_daily_checklist_counts IS 'Returns today checklist statistics for admin dashboard (Cambodia timezone)';
