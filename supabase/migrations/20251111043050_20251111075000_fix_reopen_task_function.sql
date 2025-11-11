/*
  # Fix reopen_task Function

  1. Problem
    - References wrong columns (points, description, earned_points, etc.)
    - Wrong notification type

  2. Solution
    - Use correct column names
    - Use 'warning' notification type
*/

CREATE OR REPLACE FUNCTION reopen_task(
  p_task_id uuid,
  p_admin_id uuid,
  p_reason text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task record;
BEGIN
  -- Get task data
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;
  
  -- Deduct penalty points
  INSERT INTO points_history (
    user_id,
    points_change,
    category,
    reason,
    created_by,
    created_at
  ) VALUES (
    v_task.assigned_to,
    -5,
    'task_reopened',
    'Aufgabe wiedereröffnet: ' || v_task.title,
    p_admin_id,
    now()
  );
  
  -- Also deduct from helper if exists
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
      -5,
      'task_reopened',
      'Aufgabe wiedereröffnet: ' || v_task.title || ' (Helper)',
      p_admin_id,
      now()
    );
  END IF;
  
  -- Reopen task - reset review fields
  UPDATE tasks
  SET
    status = 'pending',
    completed_at = NULL,
    admin_approved = false,
    admin_reviewed = false,
    reviewed_by = NULL,
    reviewed_at = NULL,
    review_quality = NULL,
    admin_notes = NULL,
    admin_photos = '[]'::jsonb,
    photo_urls = '[]'::jsonb,
    completion_notes = NULL,
    deadline_bonus_awarded = false,
    quality_bonus_points = 0,
    updated_at = now()
  WHERE id = p_task_id;
  
  -- Notify assigned user
  INSERT INTO notifications (
    user_id,
    title,
    message,
    type,
    created_at
  ) VALUES (
    v_task.assigned_to,
    'Aufgabe Wiedereröffnet',
    'Deine Aufgabe "' || v_task.title || '" wurde wiedereröffnet. Grund: ' || p_reason || ' (-5 Punkte)',
    'warning',
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
      'Aufgabe Wiedereröffnet',
      'Die Aufgabe "' || v_task.title || '" wurde wiedereröffnet. Grund: ' || p_reason || ' (-5 Punkte)',
      'warning',
      now()
    );
  END IF;
END;
$$;
