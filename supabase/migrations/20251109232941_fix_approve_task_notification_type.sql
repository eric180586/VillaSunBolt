/*
  # Fix approve_task_with_quality - Use correct notification type

  1. Changes
    - Change notification type from 'task_approved' to 'success'
    - notifications.type constraint allows: info, success, warning, error, task, schedule
    - 'task_approved' is not a valid type

  2. Notes
    - Using 'success' as it's a positive notification about task approval
*/

CREATE OR REPLACE FUNCTION approve_task_with_quality(
  p_task_id uuid,
  p_admin_id uuid,
  p_review_quality text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_task record;
  v_base_points integer;
  v_quality_bonus integer;
  v_total_points integer;
  v_deadline_bonus integer := 0;
  v_staff_id uuid;
  v_helper_id uuid;
BEGIN
  -- Get task details
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;

  -- Determine quality bonus
  CASE p_review_quality
    WHEN 'very_good' THEN v_quality_bonus := 2;
    WHEN 'ready' THEN v_quality_bonus := 0;
    WHEN 'not_ready' THEN v_quality_bonus := -1;
    ELSE v_quality_bonus := 0;
  END CASE;

  -- Get base points
  v_base_points := COALESCE(v_task.points_value, 0);
  
  -- Check for deadline bonus (completed before due date)
  IF v_task.completed_at IS NOT NULL AND v_task.due_date IS NOT NULL AND v_task.completed_at < v_task.due_date THEN
    v_deadline_bonus := 2;
  END IF;

  -- Calculate total points
  v_total_points := v_base_points + v_quality_bonus + v_deadline_bonus;
  
  -- Ensure points don't go negative
  IF v_total_points < 0 THEN
    v_total_points := 0;
  END IF;

  v_staff_id := v_task.assigned_to;
  v_helper_id := v_task.helper_id;

  -- Update task status to 'completed'
  UPDATE tasks 
  SET 
    status = 'completed',
    admin_reviewed = true,
    admin_approved = true,
    reviewed_by = p_admin_id,
    reviewed_at = now(),
    review_quality = p_review_quality,
    quality_bonus_points = v_quality_bonus,
    updated_at = now()
  WHERE id = p_task_id;

  -- Award points to primary staff
  IF v_staff_id IS NOT NULL THEN
    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (
      v_staff_id,
      v_total_points,
      'Task completed and approved: ' || v_task.title,
      'task_completed',
      p_admin_id
    );
  END IF;

  -- Award 50% points to helper if exists
  IF v_helper_id IS NOT NULL AND v_helper_id != v_staff_id THEN
    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (
      v_helper_id,
      GREATEST(FLOOR(v_total_points * 0.5), 0),
      'Task assistance (50%): ' || v_task.title,
      'task_completed',
      p_admin_id
    );
  END IF;

  -- Send notification to staff with correct type
  IF v_staff_id IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_staff_id,
      'Task Approved',
      v_task.title || ' wurde genehmigt! Du erhältst ' || v_total_points || ' Punkte.',
      'success'
    );
  END IF;

  -- Return success with point breakdown
  RETURN jsonb_build_object(
    'success', true,
    'base_points', v_base_points,
    'quality_bonus', v_quality_bonus,
    'deadline_bonus', v_deadline_bonus,
    'total_points', v_total_points
  );
END;
$$;
