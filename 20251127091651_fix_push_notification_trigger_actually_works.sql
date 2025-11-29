/*
  # Fix Push Notification Trigger - Actually Send Push!

  ## THE PROBLEM:
  The trigger_push_notification() function does NOTHING - it just updates
  created_at with the same value. The Edge Function is NEVER called!

  ## THE FIX:
  Use pg_net.http_post to call the send-push-notification Edge Function
  when a new notification is created.
*/

-- Drop the broken trigger first
DROP TRIGGER IF EXISTS push_notification_trigger ON notifications;

-- Create a working trigger function that actually calls the Edge Function
CREATE OR REPLACE FUNCTION trigger_push_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_supabase_url text;
  v_service_role_key text;
  v_request_id bigint;
  v_title text;
  v_message text;
  v_user_language text;
BEGIN
  -- Get Supabase URL and Service Role Key from environment
  v_supabase_url := current_setting('app.settings.supabase_url', true);
  v_service_role_key := current_setting('app.settings.service_role_key', true);
  
  -- If not set in config, use default patterns
  IF v_supabase_url IS NULL THEN
    v_supabase_url := 'https://' || current_setting('request.headers', true)::json->>'host';
  END IF;

  -- Get user's preferred language
  SELECT preferred_language INTO v_user_language
  FROM profiles
  WHERE id = NEW.user_id;
  
  -- Default to English if not set
  v_user_language := COALESCE(v_user_language, 'en');
  
  -- Get title and message in user's language
  CASE v_user_language
    WHEN 'de' THEN
      v_title := COALESCE(NEW.title_de, NEW.title_en);
      v_message := COALESCE(NEW.message_de, NEW.message_en);
    WHEN 'km' THEN
      v_title := COALESCE(NEW.title_km, NEW.title_en);
      v_message := COALESCE(NEW.message_km, NEW.message_en);
    ELSE
      v_title := NEW.title_en;
      v_message := NEW.message_en;
  END CASE;

  -- Call the Edge Function using pg_net
  -- Note: This is async, so it won't block the notification creation
  SELECT net.http_post(
    url := v_supabase_url || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || COALESCE(v_service_role_key, '')
    ),
    body := jsonb_build_object(
      'user_ids', jsonb_build_array(NEW.user_id::text),
      'title', v_title,
      'body', v_message,
      'data', jsonb_build_object(
        'notification_id', NEW.id::text,
        'type', NEW.type
      )
    )
  ) INTO v_request_id;

  -- Log the request (optional, for debugging)
  RAISE NOTICE 'Push notification request sent for notification % (request_id: %)', NEW.id, v_request_id;

  RETURN NEW;
END;
$$;

-- Recreate the trigger
CREATE TRIGGER push_notification_trigger
  AFTER INSERT ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION trigger_push_notification();

COMMENT ON FUNCTION trigger_push_notification IS 
'Trigger function that calls the send-push-notification Edge Function using pg_net';
