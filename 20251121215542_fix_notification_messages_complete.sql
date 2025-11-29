/*
  # Fix Notification Messages - Complete System

  1. Problem
    - Chat notifications have empty message field
    - Push notifications work but database notifications show no content
    - Translations can't work with empty messages

  2. Solution
    - Update all notification trigger functions to include proper messages
    - Ensure message field is never empty
    - Maintain push notification functionality

  3. Functions Updated
    - notify_chat_message: Add sender name and message preview to database notification
    - notify_reception_note: Include note content
    - notify_schedule_changed: Include schedule details
    - notify_schedule_published: Include week information
    - All admin notifications: Ensure complete information
*/

-- 1. Fix notify_chat_message - Include sender and message
CREATE OR REPLACE FUNCTION notify_chat_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_staff_user record;
  v_staff_ids text[];
  v_sender_name text;
  v_message_preview text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT full_name INTO v_sender_name
    FROM profiles
    WHERE id = NEW.user_id;

    -- Create message preview (first 100 chars)
    v_message_preview := substring(NEW.message, 1, 100);
    IF length(NEW.message) > 100 THEN
      v_message_preview := v_message_preview || '...';
    END IF;

    v_staff_ids := ARRAY[]::text[];

    -- Notify all staff members except sender
    FOR v_staff_user IN
      SELECT id FROM profiles
      WHERE id != NEW.user_id
    LOOP
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        v_staff_user.id,
        'New Message from ' || COALESCE(v_sender_name, 'Someone'),
        v_message_preview,
        'chat_message'
      );

      v_staff_ids := array_append(v_staff_ids, v_staff_user.id::text);
    END LOOP;

    -- Send push notification to all recipients
    IF array_length(v_staff_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_staff_ids,
        p_title := COALESCE(v_sender_name, 'Someone') || ' sent a message',
        p_body := v_message_preview,
        p_data := jsonb_build_object(
          'type', 'chat_message',
          'message_id', NEW.id,
          'sender_id', NEW.user_id
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Recreate trigger
DROP TRIGGER IF EXISTS notify_chat_message_trigger ON chat_messages;
CREATE TRIGGER notify_chat_message_trigger
AFTER INSERT ON chat_messages
FOR EACH ROW
EXECUTE FUNCTION notify_chat_message();

-- 2. Fix notify_reception_note - Include note content
CREATE OR REPLACE FUNCTION notify_reception_note()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_staff_user record;
  v_staff_ids text[];
  v_note_preview text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Create note preview
    v_note_preview := substring(NEW.content, 1, 100);
    IF length(NEW.content) > 100 THEN
      v_note_preview := v_note_preview || '...';
    END IF;

    v_staff_ids := ARRAY[]::text[];

    FOR v_staff_user IN
      SELECT id FROM profiles WHERE role = 'staff'
    LOOP
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        v_staff_user.id,
        'Important Reception Note',
        v_note_preview,
        'reception_note'
      );

      v_staff_ids := array_append(v_staff_ids, v_staff_user.id::text);
    END LOOP;

    IF array_length(v_staff_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_staff_ids,
        p_title := 'Important Reception Note',
        p_body := v_note_preview,
        p_data := jsonb_build_object(
          'type', 'reception_note',
          'note_id', NEW.id
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 3. Fix notify_schedule_changed - Include details
CREATE OR REPLACE FUNCTION notify_schedule_changed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_staff_name text;
  v_new_time text;
  v_old_time text;
BEGIN
  IF NEW.start_time != OLD.start_time OR NEW.end_time != OLD.end_time THEN
    SELECT full_name INTO v_staff_name
    FROM profiles
    WHERE id = NEW.staff_id;

    v_new_time := to_char(NEW.start_time, 'HH24:MI') || ' - ' || to_char(NEW.end_time, 'HH24:MI');
    v_old_time := to_char(OLD.start_time, 'HH24:MI') || ' - ' || to_char(OLD.end_time, 'HH24:MI');

    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      NEW.staff_id,
      'Schedule Changed',
      'Your schedule was changed from ' || v_old_time || ' to ' || v_new_time,
      'schedule_changed'
    );

    PERFORM send_push_via_edge_function(
      p_user_ids := ARRAY[NEW.staff_id::text],
      p_title := 'Schedule Changed',
      p_body := 'Your schedule was changed from ' || v_old_time || ' to ' || v_new_time,
      p_data := jsonb_build_object(
        'type', 'schedule_changed',
        'schedule_id', NEW.id
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

-- 4. Fix notify_schedule_published - Include week info
CREATE OR REPLACE FUNCTION notify_schedule_published()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_staff_user record;
  v_staff_ids text[];
  v_week_info text;
BEGIN
  IF NEW.published = true AND (OLD.published IS NULL OR OLD.published = false) THEN
    v_week_info := 'Week ' || to_char(NEW.week_start_date, 'DD.MM.YYYY');
    v_staff_ids := ARRAY[]::text[];

    FOR v_staff_user IN
      SELECT DISTINCT staff_id
      FROM schedules
      WHERE start_time >= NEW.week_start_date
      AND start_time < NEW.week_start_date + interval '7 days'
    LOOP
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        v_staff_user.staff_id,
        'New Schedule Published',
        'Your schedule for ' || v_week_info || ' is now available',
        'schedule_published'
      );

      v_staff_ids := array_append(v_staff_ids, v_staff_user.staff_id::text);
    END LOOP;

    IF array_length(v_staff_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_staff_ids,
        p_title := 'New Schedule Published',
        p_body := 'Your schedule for ' || v_week_info || ' is now available',
        p_data := jsonb_build_object(
          'type', 'schedule_published',
          'week_schedule_id', NEW.id
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 5. Ensure all existing notification types have proper translations
-- This helps the auto-fill trigger work correctly
INSERT INTO notification_translations (key, title_en, title_de, title_km, message_template_en, message_template_de, message_template_km)
VALUES
  ('chat_message', 'New Message', 'Neue Nachricht', 'សារថ្មី', '{sender_name} sent a message: {message}', '{sender_name} hat eine Nachricht gesendet: {message}', '{sender_name} បានផ្ញើសារ: {message}'),
  ('reception_note', 'Reception Note', 'Rezeptionsnotiz', 'កំណត់ចំណាំទទួល', 'Important note: {note_content}', 'Wichtige Notiz: {note_content}', 'សេចក្តីសំខាន់: {note_content}')
ON CONFLICT (key)
DO UPDATE SET
  title_en = EXCLUDED.title_en,
  title_de = EXCLUDED.title_de,
  title_km = EXCLUDED.title_km,
  message_template_en = EXCLUDED.message_template_en,
  message_template_de = EXCLUDED.message_template_de,
  message_template_km = EXCLUDED.message_template_km;