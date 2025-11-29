/*
  # Fix approve_task Function - Correct Column Names
  
  1. Changes
    - Use points_change instead of points
    - Use reason instead of description
    - Use created_by instead of no creator
*/

CREATE OR REPLACE FUNCTION public.approve_task(
  p_task_id uuid,
  p_admin_notes text DEFAULT NULL,
  p_admin_photos jsonb DEFAULT '[]'::jsonb,
  p_review_quality text DEFAULT 'perfect'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task RECORD;
  v_base_points INTEGER := 0;
  v_quality_bonus INTEGER := 0;
  v_deadline_bonus INTEGER := 0;
  v_total_points INTEGER := 0;
  v_category TEXT;
  v_points_history_id UUID;
BEGIN
  -- Get task details
  SELECT t.*, p.full_name as user_name, t.title as task_title
  INTO v_task
  FROM tasks t
  LEFT JOIN profiles p ON p.id = t.assigned_to
  WHERE t.id = p_task_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;

  -- Calculate points
  v_base_points := COALESCE(v_task.points_value, 5);

  -- Quality bonus
  CASE p_review_quality
    WHEN 'perfect' THEN v_quality_bonus := 2;
    WHEN 'good' THEN v_quality_bonus := 1;
    WHEN 'acceptable' THEN v_quality_bonus := 0;
    ELSE v_quality_bonus := 0;
  END CASE;

  -- Deadline bonus (only if completed before due date)
  IF v_task.completed_at IS NOT NULL AND v_task.due_date IS NOT NULL THEN
    IF v_task.completed_at <= v_task.due_date THEN
      v_deadline_bonus := 2;
    END IF;
  END IF;

  v_total_points := v_base_points + v_quality_bonus + v_deadline_bonus;
  v_category := 'task_approved';

  -- Update task
  UPDATE tasks
  SET 
    status = 'completed',
    admin_notes = p_admin_notes,
    admin_photos = p_admin_photos,
    review_quality = p_review_quality,
    reviewed_at = now(),
    reviewed_by = auth.uid()
  WHERE id = p_task_id;

  -- Award points with CORRECT column names
  INSERT INTO points_history (
    user_id,
    points_change,
    reason,
    category,
    created_by
  ) VALUES (
    v_task.assigned_to,
    v_total_points,
    'Task approved: ' || v_task.title || ' (Base: ' || v_base_points || ', Quality: +' || v_quality_bonus || ', Deadline: +' || v_deadline_bonus || ')',
    v_category,
    auth.uid()
  )
  RETURNING id INTO v_points_history_id;

  -- Create notification
  INSERT INTO notifications (
    user_id,
    type,
    title,
    message
  ) VALUES (
    v_task.assigned_to,
    'task_approved',
    'Task Approved',
    'Your task "' || v_task.title || '" has been approved! Points earned: ' || v_total_points
  );

  RETURN jsonb_build_object(
    'success', true,
    'base_points', v_base_points,
    'quality_bonus', v_quality_bonus,
    'deadline_bonus', v_deadline_bonus,
    'total_points', v_total_points
  );
END;
$$;
