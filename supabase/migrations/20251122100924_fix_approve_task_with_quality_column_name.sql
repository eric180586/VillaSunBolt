/*
  # Fix approve_task_with_quality - Wrong Column Name
  
  1. Problem
    - Function tries to set `deadline_bonus_points` but column is `deadline_bonus_awarded`
    - This causes 400 error when admin tries to approve task
  
  2. Solution
    - Fix the column name in the UPDATE statement
    - Change from INTEGER to BOOLEAN (true/false instead of 0/1)
*/

CREATE OR REPLACE FUNCTION approve_task_with_quality(
  p_task_id uuid,
  p_admin_id uuid,
  p_review_quality text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task record;
  v_base_points integer;
  v_quality_bonus integer;
  v_total_points integer;
  v_deadline_bonus integer := 0;
  v_staff_id uuid;
  v_helper_id uuid;
  v_helper_points integer;
  v_quality_text text;
  v_notification_id uuid;
BEGIN
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;
  
  -- Determine quality bonus
  CASE p_review_quality
    WHEN 'very_good' THEN 
      v_quality_bonus := 3;
      v_quality_text := 'Sehr gut gemacht!';
    WHEN 'ready' THEN 
      v_quality_bonus := 0;
      v_quality_text := 'Gut erledigt';
    WHEN 'not_ready' THEN 
      v_quality_bonus := -2;
      v_quality_text := 'Bitte nochmal überarbeiten';
    ELSE 
      v_quality_bonus := 0;
      v_quality_text := 'Erledigt';
  END CASE;
  
  v_base_points := COALESCE(v_task.points_value, 0);
  
  -- Check for deadline bonus (task completed before deadline)
  IF v_task.completed_at IS NOT NULL AND v_task.due_date IS NOT NULL 
     AND v_task.completed_at < v_task.due_date THEN
    v_deadline_bonus := 1;
  END IF;
  
  v_total_points := v_base_points + v_quality_bonus + v_deadline_bonus;
  
  IF v_total_points < 0 THEN
    v_total_points := 0;
  END IF;
  
  v_staff_id := v_task.assigned_to;
  v_helper_id := v_task.helper_id;
  v_helper_points := GREATEST(FLOOR(v_total_points * 0.5), 0);
  
  -- Update task (FIX: Use correct column name)
  UPDATE tasks 
  SET 
    status = 'completed',
    admin_reviewed = true,
    admin_approved = true,
    reviewed_by = p_admin_id,
    reviewed_at = now(),
    review_quality = p_review_quality,
    quality_bonus_points = v_quality_bonus,
    deadline_bonus_awarded = (v_deadline_bonus > 0),
    updated_at = now()
  WHERE id = p_task_id;
  
  -- Award points to primary staff
  IF v_staff_id IS NOT NULL THEN
    INSERT INTO points_history (user_id, points_change, category, reason, task_id, created_by)
    VALUES (v_staff_id, v_total_points, 'task_completed', v_task.title, p_task_id, p_admin_id);
    
    -- Create notification with translations
    INSERT INTO notifications (
      user_id,
      type,
      title_de,
      title_en,
      title_km,
      message_de,
      message_en,
      message_km
    ) VALUES (
      v_staff_id,
      'task_approved',
      'Aufgabe genehmigt!',
      'Task Approved!',
      'កិច្ចការអនុម័ត!',
      v_quality_text || ' - ' || v_task.title || ' (+' || v_total_points || ' Punkte)',
      v_quality_text || ' - ' || v_task.title || ' (+' || v_total_points || ' points)',
      v_quality_text || ' - ' || v_task.title || ' (+' || v_total_points || ' ពិន្ទុ)'
    )
    RETURNING id INTO v_notification_id;
    
    -- Send push notification
    BEGIN
      PERFORM send_push_notification(v_staff_id, v_notification_id);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Push notification failed for user %: %', v_staff_id, SQLERRM;
    END;
  END IF;
  
  -- Award 50% points to helper if exists
  IF v_helper_id IS NOT NULL AND v_helper_id != v_staff_id AND v_helper_points > 0 THEN
    INSERT INTO points_history (user_id, points_change, category, reason, task_id, created_by)
    VALUES (v_helper_id, v_helper_points, 'task_completed', v_task.title || ' (Helfer)', p_task_id, p_admin_id);
    
    INSERT INTO notifications (
      user_id,
      type,
      title_de,
      title_en,
      title_km,
      message_de,
      message_en,
      message_km
    ) VALUES (
      v_helper_id,
      'task_approved',
      'Helfer Punkte!',
      'Helper Points!',
      'ពិន្ទុជំនួយការ!',
      'Aufgabe genehmigt: ' || v_task.title || ' (+' || v_helper_points || ' Punkte)',
      'Task approved: ' || v_task.title || ' (+' || v_helper_points || ' points)',
      'កិច្ចការអនុម័ត: ' || v_task.title || ' (+' || v_helper_points || ' ពិន្ទុ)'
    )
    RETURNING id INTO v_notification_id;
    
    BEGIN
      PERFORM send_push_notification(v_helper_id, v_notification_id);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Push notification failed for helper %: %', v_helper_id, SQLERRM;
    END;
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'points_awarded', v_total_points,
    'helper_points', v_helper_points,
    'quality_bonus', v_quality_bonus,
    'deadline_bonus', v_deadline_bonus
  );
END;
$$;
