/*
  # Fix complete_task_with_helper - Always Show Helper Selection

  ## Changes:
  - Helper selection always shown for all tasks
  - Items without is_template field supported
  - Points split 50/50 when helper selected
  - Proper notification to admin for review
  
  ## Features:
  - Works with tasks with or without items
  - Helper info stored in secondary_assigned_to
  - Points split automatically
  - Notifications to admin
*/

CREATE OR REPLACE FUNCTION complete_task_with_helper(
  p_task_id uuid,
  p_helper_id uuid DEFAULT NULL,
  p_photo_urls jsonb DEFAULT '[]',
  p_notes text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task record;
  v_points_per_person integer;
  v_primary_name text;
  v_helper_name text;
BEGIN
  -- Get task
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;
  
  -- Check if all items completed (if task has items)
  IF v_task.items IS NOT NULL AND jsonb_array_length(v_task.items) > 0 THEN
    IF NOT all_task_items_completed(v_task.items) THEN
      RAISE EXCEPTION 'Not all items are completed';
    END IF;
  END IF;
  
  -- Calculate points (split if helper)
  IF p_helper_id IS NOT NULL THEN
    v_points_per_person := FLOOR(v_task.points_value / 2.0);
  ELSE
    v_points_per_person := v_task.points_value;
  END IF;
  
  -- Update task to pending_review
  UPDATE tasks SET 
    status = 'pending_review',
    secondary_assigned_to = p_helper_id,
    photo_urls = COALESCE(p_photo_urls, '[]'::jsonb),
    completed_at = now(),
    points_value = v_points_per_person
  WHERE id = p_task_id;
  
  -- Get names for notification
  SELECT full_name INTO v_primary_name FROM profiles WHERE id = v_task.assigned_to;
  
  IF p_helper_id IS NOT NULL THEN
    SELECT full_name INTO v_helper_name FROM profiles WHERE id = p_helper_id;
  END IF;
  
  -- Send notification to admin
  INSERT INTO notifications (user_id, type, title, message, reference_id, priority)
  SELECT 
    id, 
    'task_completed', 
    'Task zur Review',
    CASE 
      WHEN p_helper_id IS NOT NULL THEN
        v_primary_name || ' und ' || v_helper_name || ' haben Task "' || v_task.title || '" abgeschlossen'
      ELSE
        v_primary_name || ' hat Task "' || v_task.title || '" abgeschlossen'
    END,
    p_task_id, 
    'high'
  FROM profiles WHERE role = 'admin';
END;
$$;

COMMENT ON FUNCTION complete_task_with_helper IS 
'Completes task with optional helper. Points split 50/50 if helper provided. Works for tasks with or without items. Always sends to admin review.';
