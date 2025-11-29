/*
  # Fix Notification Messages - Support All Languages

  ## Problem
  - Notifications show German text even when user has English profile
  - v_quality_text variable is hardcoded in German
  - message, message_de, message_en, message_km all use same v_quality_text

  ## Solution
  - Create separate variables for each language
  - Use correct language variable for each message column
  - Default 'message' column should use German (for backwards compatibility)

  ## Example
  Roger (English profile) was getting:
  - "Sehr gut gemacht! - 1 (+14 points)" ❌

  Will now get:
  - "Very well done! - 1 (+14 points)" ✅
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
  v_quality_text_de text;
  v_quality_text_en text;
  v_quality_text_km text;
  v_notification_id uuid;
BEGIN
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;
  
  -- Determine quality bonus and texts in ALL languages
  CASE p_review_quality
    WHEN 'very_good' THEN 
      v_quality_bonus := 3;
      v_quality_text_de := 'Sehr gut gemacht!';
      v_quality_text_en := 'Very well done!';
      v_quality_text_km := 'ល្អណាស់!';
    WHEN 'ready' THEN 
      v_quality_bonus := 0;
      v_quality_text_de := 'Gut erledigt';
      v_quality_text_en := 'Well done';
      v_quality_text_km := 'បានល្អ';
    WHEN 'not_ready' THEN 
      v_quality_bonus := -2;
      v_quality_text_de := 'Bitte nochmal überarbeiten';
      v_quality_text_en := 'Please revise';
      v_quality_text_km := 'សូមកែប្រែម្តងទៀត';
    ELSE 
      v_quality_bonus := 0;
      v_quality_text_de := 'Erledigt';
      v_quality_text_en := 'Completed';
      v_quality_text_km := 'បានបញ្ចប់';
  END CASE;
  
  v_base_points := COALESCE(v_task.points_value, 0);
  
  -- Check if completed before deadline
  IF v_task.due_date IS NOT NULL AND v_task.completed_at <= v_task.due_date THEN
    v_deadline_bonus := 2;
  END IF;
  
  v_total_points := v_base_points + v_quality_bonus + v_deadline_bonus;
  
  -- Get staff and helper IDs (check both fields for helper)
  v_staff_id := v_task.assigned_to;
  v_helper_id := COALESCE(v_task.helper_id, v_task.secondary_assigned_to);
  
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
    INSERT INTO points_history (user_id, points_change, category, reason, created_by)
    VALUES (v_staff_id, v_total_points, 'task_completed', v_task.title, p_admin_id);
    
    -- Insert notification with ALL language variants
    INSERT INTO notifications (
      user_id,
      type,
      title,
      title_de,
      title_en,
      title_km,
      message,
      message_de,
      message_en,
      message_km
    ) VALUES (
      v_staff_id,
      'task_approved',
      'Task Approved!',
      'Aufgabe genehmigt!',
      'Task Approved!',
      'កិច្ចការអនុម័ត!',
      v_quality_text_de || ' - ' || v_task.title || ' (+' || v_total_points || ' Punkte)',
      v_quality_text_de || ' - ' || v_task.title || ' (+' || v_total_points || ' Punkte)',
      v_quality_text_en || ' - ' || v_task.title || ' (+' || v_total_points || ' points)',
      v_quality_text_km || ' - ' || v_task.title || ' (+' || v_total_points || ' ពិន្ទុ)'
    )
    RETURNING id INTO v_notification_id;
    
    BEGIN
      PERFORM send_push_notification(v_staff_id, v_notification_id);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Push notification failed for user %: %', v_staff_id, SQLERRM;
    END;
  END IF;
  
  -- Award 50% points to helper (check both helper_id and secondary_assigned_to)
  IF v_helper_id IS NOT NULL THEN
    v_helper_points := FLOOR(v_total_points::numeric / 2);
    
    INSERT INTO points_history (user_id, points_change, category, reason, created_by)
    VALUES (v_helper_id, v_helper_points, 'task_completed', 'Helper: ' || v_task.title, p_admin_id);
    
    -- Notification for helper
    INSERT INTO notifications (
      user_id,
      type,
      title,
      title_de,
      title_en,
      title_km,
      message,
      message_de,
      message_en,
      message_km
    ) VALUES (
      v_helper_id,
      'task_approved',
      'Task Approved!',
      'Aufgabe genehmigt!',
      'Task Approved!',
      'កិច្ចការអនុម័ត!',
      v_quality_text_de || ' (Helfer) - ' || v_task.title || ' (+' || v_helper_points || ' Punkte)',
      v_quality_text_de || ' (Helfer) - ' || v_task.title || ' (+' || v_helper_points || ' Punkte)',
      v_quality_text_en || ' (Helper) - ' || v_task.title || ' (+' || v_helper_points || ' points)',
      v_quality_text_km || ' (អ្នកជួយ) - ' || v_task.title || ' (+' || v_helper_points || ' ពិន្ទុ)'
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
    'quality_bonus', v_quality_bonus,
    'deadline_bonus', v_deadline_bonus
  );
END;
$$;

COMMENT ON FUNCTION approve_task_with_quality IS 
'Approves task with quality rating. FIXED: Uses language-specific texts for notifications!';
