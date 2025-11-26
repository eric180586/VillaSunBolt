/*
  # Fix Notification Triggers - Missing title and message

  ## Problem
  - notify_task_created_broadcast() creates notifications without title/message
  - These columns are NOT NULL, causing INSERT to fail
  - Error: "null value in column "title" of relation "notifications" violates not-null constraint"

  ## Solution
  - Add title and message to all notification inserts
  - Use German as default for backwards compatibility
  - Keep language-specific columns for translations

  ## Affected Functions
  - notify_task_created_broadcast()
  - Any other notification functions missing title/message
*/

-- Fix notify_task_created_broadcast to include title and message
CREATE OR REPLACE FUNCTION notify_task_created_broadcast()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_staff_user record;
  v_staff_ids text[];
BEGIN
  -- Broadcast to all staff when a new task is created (not assigned yet)
  IF NEW.is_template = false AND NEW.assigned_to IS NULL THEN
    v_staff_ids := ARRAY[]::text[];

    FOR v_staff_user IN
      SELECT id FROM profiles WHERE role = 'staff'
    LOOP
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
        v_staff_user.id,
        'task_available',
        'Neue Aufgabe verfügbar',  -- Default title (German for backwards compat)
        'Neue Aufgabe verfügbar',
        'New Task Available',
        'កិច្ចការថ្មីមាន',
        'Neue Aufgabe verfügbar: "' || NEW.title || '"',  -- Default message
        'Neue Aufgabe verfügbar: "' || NEW.title || '"',
        'New task available: "' || NEW.title || '"',
        'កិច្ចការថ្មីមាន: "' || NEW.title || '"'
      );

      v_staff_ids := array_append(v_staff_ids, v_staff_user.id::text);
    END LOOP;

    -- Send push to all staff
    IF array_length(v_staff_ids, 1) > 0 THEN
      BEGIN
        PERFORM send_push_via_edge_function(
          p_user_ids := v_staff_ids,
          p_title := 'New Task Available',
          p_body := 'New task available: "' || NEW.title || '"',
          p_data := jsonb_build_object(
            'type', 'task_available',
            'task_id', NEW.id
          )
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Push notification failed: %', SQLERRM;
      END;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION notify_task_created_broadcast IS 
'FIXED: Now includes title and message columns to satisfy NOT NULL constraints';
