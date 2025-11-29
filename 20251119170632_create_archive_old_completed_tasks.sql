/*
  # Create archive_old_completed_tasks function
  
  This function archives old completed tasks and checklists 
  to keep the active working set clean.
*/

CREATE OR REPLACE FUNCTION archive_old_completed_tasks()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tasks_archived integer := 0;
  v_checklists_archived integer := 0;
  v_cutoff_date timestamptz;
BEGIN
  -- Archive tasks completed more than 7 days ago
  v_cutoff_date := (now() AT TIME ZONE 'Asia/Phnom_Penh') - INTERVAL '7 days';
  
  -- Archive old completed tasks
  WITH archived AS (
    UPDATE tasks
    SET status = 'archived'
    WHERE status = 'completed'
      AND completed_at < v_cutoff_date
      AND status != 'archived'
    RETURNING id
  )
  SELECT COUNT(*) INTO v_tasks_archived FROM archived;
  
  -- Archive old completed checklist instances
  WITH archived_checklists AS (
    UPDATE checklist_instances
    SET status = 'archived'
    WHERE status = 'completed'
      AND completed_at < v_cutoff_date
    RETURNING id
  )
  SELECT COUNT(*) INTO v_checklists_archived FROM archived_checklists;
  
  RAISE NOTICE 'Archived % tasks and % checklists', v_tasks_archived, v_checklists_archived;
  
  RETURN jsonb_build_object(
    'tasks_archived', v_tasks_archived,
    'checklists_archived', v_checklists_archived
  );
END;
$$;