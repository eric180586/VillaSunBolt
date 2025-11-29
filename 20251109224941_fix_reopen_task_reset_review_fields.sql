/*
  # Fix Reopen Task - Reset Review Fields

  1. Changes
    - Update reopen_task_with_penalty to reset review fields
    - Reset admin_reviewed, admin_approved, reviewed_by, reviewed_at
    - Reset completed_at so task can be completed again
    - This allows staff to resubmit the task for review

  2. Notes
    - Task status is set to 'in_progress'
    - Staff can now complete the task again
    - Admin can review it again after staff resubmits
*/

CREATE OR REPLACE FUNCTION reopen_task_with_penalty(
  p_task_id uuid,
  p_admin_id uuid,
  p_admin_notes text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_task record;
BEGIN
  -- Verify admin
  IF NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = p_admin_id AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can reopen tasks';
  END IF;

  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;

  -- Update task - reset review fields so staff can complete again
  UPDATE tasks
  SET 
    status = 'in_progress',
    admin_notes = p_admin_notes,
    admin_reviewed = false,
    admin_approved = NULL,
    reviewed_by = NULL,
    reviewed_at = NULL,
    completed_at = NULL,
    review_quality = NULL,
    quality_bonus_points = 0,
    reopened_count = COALESCE(reopened_count, 0) + 1,
    updated_at = now()
  WHERE id = p_task_id;

  -- Notification
  IF v_task.assigned_to IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type, priority)
    VALUES (
      v_task.assigned_to,
      'Task zur Überarbeitung',
      'Bitte überarbeite: ' || v_task.title || '. ' || COALESCE(p_admin_notes, ''),
      'task_reopened',
      'high'
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'reopened_count', COALESCE(v_task.reopened_count, 0) + 1);
END;
$$;
