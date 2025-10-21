/*
  # Update All Notification Triggers to Send Push Notifications
  
  1. Updates
    - All 11 notification trigger functions now call Edge Function
    - Sends real-time push notifications via send_push_via_edge_function()
  
  2. Functions Updated
    - notify_admin_checkin
    - notify_admin_checklist_completed
    - notify_admin_departure_request
    - notify_admin_task_pending_review
    - notify_chat_message
    - notify_departure_approved
    - notify_new_checklist
    - notify_new_task
    - notify_reception_note
    - notify_schedule_changed
    - notify_schedule_published
  
  3. Behavior
    - Creates database notification (for history)
    - Sends push notification via Edge Function (for real-time alerts)
    - Works even when app is closed
*/

-- 1. notify_admin_checkin - Staff checks in
CREATE OR REPLACE FUNCTION notify_admin_checkin()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin record;
  v_staff_name text;
  v_admin_ids text[];
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT full_name INTO v_staff_name
    FROM profiles
    WHERE id = NEW.user_id;

    v_admin_ids := ARRAY[]::text[];

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
      
      v_admin_ids := array_append(v_admin_ids, v_admin.id::text);
    END LOOP;

    -- Send push notification to all admins
    IF array_length(v_admin_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_admin_ids,
        p_title := 'Staff Check-In',
        p_body := COALESCE(v_staff_name, 'Staff') || ' has checked in',
        p_data := jsonb_build_object('type', 'admin_checkin')
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 2. notify_admin_checklist_completed - Checklist completed
CREATE OR REPLACE FUNCTION notify_admin_checklist_completed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin record;
  v_admin_ids text[];
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    v_admin_ids := ARRAY[]::text[];

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
      
      v_admin_ids := array_append(v_admin_ids, v_admin.id::text);
    END LOOP;

    IF array_length(v_admin_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_admin_ids,
        p_title := 'Checklist Completed',
        p_body := 'A checklist has been completed and needs review',
        p_data := jsonb_build_object('type', 'admin_checklist_review')
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 3. notify_admin_departure_request - Staff requests to leave early
CREATE OR REPLACE FUNCTION notify_admin_departure_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin record;
  v_staff_name text;
  v_admin_ids text[];
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT full_name INTO v_staff_name
    FROM profiles
    WHERE id = NEW.user_id;

    v_admin_ids := ARRAY[]::text[];

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
      
      v_admin_ids := array_append(v_admin_ids, v_admin.id::text);
    END LOOP;

    IF array_length(v_admin_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_admin_ids,
        p_title := 'Departure Request',
        p_body := COALESCE(v_staff_name, 'Staff') || ' requests to leave early',
        p_data := jsonb_build_object('type', 'admin_departure_request')
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 4. notify_admin_task_pending_review - Task completed and needs review
CREATE OR REPLACE FUNCTION notify_admin_task_pending_review()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin record;
  v_staff_name text;
  v_admin_ids text[];
BEGIN
  IF NEW.status = 'pending_review' AND (OLD.status IS NULL OR OLD.status != 'pending_review') THEN
    SELECT full_name INTO v_staff_name
    FROM profiles
    WHERE id = NEW.assigned_to;

    v_admin_ids := ARRAY[]::text[];

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
      
      v_admin_ids := array_append(v_admin_ids, v_admin.id::text);
    END LOOP;

    IF array_length(v_admin_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_admin_ids,
        p_title := 'Task Completed',
        p_body := COALESCE(v_staff_name, 'Staff') || ' marked task as completed',
        p_data := jsonb_build_object('type', 'admin_task_review')
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 5. notify_chat_message - New chat message
CREATE OR REPLACE FUNCTION notify_chat_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_staff_user record;
  v_staff_ids text[];
  v_sender_name text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT full_name INTO v_sender_name
    FROM profiles
    WHERE id = NEW.user_id;

    v_staff_ids := ARRAY[]::text[];

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
      
      v_staff_ids := array_append(v_staff_ids, v_staff_user.id::text);
    END LOOP;

    IF array_length(v_staff_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_staff_ids,
        p_title := 'New Message',
        p_body := COALESCE(v_sender_name, 'Someone') || ' sent a message',
        p_data := jsonb_build_object('type', 'chat_message')
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 6. notify_departure_approved - Departure request approved
CREATE OR REPLACE FUNCTION notify_departure_approved()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status = 'pending') THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      NEW.user_id,
      'Go Go',
      'Dtow Dtow :)',
      'departure_approved'
    );

    PERFORM send_push_via_edge_function(
      p_user_ids := ARRAY[NEW.user_id::text],
      p_title := 'Go Go',
      p_body := 'Dtow Dtow :)',
      p_data := jsonb_build_object('type', 'departure_approved')
    );
  END IF;

  RETURN NEW;
END;
$$;

-- 7. notify_new_checklist - New checklist assigned
CREATE OR REPLACE FUNCTION notify_new_checklist()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_staff_user record;
  v_staff_ids text[];
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_staff_ids := ARRAY[]::text[];

    FOR v_staff_user IN 
      SELECT DISTINCT s.staff_id
      FROM schedules s
      WHERE s.start_time <= now()
      AND s.end_time >= now()
      AND s.staff_id IS NOT NULL
    LOOP
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        v_staff_user.staff_id,
        'Busy?',
        'Next To Do :)',
        'new_checklist'
      );
      
      v_staff_ids := array_append(v_staff_ids, v_staff_user.staff_id::text);
    END LOOP;

    IF array_length(v_staff_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_staff_ids,
        p_title := 'Busy?',
        p_body := 'Next To Do :)',
        p_data := jsonb_build_object('type', 'new_checklist')
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 8. notify_new_task - New task created
CREATE OR REPLACE FUNCTION notify_new_task()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_staff_user record;
  v_staff_ids text[];
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_staff_ids := ARRAY[]::text[];

    IF NEW.assigned_to IS NOT NULL THEN
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        NEW.assigned_to,
        'Busy?',
        'Next To Do :)',
        'task'
      );
      
      v_staff_ids := ARRAY[NEW.assigned_to::text];
    ELSE
      FOR v_staff_user IN 
        SELECT id
        FROM profiles
        WHERE role = 'staff'
      LOOP
        INSERT INTO notifications (user_id, title, message, type)
        VALUES (
          v_staff_user.id,
          'Busy?',
          'Next To Do :)',
          'task'
        );
        
        v_staff_ids := array_append(v_staff_ids, v_staff_user.id::text);
      END LOOP;
    END IF;

    IF array_length(v_staff_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_staff_ids,
        p_title := 'Busy?',
        p_body := 'Next To Do :)',
        p_data := jsonb_build_object('type', 'task')
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 9. notify_reception_note - Important reception note
CREATE OR REPLACE FUNCTION notify_reception_note()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_staff_user record;
  v_staff_ids text[];
BEGIN
  IF NEW.category != 'reception' THEN
    RETURN NEW;
  END IF;

  v_staff_ids := ARRAY[]::text[];

  FOR v_staff_user IN 
    SELECT id FROM profiles 
    WHERE role = 'staff' 
    AND id != NEW.created_by
  LOOP
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_staff_user.id,
      'Important Info',
      NEW.title,
      'reception_note'
    );
    
    v_staff_ids := array_append(v_staff_ids, v_staff_user.id::text);
  END LOOP;

  IF array_length(v_staff_ids, 1) > 0 THEN
    PERFORM send_push_via_edge_function(
      p_user_ids := v_staff_ids,
      p_title := 'Important Info',
      p_body := NEW.title,
      p_data := jsonb_build_object('type', 'reception_note')
    );
  END IF;

  RETURN NEW;
END;
$$;

-- 10. notify_schedule_changed - Schedule time changed
CREATE OR REPLACE FUNCTION notify_schedule_changed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF OLD.start_time != NEW.start_time OR OLD.end_time != NEW.end_time THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      NEW.staff_id,
      'New Shift',
      'Pls check',
      'schedule_changed'
    );

    PERFORM send_push_via_edge_function(
      p_user_ids := ARRAY[NEW.staff_id::text],
      p_title := 'New Shift',
      p_body := 'Pls check',
      p_data := jsonb_build_object('type', 'schedule_changed')
    );
  END IF;

  RETURN NEW;
END;
$$;

-- 11. notify_schedule_published - New weekly schedule published
CREATE OR REPLACE FUNCTION notify_schedule_published()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_staff_user record;
  v_staff_ids text[];
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_staff_ids := ARRAY[]::text[];

    FOR v_staff_user IN 
      SELECT id FROM profiles WHERE role = 'staff'
    LOOP
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        v_staff_user.id,
        'Next week',
        'Day off or not? Find out now :)',
        'schedule_published'
      );
      
      v_staff_ids := array_append(v_staff_ids, v_staff_user.id::text);
    END LOOP;

    IF array_length(v_staff_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_staff_ids,
        p_title := 'Next week',
        p_body := 'Day off or not? Find out now :)',
        p_data := jsonb_build_object('type', 'schedule_published')
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
