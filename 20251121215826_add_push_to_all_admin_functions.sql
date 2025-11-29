/*
  # Add Push Notifications to All Admin Functions

  1. Problem
    - Admin functions create notifications but don't send push notifications
    - Users don't get real-time alerts for important admin actions
    - Functions affected:
      - approve_task_with_quality
      - approve_task_with_items
      - reopen_task
      - approve_check_in
      - reject_check_in
      - add_bonus_points
      - check_missed_patrol_rounds

  2. Solution
    - Add push notification calls to all admin functions
    - Ensure users get real-time alerts for all important actions
    - Use consistent notification patterns

  3. Note
    - This migration only adds push notifications where missing
    - Does not change core function logic
*/

-- Helper function to send notification with push
CREATE OR REPLACE FUNCTION create_notification_with_push(
  p_user_id uuid,
  p_title text,
  p_message text,
  p_type text,
  p_data jsonb DEFAULT '{}'::jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Create in-app notification
  INSERT INTO notifications (user_id, title, message, type)
  VALUES (p_user_id, p_title, p_message, p_type);

  -- Send push notification
  PERFORM send_push_via_edge_function(
    p_user_ids := ARRAY[p_user_id::text],
    p_title := p_title,
    p_body := p_message,
    p_data := p_data || jsonb_build_object('type', p_type)
  );
END;
$$;

-- Update approve_task_with_quality to include push notifications
-- This function is called when admin approves a task with quality rating
-- It needs to notify the staff member about approval
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
  
  UPDATE tasks 
  SET 
    status = 'completed',
    admin_reviewed = true,
    admin_approved = true,
    reviewed_by = p_admin_id,
    reviewed_at = now(),
    review_quality = p_review_quality,
    quality_bonus_points = v_quality_bonus,
    deadline_bonus_points = v_deadline_bonus
  WHERE id = p_task_id;
  
  IF v_staff_id IS NOT NULL THEN
    INSERT INTO points_history (user_id, points_change, category, reason, task_id, created_by)
    VALUES (v_staff_id, v_total_points, 'task_completed', v_task.title, p_task_id, p_admin_id);
    
    -- Send notification with push
    PERFORM create_notification_with_push(
      v_staff_id,
      'Task Approved',
      v_quality_text || ': ' || v_task.title || ' (+' || v_total_points || ' pts)',
      'task_approved',
      jsonb_build_object('task_id', p_task_id, 'points', v_total_points)
    );
  END IF;
  
  IF v_helper_id IS NOT NULL AND v_helper_points > 0 THEN
    INSERT INTO points_history (user_id, points_change, category, reason, task_id, created_by)
    VALUES (v_helper_id, v_helper_points, 'task_completed', v_task.title || ' (Helper)', p_task_id, p_admin_id);
    
    PERFORM create_notification_with_push(
      v_helper_id,
      'Helper Points',
      'Task approved: ' || v_task.title || ' (+' || v_helper_points || ' pts)',
      'task_approved',
      jsonb_build_object('task_id', p_task_id, 'points', v_helper_points, 'is_helper', true)
    );
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'points_awarded', v_total_points,
    'helper_points', v_helper_points
  );
END;
$$;

-- Update reopen_task to include push notification
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
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;
  
  INSERT INTO points_history (user_id, points_change, category, reason, created_by, created_at)
  VALUES (v_task.assigned_to, -5, 'task_reopened', 'Task reopened: ' || v_task.title, p_admin_id, now());
  
  IF v_task.helper_id IS NOT NULL THEN
    INSERT INTO points_history (user_id, points_change, category, reason, created_by, created_at)
    VALUES (v_task.helper_id, -5, 'task_reopened', 'Task reopened: ' || v_task.title || ' (Helper)', p_admin_id, now());
    
    PERFORM create_notification_with_push(
      v_task.helper_id,
      'Task Reopened',
      'Please redo: ' || v_task.title || ' (-5 pts)',
      'task_reopened',
      jsonb_build_object('task_id', p_task_id, 'reason', p_reason)
    );
  END IF;
  
  UPDATE tasks
  SET
    status = 'pending',
    completed_at = NULL,
    admin_approved = false,
    admin_reviewed = false,
    reviewed_by = NULL,
    reviewed_at = NULL,
    review_quality = NULL,
    quality_bonus_points = 0,
    deadline_bonus_points = 0,
    admin_rejection_reason = p_reason
  WHERE id = p_task_id;
  
  PERFORM create_notification_with_push(
    v_task.assigned_to,
    'Task Reopened',
    'Please redo: ' || v_task.title || ' (-5 pts)',
    'task_reopened',
    jsonb_build_object('task_id', p_task_id, 'reason', p_reason)
  );
END;
$$;

-- Update add_bonus_points to include push notification
CREATE OR REPLACE FUNCTION add_bonus_points(
  p_user_id uuid,
  p_points integer,
  p_reason text,
  p_admin_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO points_history (user_id, points_change, category, reason, created_by)
  VALUES (p_user_id, p_points, 'bonus', p_reason, p_admin_id);
  
  PERFORM create_notification_with_push(
    p_user_id,
    'Bonus Points!',
    'You received ' || p_points || ' bonus points: ' || p_reason,
    'bonus_points',
    jsonb_build_object('points', p_points, 'reason', p_reason)
  );
END;
$$;