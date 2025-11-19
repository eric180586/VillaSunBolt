/*
  # Fix approve_task_with_quality to use i18n notifications
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
BEGIN
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;
  
  -- Determine quality bonus
  CASE p_review_quality
    WHEN 'very_good' THEN v_quality_bonus := 3;
    WHEN 'ready' THEN v_quality_bonus := 0;
    WHEN 'not_ready' THEN v_quality_bonus := -2;
    ELSE v_quality_bonus := 0;
  END CASE;
  
  v_base_points := COALESCE(v_task.points_value, 0);
  
  -- Check for deadline bonus
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
  
  -- Update task
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
    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (
      v_staff_id,
      v_total_points,
      v_task.title || 
        CASE WHEN v_deadline_bonus > 0 THEN ' (deadline +1)' ELSE '' END ||
        CASE 
          WHEN p_review_quality = 'very_good' THEN ' (very good +3)'
          WHEN p_review_quality = 'not_ready' THEN ' (not ready -2)'
          ELSE ''
        END,
      'task_completed',
      p_admin_id
    );
    
    -- Send notification with translations
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
      'Gut gemacht!',
      'Well done!',
      'ល្អណាស់!',
      'Deine Aufgabe "' || v_task.title || '" wurde genehmigt! +' || v_total_points || ' Punkte',
      'Your task "' || v_task.title || '" was approved! +' || v_total_points || ' points',
      'កិច្ចការ "' || v_task.title || '" ត្រូវបានអនុម័ត! +' || v_total_points || ' ពិន្ទុ'
    );
  END IF;
  
  -- Award 50% points to helper if exists
  IF v_helper_id IS NOT NULL AND v_helper_id != v_staff_id THEN
    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (
      v_helper_id,
      v_helper_points,
      v_task.title || ' (Helper 50%)',
      'task_completed',
      p_admin_id
    );
    
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
      'Gut gemacht!',
      'Well done!',
      'ល្អណាស់!',
      'Aufgabe "' || v_task.title || '" genehmigt! +' || v_helper_points || ' Punkte (Helfer)',
      'Task "' || v_task.title || '" approved! +' || v_helper_points || ' points (Helper)',
      'កិច្ចការ "' || v_task.title || '" អនុម័ត! +' || v_helper_points || ' ពិន្ទុ (ជំនួយការ)'
    );
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'base_points', v_base_points,
    'quality_bonus', v_quality_bonus,
    'deadline_bonus', v_deadline_bonus,
    'total_points', v_total_points
  );
END;
$$;