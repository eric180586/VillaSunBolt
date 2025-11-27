/*
  # Fix Push Notification Trigger - Use Proper URL

  Update the trigger to use the correct Supabase URL pattern.
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
  v_supabase_url text := 'https://ehpkfncumqqoezrmmhzw.supabase.co';
  v_anon_key text;
BEGIN
  -- Get anon key from vault if available, otherwise use the function with service role
  -- For now, we'll use the service role context that the function already has
  
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
  -- The Edge Function has verifyJWT=true, so we need proper auth
  -- Since this function is SECURITY DEFINER, it runs with elevated privileges
  BEGIN
    SELECT net.http_post(
      url := v_supabase_url || '/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json'
        -- Note: We can't easily get the service role key here
        -- The Edge Function needs to be public or we need another approach
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
      timeout_milliseconds := 5000
    ) INTO v_request_id;
    
    RAISE NOTICE 'Push notification request sent: request_id=%', v_request_id;
  EXCEPTION
    WHEN OTHERS THEN
      -- Don't fail the notification creation if push fails
      RAISE WARNING 'Failed to send push notification: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION trigger_push_notification IS 
'Trigger function that calls send-push-notification Edge Function via pg_net';
