/*
  # Fix Task Notifications - Complete System
  
  1. New Functions
    - notify_task_assignment() - Trigger für neue Task-Zuweisungen
    
  2. Updated Functions
    - approve_task_with_items() - Jetzt mit Notifications
    
  3. New Triggers
    - trigger_notify_new_task - Sendet Notification bei Task-Erstellung
*/

-- 1. Function: Notify when task is assigned
CREATE OR REPLACE FUNCTION notify_task_assignment()
RETURNS TRIGGER AS $$
BEGIN
  -- Only send notification for non-template tasks with assigned user
  IF NEW.is_template = false AND NEW.assigned_to IS NOT NULL THEN
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      priority
    ) VALUES (
      NEW.assigned_to,
      'task',
      'New Task Assigned',
      'You have been assigned: "' || NEW.title || '"',
      'normal'
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create trigger for task assignment notifications
DROP TRIGGER IF EXISTS trigger_notify_new_task ON tasks;
CREATE TRIGGER trigger_notify_new_task
AFTER INSERT ON tasks
FOR EACH ROW
EXECUTE FUNCTION notify_task_assignment();

-- 3. Update approve_task_with_items to include notifications
CREATE OR REPLACE FUNCTION approve_task_with_items(
  p_task_id uuid,
  p_admin_id uuid,
  p_admin_notes text DEFAULT NULL,
  p_admin_photos jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task record;
  v_points integer;
  v_assigned_name text;
  v_helper_name text;
BEGIN
  -- Get task data
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Task not found');
  END IF;
  
  v_points := COALESCE(v_task.points_value, 0);
  
  -- Update task
  UPDATE tasks
  SET 
    status = 'completed',
    completed_at = COALESCE(completed_at, now()),
    admin_notes = p_admin_notes,
    admin_photos = p_admin_photos,
    admin_approved = true,
    admin_reviewed = true,
    reviewed_by = p_admin_id,
    reviewed_at = now()
  WHERE id = p_task_id;
  
  -- Award points to assigned user
  IF v_task.assigned_to IS NOT NULL AND v_points > 0 THEN
    INSERT INTO points_history (
      user_id,
      points_change,
      reason,
      category,
      created_by
    ) VALUES (
      v_task.assigned_to,
      v_points,
      'Task completed: ' || v_task.title,
      'task_completed',
      p_admin_id
    );
    
    -- Send notification to assigned user
    SELECT full_name INTO v_assigned_name FROM profiles WHERE id = v_task.assigned_to;
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      priority
    ) VALUES (
      v_task.assigned_to,
      'success',
      'Task Approved',
      'Your task "' || v_task.title || '" has been approved! +' || v_points || ' points',
      'normal'
    );
  END IF;
  
  -- Award points to helper if exists
  IF v_task.helper_id IS NOT NULL AND v_points > 0 THEN
    INSERT INTO points_history (
      user_id,
      points_change,
      reason,
      category,
      created_by
    ) VALUES (
      v_task.helper_id,
      v_points,
      'Task helper: ' || v_task.title,
      'task_completed',
      p_admin_id
    );
    
    -- Send notification to helper
    SELECT full_name INTO v_helper_name FROM profiles WHERE id = v_task.helper_id;
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      priority
    ) VALUES (
      v_task.helper_id,
      'success',
      'Task Approved (Helper)',
      'Task "' || v_task.title || '" has been approved! +' || v_points || ' points (Helper)',
      'normal'
    );
  END IF;
  
  RETURN jsonb_build_object('success', true);
END;
$$;
