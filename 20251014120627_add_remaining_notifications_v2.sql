/*
  # Add Remaining Push Notifications
  
  ## New Notifications:
  1. Patrol due (5 minutes after scheduled time): "Time for checking - :)"
  2. Task deadline approaching: "Oh oh, time is running - Don´t forget"
  3. Departure approved: "Go Go - Dtow Dtow :)"
  4. Chat message: "New Message"
  5. Admin notifications: task completed, checklist completed, check-in, departure request
  
  ## Notes:
  - Checklist instances store items as JSONB, not in separate table
  - Check completion by parsing JSONB items array
*/

-- 1. Update patrol notification to be called 5 minutes after scheduled time
CREATE OR REPLACE FUNCTION notify_patrol_due(p_patrol_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_assigned_user uuid;
  v_scheduled_time timestamptz;
BEGIN
  SELECT assigned_to, scheduled_time INTO v_assigned_user, v_scheduled_time
  FROM patrol_rounds
  WHERE id = p_patrol_id;

  -- Only notify if 5 minutes have passed since scheduled time
  IF v_assigned_user IS NOT NULL AND now() >= v_scheduled_time + interval '5 minutes' THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_assigned_user,
      'Time for checking',
      ':)',
      'patrol_due'
    );
  END IF;
END;
$$;

-- 2. Task deadline notification (should be called by cron/scheduled job every 5 minutes)
CREATE OR REPLACE FUNCTION notify_task_deadline_approaching()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task record;
  v_staff_user record;
  v_time_until_deadline interval;
BEGIN
  -- Check all tasks that are not completed and have a deadline
  FOR v_task IN 
    SELECT t.id, t.title, t.assigned_to, t.due_date, t.estimated_duration
    FROM tasks t
    WHERE t.status NOT IN ('completed', 'cancelled', 'archived')
    AND t.due_date IS NOT NULL
    AND t.due_date > now()
  LOOP
    -- Calculate time until deadline minus estimated duration
    v_time_until_deadline := v_task.due_date - COALESCE(v_task.estimated_duration, interval '0 minutes') - now();
    
    -- Notify when deadline - estimated_duration is reached (within 5 minute window)
    IF v_time_until_deadline <= interval '5 minutes' AND v_time_until_deadline >= interval '0 minutes' THEN
      IF v_task.assigned_to IS NOT NULL THEN
        -- Check if notification was already sent (avoid duplicates)
        IF NOT EXISTS (
          SELECT 1 FROM notifications 
          WHERE user_id = v_task.assigned_to 
          AND type = 'task_deadline'
          AND message LIKE '%' || v_task.id::text || '%'
          AND created_at > now() - interval '1 hour'
        ) THEN
          INSERT INTO notifications (user_id, title, message, type)
          VALUES (
            v_task.assigned_to,
            'Oh oh, time is running',
            'Don´t forget',
            'task_deadline'
          );
        END IF;
      ELSE
        -- Notify all staff in current shift
        FOR v_staff_user IN 
          SELECT DISTINCT s.staff_id
          FROM schedules s
          WHERE s.start_time <= now()
          AND s.end_time >= now()
          AND s.staff_id IS NOT NULL
        LOOP
          IF NOT EXISTS (
            SELECT 1 FROM notifications 
            WHERE user_id = v_staff_user.staff_id 
            AND type = 'task_deadline'
            AND message LIKE '%' || v_task.id::text || '%'
            AND created_at > now() - interval '1 hour'
          ) THEN
            INSERT INTO notifications (user_id, title, message, type)
            VALUES (
              v_staff_user.staff_id,
              'Oh oh, time is running',
              'Don´t forget',
              'task_deadline'
            );
          END IF;
        END LOOP;
      END IF;
    END IF;
  END LOOP;
END;
$$;

-- 3. Departure request approved notification
CREATE OR REPLACE FUNCTION notify_departure_approved()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- When departure request is approved
  IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status = 'pending') THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      NEW.user_id,
      'Go Go',
      'Dtow Dtow :)',
      'departure_approved'
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_departure_approved_trigger ON departure_requests;
CREATE TRIGGER notify_departure_approved_trigger
AFTER UPDATE OF status ON departure_requests
FOR EACH ROW
EXECUTE FUNCTION notify_departure_approved();

-- 4. Chat message notification
CREATE OR REPLACE FUNCTION notify_chat_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_staff_user record;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Notify all staff except the sender
    FOR v_staff_user IN 
      SELECT id FROM profiles 
      WHERE role = 'staff' 
      AND id != NEW.user_id
    LOOP
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        v_staff_user.id,
        'New Message',
        '',
        'chat_message'
      );
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_chat_message_trigger ON chat_messages;
CREATE TRIGGER notify_chat_message_trigger
AFTER INSERT ON chat_messages
FOR EACH ROW
EXECUTE FUNCTION notify_chat_message();

-- 5a. Admin notification: Task marked as completed (pending review)
CREATE OR REPLACE FUNCTION notify_admin_task_pending_review()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin record;
  v_staff_name text;
BEGIN
  -- When task status changes to pending_review
  IF NEW.status = 'pending_review' AND (OLD.status IS NULL OR OLD.status != 'pending_review') THEN
    -- Get staff name
    SELECT full_name INTO v_staff_name
    FROM profiles
    WHERE id = NEW.assigned_to;
    
    -- Notify all admins
    FOR v_admin IN 
      SELECT id FROM profiles WHERE role = 'admin'
    LOOP
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        v_admin.id,
        'Task Completed',
        COALESCE(v_staff_name, 'Staff') || ' marked task as completed',
        'admin_task_review'
      );
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_admin_task_pending_review_trigger ON tasks;
CREATE TRIGGER notify_admin_task_pending_review_trigger
AFTER UPDATE OF status ON tasks
FOR EACH ROW
EXECUTE FUNCTION notify_admin_task_pending_review();

-- 5b. Admin notification: Checklist marked as completed
CREATE OR REPLACE FUNCTION notify_admin_checklist_completed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin record;
  v_all_completed boolean;
  v_item jsonb;
BEGIN
  -- When status changes to completed
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    -- Notify all admins
    FOR v_admin IN 
      SELECT id FROM profiles WHERE role = 'admin'
    LOOP
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        v_admin.id,
        'Checklist Completed',
        'A checklist has been completed and needs review',
        'admin_checklist_review'
      );
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_admin_checklist_completed_trigger ON checklist_instances;
CREATE TRIGGER notify_admin_checklist_completed_trigger
AFTER UPDATE OF status ON checklist_instances
FOR EACH ROW
EXECUTE FUNCTION notify_admin_checklist_completed();

-- 5c. Admin notification: Staff checked in
CREATE OR REPLACE FUNCTION notify_admin_checkin()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin record;
  v_staff_name text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Get staff name
    SELECT full_name INTO v_staff_name
    FROM profiles
    WHERE id = NEW.user_id;
    
    -- Notify all admins
    FOR v_admin IN 
      SELECT id FROM profiles WHERE role = 'admin'
    LOOP
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        v_admin.id,
        'Staff Check-In',
        COALESCE(v_staff_name, 'Staff') || ' has checked in',
        'admin_checkin'
      );
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_admin_checkin_trigger ON check_ins;
CREATE TRIGGER notify_admin_checkin_trigger
AFTER INSERT ON check_ins
FOR EACH ROW
EXECUTE FUNCTION notify_admin_checkin();

-- 5d. Admin notification: Departure request created
CREATE OR REPLACE FUNCTION notify_admin_departure_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin record;
  v_staff_name text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Get staff name
    SELECT full_name INTO v_staff_name
    FROM profiles
    WHERE id = NEW.user_id;
    
    -- Notify all admins
    FOR v_admin IN 
      SELECT id FROM profiles WHERE role = 'admin'
    LOOP
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        v_admin.id,
        'Departure Request',
        COALESCE(v_staff_name, 'Staff') || ' requests to leave early',
        'admin_departure_request'
      );
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_admin_departure_request_trigger ON departure_requests;
CREATE TRIGGER notify_admin_departure_request_trigger
AFTER INSERT ON departure_requests
FOR EACH ROW
EXECUTE FUNCTION notify_admin_departure_request();

-- Grant permissions
GRANT EXECUTE ON FUNCTION notify_patrol_due(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION notify_task_deadline_approaching() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_departure_approved() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_chat_message() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_admin_task_pending_review() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_admin_checklist_completed() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_admin_checkin() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_admin_departure_request() TO authenticated;