/*
  # Fix Task Archival - Automatic Cleanup System
  
  ## Summary
  This migration implements automatic archival of completed tasks and checklists
  from previous days to ensure clean task lists and proper "Today's Tasks" display.
  
  ## Problems Fixed
  1. Completed tasks from previous days remain visible in regular task overview
  2. No automatic archival mechanism exists
  3. "Today's Tasks" counter shows correct counts but regular overview is cluttered
  4. checklist_instances CHECK constraint doesn't allow 'archived' status
  
  ## Changes Made
  
  ### 1. Update CHECK Constraint for checklist_instances
  - Drop existing constraint that only allows: pending, in_progress, completed
  - Add new constraint that allows: pending, in_progress, completed, archived
  
  ### 2. Archive Old Completed Tasks Function
  - Creates function to archive tasks with status='completed' from previous days
  - Archives checklist instances with status='completed' from previous days
  - Can be called manually or via daily-reset edge function
  
  ### 3. Get Archived Tasks Statistics
  - Helper function to see how many tasks were archived
  - Useful for monitoring and debugging
  
  ## Expected Behavior
  - At midnight (daily-reset), all completed tasks from yesterday become archived
  - Regular task overview only shows: pending, in_progress, review, and TODAY's completed
  - Today's Tasks counter continues to show all tasks for the day until reset
  
  ## Security
  - Function uses SECURITY DEFINER for system-level archival
  - No RLS changes needed (archived tasks simply filtered out in frontend)
*/

-- ============================================================================
-- 1. UPDATE CHECK CONSTRAINT TO ALLOW 'archived' STATUS
-- ============================================================================

-- Drop old constraint
ALTER TABLE checklist_instances
DROP CONSTRAINT IF EXISTS checklist_instances_status_check;

-- Add new constraint with 'archived' included
ALTER TABLE checklist_instances
ADD CONSTRAINT checklist_instances_status_check
CHECK (status IN ('pending', 'in_progress', 'completed', 'archived'));

-- ============================================================================
-- 2. CREATE AUTOMATIC ARCHIVAL FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION archive_old_completed_tasks()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tasks_archived integer := 0;
  v_checklists_archived integer := 0;
  v_today_date text;
BEGIN
  -- Get today's date in Cambodia timezone
  v_today_date := (now() AT TIME ZONE 'Asia/Phnom_Penh')::date::text;
  
  -- Archive tasks with status='completed' from previous days
  WITH archived_tasks AS (
    UPDATE tasks
    SET status = 'archived',
        updated_at = now()
    WHERE status = 'completed'
      AND DATE(due_date) < v_today_date::date
    RETURNING id
  )
  SELECT COUNT(*) INTO v_tasks_archived FROM archived_tasks;
  
  -- Archive checklist instances with status='completed' from previous days
  WITH archived_checklists AS (
    UPDATE checklist_instances
    SET status = 'archived',
        updated_at = now()
    WHERE status = 'completed'
      AND instance_date < v_today_date::date
    RETURNING id
  )
  SELECT COUNT(*) INTO v_checklists_archived FROM archived_checklists;
  
  RAISE NOTICE 'Archived % tasks and % checklists from previous days', 
    v_tasks_archived, v_checklists_archived;
  
  RETURN json_build_object(
    'success', true,
    'tasks_archived', v_tasks_archived,
    'checklists_archived', v_checklists_archived,
    'execution_time', now()
  );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION archive_old_completed_tasks() TO authenticated;

-- ============================================================================
-- 3. CREATE STATISTICS FUNCTION (for monitoring)
-- ============================================================================

CREATE OR REPLACE FUNCTION get_archival_statistics(days_back integer DEFAULT 7)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'total_tasks', (SELECT COUNT(*) FROM tasks),
    'completed_tasks', (SELECT COUNT(*) FROM tasks WHERE status = 'completed'),
    'archived_tasks', (SELECT COUNT(*) FROM tasks WHERE status = 'archived'),
    'old_completed_tasks', (
      SELECT COUNT(*) FROM tasks 
      WHERE status = 'completed' 
      AND DATE(due_date) < CURRENT_DATE
    ),
    'total_checklists', (SELECT COUNT(*) FROM checklist_instances),
    'completed_checklists', (SELECT COUNT(*) FROM checklist_instances WHERE status = 'completed'),
    'archived_checklists', (SELECT COUNT(*) FROM checklist_instances WHERE status = 'archived'),
    'old_completed_checklists', (
      SELECT COUNT(*) FROM checklist_instances 
      WHERE status = 'completed' 
      AND instance_date < CURRENT_DATE
    ),
    'date_range', json_build_object(
      'from', CURRENT_DATE - days_back,
      'to', CURRENT_DATE
    )
  ) INTO v_result;
  
  RETURN v_result;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_archival_statistics(integer) TO authenticated;

-- ============================================================================
-- 4. INITIAL CLEANUP - Archive old completed items NOW
-- ============================================================================

-- Run initial archival for tasks older than today
DO $$
DECLARE
  v_result json;
BEGIN
  SELECT archive_old_completed_tasks() INTO v_result;
  RAISE NOTICE 'Initial archival completed: %', v_result;
END;
$$;

-- ============================================================================
-- 5. VERIFY RESULTS
-- ============================================================================

-- Show statistics after initial cleanup
SELECT get_archival_statistics(30) as archival_stats;
