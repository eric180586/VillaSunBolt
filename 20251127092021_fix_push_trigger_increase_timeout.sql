/*
  # Fix Push Notification Trigger - Increase Timeout

  The Edge Function times out after 5 seconds.
  Increase timeout to 15 seconds to allow for VAPID key issues.
*/

CREATE OR REPLACE FUNCTION trigger_push_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_request_id bigint;
  v_title text;
  v_message text;
  v_user_language text;
  v_supabase_url text := 'https://mvkupvgqtjgegaulaztx.supabase.co';
BEGIN
  -- Get user's preferred language
  SELECT preferred_language INTO v_user_language
  FROM profiles
  WHERE id = NEW.user_id;
  
  -- Default to English if not set
  v_user_language := COALESCE(v_user_language, 'en');
  
  -- Get title and message in user's language
  CASE v_user_language
    WHEN 'de' THEN
      v_title := COALESCE(NEW.title_de, NEW.title_en, NEW.title);
      v_message := COALESCE(NEW.message_de, NEW.message_en, NEW.message);
    WHEN 'km' THEN
      v_title := COALESCE(NEW.title_km, NEW.title_en, NEW.title);
      v_message := COALESCE(NEW.message_km, NEW.message_en, NEW.message);
    ELSE
      v_title := COALESCE(NEW.title_en, NEW.title);
      v_message := COALESCE(NEW.message_en, NEW.message);
  END CASE;

  -- Call the Edge Function using pg_net (async, non-blocking)
  -- Increased timeout to 15 seconds
  BEGIN
    SELECT net.http_post(
      url := v_supabase_url || '/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'user_ids', jsonb_build_array(NEW.user_id::text),
        'title', v_title,
        'body', v_message,
        'data', jsonb_build_object(
          'notification_id', NEW.id::text,
          'type', NEW.type
        )
      ),
      timeout_milliseconds := 15000  -- Increased from 5000 to 15000
    ) INTO v_request_id;
    
    RAISE NOTICE 'Push notification request sent: notification_id=%, request_id=%', NEW.id, v_request_id;
  EXCEPTION
    WHEN OTHERS THEN
      -- Don't fail the notification creation if push fails
      RAISE WARNING 'Failed to send push notification for %: %', NEW.id, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION trigger_push_notification IS 
'Trigger function that calls send-push-notification Edge Function via pg_net with 15s timeout';
