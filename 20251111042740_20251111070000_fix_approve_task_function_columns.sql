/*
  # Fix approve_task Function - Update to Match Current Schema

  1. Problem
    - approve_task references non-existent columns (base_points, final_points, approved_by, approved_at, completed_before_deadline)
    - This causes task approval to fail completely

  2. Solution
    - Rewrite function to use actual columns:
      - points_value (not base_points)
      - reviewed_by (not approved_by)
      - reviewed_at (not approved_at)
      - admin_approved, admin_reviewed
      - deadline_bonus_awarded
      - quality_bonus_points
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
  v_assigned_name text;
  v_helper_name text;
  v_points int;
  v_deadline_bonus int := 0;
  v_quality_bonus int := 0;
  v_old_data jsonb;
  v_new_data jsonb;
BEGIN
  -- Get task data
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;
  
  -- Store old data
  v_old_data := to_jsonb(v_task);
  
  -- Get assigned user name
  SELECT full_name INTO v_assigned_name FROM profiles WHERE id = v_task.assigned_to;
  
  -- Calculate points
  v_points := COALESCE(v_task.points_value, 0);
  
  -- Check if deadline bonus should be awarded
  IF v_task.due_date IS NOT NULL AND v_task.completed_at IS NOT NULL THEN
    IF v_task.completed_at <= v_task.due_date THEN
      v_deadline_bonus := 2;
    END IF;
  END IF;
  
  -- Calculate quality bonus based on review
  IF p_review_quality = 'excellent' THEN
    v_quality_bonus := 3;
  ELSIF p_review_quality = 'good' THEN
    v_quality_bonus := 1;
  ELSIF p_review_quality = 'poor' THEN
    v_quality_bonus := -2;
  END IF;
  
  -- Total points
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
  
  -- Store new data
  SELECT to_jsonb(tasks.*) INTO v_new_data FROM tasks WHERE id = p_task_id;
  
  -- Award points to assigned user
  INSERT INTO points_history (
    user_id,
    points,
    category,
    description,
    created_at
  ) VALUES (
    v_task.assigned_to,
    v_points,
    'task_completed',
    v_task.title || ' (Quality: ' || COALESCE(p_review_quality, 'standard') || ')',
    now()
  );
  
  -- Award points to helper if exists
  IF v_task.helper_id IS NOT NULL THEN
    SELECT full_name INTO v_helper_name FROM profiles WHERE id = v_task.helper_id;
    INSERT INTO points_history (
      user_id,
      points,
      category,
      description,
      created_at
    ) VALUES (
      v_task.helper_id,
      v_points,
      'task_helper',
      v_task.title || ' (Helper)',
      now()
    );
  END IF;
  
  -- Update daily goals
  INSERT INTO daily_point_goals (user_id, goal_date, achievable_points, earned_points, created_at)
  VALUES (v_task.assigned_to, CURRENT_DATE, 0, v_points, now())
  ON CONFLICT (user_id, goal_date)
  DO UPDATE SET earned_points = daily_point_goals.earned_points + EXCLUDED.earned_points;
  
  IF v_task.helper_id IS NOT NULL THEN
    INSERT INTO daily_point_goals (user_id, goal_date, achievable_points, earned_points, created_at)
    VALUES (v_task.helper_id, CURRENT_DATE, 0, v_points, now())
    ON CONFLICT (user_id, goal_date)
    DO UPDATE SET earned_points = daily_point_goals.earned_points + EXCLUDED.earned_points;
  END IF;
  
  -- Log the approval
  PERFORM log_admin_action(
    p_admin_id,
    'approve_task',
    'tasks',
    p_task_id,
    v_task.title,
    v_old_data,
    v_new_data,
    'Approved: ' || COALESCE(p_review_quality, 'No rating') || ' - Points: ' || v_points
  );
  
  -- Create notification
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
    'task_approved',
    now()
  );
  
  IF v_task.helper_id IS NOT NULL THEN
    INSERT INTO notifications (
      user_id,
      title,
      message,
      type,
      created_at
    ) VALUES (
      v_task.helper_id,
      'Aufgabe Genehmigt (Helper)',
      'Die Aufgabe "' || v_task.title || '" wurde genehmigt! +' || v_points || ' Punkte',
      'task_approved',
      now()
    );
  END IF;
END;
$$;
