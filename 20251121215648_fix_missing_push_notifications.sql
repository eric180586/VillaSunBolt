/*
  # Fix Missing Push Notifications

  1. Problem
    - notify_task_assignment has no push integration
    - notify_admin_departure_request uses old 'priority' field
    - notify_departure_approved uses old 'priority' field

  2. Solution
    - Remove 'priority' field from all INSERT INTO notifications
    - Add push notification integration to notify_task_assignment
    - Ensure all notification functions have proper push integration

  3. Functions Updated
    - notify_task_assignment: Add push notifications
    - notify_admin_departure_request: Remove priority field, verify push integration
    - notify_departure_approved: Remove priority field, verify push integration
*/

-- 1. Fix notify_task_assignment - Add push notifications
CREATE OR REPLACE FUNCTION notify_task_assignment()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_assigned_name text;
  v_task_title text;
BEGIN
  -- Only send notification for non-template tasks with assigned user
  IF NEW.is_template = false AND NEW.assigned_to IS NOT NULL THEN
    -- Get user's name
    SELECT full_name INTO v_assigned_name
    FROM profiles
    WHERE id = NEW.assigned_to;

    v_task_title := NEW.title;

    -- Create in-app notification
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message
    ) VALUES (
      NEW.assigned_to,
      'task_assigned',
      'New Task Assigned',
      'You have been assigned: "' || v_task_title || '"'
    );

    -- Send push notification
    PERFORM send_push_via_edge_function(
      p_user_ids := ARRAY[NEW.assigned_to::text],
      p_title := 'New Task Assigned',
      p_body := 'You have been assigned: "' || v_task_title || '"',
      p_data := jsonb_build_object(
        'type', 'task_assigned',
        'task_id', NEW.id
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- Recreate trigger
DROP TRIGGER IF EXISTS trigger_notify_new_task ON tasks;
CREATE TRIGGER trigger_notify_new_task
AFTER INSERT ON tasks
FOR EACH ROW
EXECUTE FUNCTION notify_task_assignment();

-- 2. Fix notify_admin_departure_request - Remove priority field
CREATE OR REPLACE FUNCTION notify_admin_departure_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin record;
  v_staff_name text;
  v_admin_ids text[];
  v_reason_text text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Get staff member's name
    SELECT full_name INTO v_staff_name
    FROM profiles
    WHERE id = NEW.user_id;

    v_reason_text := COALESCE(NEW.reason, 'No reason provided');
    v_admin_ids := ARRAY[]::text[];

    -- Create notification for each admin
    FOR v_admin IN 
      SELECT id FROM profiles WHERE role = 'admin'
    LOOP
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        v_admin.id,
        'Departure Request',
        COALESCE(v_staff_name, 'Staff') || ' requests to leave early: ' || v_reason_text,
        'admin_departure_request'
      );
      
      v_admin_ids := array_append(v_admin_ids, v_admin.id::text);
    END LOOP;

    -- Send push notification to all admins
    IF array_length(v_admin_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_admin_ids,
        p_title := 'Departure Request',
        p_body := COALESCE(v_staff_name, 'Staff') || ' requests to leave early',
        p_data := jsonb_build_object(
          'type', 'admin_departure_request',
          'request_id', NEW.id
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Recreate trigger
DROP TRIGGER IF EXISTS notify_admin_departure_request_trigger ON departure_requests;
CREATE TRIGGER notify_admin_departure_request_trigger
AFTER INSERT ON departure_requests
FOR EACH ROW
EXECUTE FUNCTION notify_admin_departure_request();

-- 3. Fix notify_departure_approved - Remove priority field
CREATE OR REPLACE FUNCTION notify_departure_approved()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status = 'pending') THEN
    -- Create in-app notification
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      NEW.user_id,
      'Go Go',
      'Dtow Dtow :)',
      'departure_approved'
    );

    -- Send push notification
    PERFORM send_push_via_edge_function(
      p_user_ids := ARRAY[NEW.user_id::text],
      p_title := 'Go Go',
      p_body := 'Dtow Dtow :)',
      p_data := jsonb_build_object(
        'type', 'departure_approved',
        'request_id', NEW.id
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Recreate trigger
DROP TRIGGER IF EXISTS notify_departure_approved_trigger ON departure_requests;
CREATE TRIGGER notify_departure_approved_trigger
AFTER UPDATE ON departure_requests
FOR EACH ROW
EXECUTE FUNCTION notify_departure_approved();

-- 4. Add notification translation for task_assigned
INSERT INTO notification_translations (key, title_en, title_de, title_km, message_template_en, message_template_de, message_template_km)
VALUES
  ('task_assigned', 'New Task', 'Neue Aufgabe', 'កិច្ចការថ្មី', 'You have been assigned: {task_title}', 'Dir wurde zugewiesen: {task_title}', 'អ្នកត្រូវបានចាត់តាំង: {task_title}'),
  ('admin_departure_request', 'Departure Request', 'Feierabend-Anfrage', 'សំណើចាកចេញ', '{staff_name} requests to leave early: {reason}', '{staff_name} möchte früher gehen: {reason}', '{staff_name} សុំចាកចេញមុន: {reason}'),
  ('departure_approved', 'Approved', 'Genehmigt', 'បានអនុម័ត', 'Your departure request has been approved', 'Deine Feierabend-Anfrage wurde genehmigt', 'សំណើចាកចេញរបស់អ្នកត្រូវបានអនុម័ត')
ON CONFLICT (key)
DO UPDATE SET
  title_en = EXCLUDED.title_en,
  title_de = EXCLUDED.title_de,
  title_km = EXCLUDED.title_km,
  message_template_en = EXCLUDED.message_template_en,
  message_template_de = EXCLUDED.message_template_de,
  message_template_km = EXCLUDED.message_template_km;