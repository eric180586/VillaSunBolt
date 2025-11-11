/*
  # Fix approve_task - Correct Notification Type

  1. Problem
    - Uses 'task_approved' type which doesn't exist
    - Allowed types: 'info', 'success', 'warning', 'error', 'task', 'schedule'

  2. Solution
    - Change to 'success' type
*/

CREATE OR REPLACE FUNCTION approve_task(
  p_task_id uuid,
  p_admin_id uuid,
  p_review_quality text DEFAULT NULL,
  p_review_comment text DEFAULT NULL,
  p_admin_photos jsonb DEFAULT '[]'
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task record;
  v_points int;
  v_deadline_bonus int := 0;
  v_quality_bonus int := 0;
BEGIN
  -- Get task data
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;
  
  -- Calculate points
  v_points := COALESCE(v_task.points_value, 0);
  
  -- Check if deadline bonus
  IF v_task.due_date IS NOT NULL AND v_task.completed_at IS NOT NULL THEN
    IF v_task.completed_at <= v_task.due_date THEN
      v_deadline_bonus := 2;
    END IF;
  END IF;
  
  -- Calculate quality bonus
  IF p_review_quality = 'very_good' THEN
    v_quality_bonus := 3;
  ELSIF p_review_quality = 'ready' THEN
    v_quality_bonus := 0;
  ELSIF p_review_quality = 'not_ready' THEN
    v_quality_bonus := -2;
  END IF;
  
  v_points := v_points + v_deadline_bonus + v_quality_bonus;
  
  -- Update task
  UPDATE tasks
  SET
    status = 'completed',
    admin_approved = true,
    admin_reviewed = true,
    reviewed_by = p_admin_id,
    reviewed_at = now(),
    review_quality = p_review_quality,
    admin_notes = p_review_comment,
    admin_photos = p_admin_photos,
    deadline_bonus_awarded = (v_deadline_bonus > 0),
    quality_bonus_points = v_quality_bonus,
    updated_at = now()
  WHERE id = p_task_id;
  
  -- Award points to assigned user
  INSERT INTO points_history (
    user_id,
    points_change,
    category,
    reason,
    created_by,
    created_at
  ) VALUES (
    v_task.assigned_to,
    v_points,
    'task_completed',
    v_task.title,
    p_admin_id,
    now()
  );
  
  -- Award points to helper if exists
  IF v_task.helper_id IS NOT NULL THEN
    INSERT INTO points_history (
      user_id,
      points_change,
      category,
      reason,
      created_by,
      created_at
    ) VALUES (
      v_task.helper_id,
      v_points,
      'task_helper',
      v_task.title || ' (Helper)',
      p_admin_id,
      now()
    );
  END IF;
  
  -- Notify assigned user
  INSERT INTO notifications (
    user_id,
    title,
    message,
    type,
    created_at
  ) VALUES (
    v_task.assigned_to,
    'Aufgabe Genehmigt',
    'Deine Aufgabe "' || v_task.title || '" wurde genehmigt! +' || v_points || ' Punkte',
    'success',
    now()
  );
  
  -- Notify helper if exists
  IF v_task.helper_id IS NOT NULL THEN
    INSERT INTO notifications (
      user_id,
      title,
      message,
      type,
      created_at
    ) VALUES (
      v_task.helper_id,
      'Aufgabe Genehmigt',
      'Die Aufgabe "' || v_task.title || '" wurde genehmigt! +' || v_points || ' Punkte',
      'success',
      now()
    );
  END IF;
END;
$$;
