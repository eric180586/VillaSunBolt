/*
  # Add Task Archiving System
  
  1. New Functions
    - archive_old_tasks() - Archiviert Tasks die älter als gestern sind
    - cleanup_old_archived_tasks() - Löscht sehr alte archivierte Tasks
    
  2. Changes
    - Alte incomplete Tasks werden automatisch archiviert
    - Sehr alte archivierte Tasks (>30 Tage) werden gelöscht
*/

-- 1. Function to archive old incomplete tasks
CREATE OR REPLACE FUNCTION archive_old_tasks()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_archived_count integer := 0;
BEGIN
  -- Archive tasks older than yesterday that are not completed
  UPDATE tasks
  SET status = 'archived', updated_at = now()
  WHERE DATE(due_date AT TIME ZONE 'Asia/Phnom_Penh') < CURRENT_DATE
  AND is_template = false
  AND status NOT IN ('completed', 'archived');

  GET DIAGNOSTICS v_archived_count = ROW_COUNT;

  RETURN v_archived_count;
END;
$$;

-- 2. Function to cleanup very old archived tasks
CREATE OR REPLACE FUNCTION cleanup_old_archived_tasks()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted_count integer := 0;
BEGIN
  -- Delete tasks archived more than 30 days ago
  DELETE FROM tasks
  WHERE status = 'archived'
  AND updated_at < (now() - INTERVAL '30 days')
  AND is_template = false;

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  RETURN v_deleted_count;
END;
$$;

-- 3. Run archive_old_tasks immediately to clean up current old tasks
SELECT archive_old_tasks();
