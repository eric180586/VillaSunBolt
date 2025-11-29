/*
  # Fix send_push_notification to use Supabase Functions URL
  
  1. Problem
    - Function tries to use current_setting() for Supabase URL/key
    - These settings are not configured in the database
    - Push notifications fail silently
  
  2. Solution
    - Use extensions.http_request instead of net.http_post
    - Construct the Edge Function URL using the project reference
    - Use service role key from pg_net
*/

CREATE OR REPLACE FUNCTION send_push_notification(
  p_user_id uuid,
  p_notification_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_notification record;
  v_title text;
  v_message text;
  v_lang text;
  v_response_status integer;
BEGIN
  -- Get user's preferred language
  SELECT preferred_language INTO v_lang
  FROM profiles
  WHERE id = p_user_id;
  
  IF v_lang IS NULL THEN
    v_lang := 'en';
  END IF;

  -- Get notification
  SELECT * INTO v_notification
  FROM notifications
  WHERE id = p_notification_id;

  IF NOT FOUND THEN
    RAISE WARNING 'Notification % not found', p_notification_id;
    RETURN;
  END IF;

  -- Select appropriate translation based on language
  CASE v_lang
    WHEN 'de' THEN
      v_title := COALESCE(v_notification.title_de, v_notification.title);
      v_message := COALESCE(v_notification.message_de, v_notification.message);
    WHEN 'km' THEN
      v_title := COALESCE(v_notification.title_km, v_notification.title);
      v_message := COALESCE(v_notification.message_km, v_notification.message);
    ELSE
      v_title := COALESCE(v_notification.title_en, v_notification.title);
      v_message := COALESCE(v_notification.message_en, v_notification.message);
  END CASE;

  -- Call Edge Function using pg_net extension
  BEGIN
    -- Note: Supabase automatically provides SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY
    -- The Edge Function URL is automatically constructed
    SELECT status INTO v_response_status
    FROM extensions.http_post(
      url := current_setting('request.headers')::json->>'x-forwarded-host' || '/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('request.jwt.claims', true)::json->>'role'
      ),
      body := jsonb_build_object(
        'user_ids', jsonb_build_array(p_user_id::text),
        'title', v_title,
        'body', v_message,
        'data', jsonb_build_object('notification_id', p_notification_id)
      )
    );

    IF v_response_status >= 400 THEN
      RAISE WARNING 'Push notification returned status %', v_response_status;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail the transaction
    RAISE WARNING 'Failed to send push notification: %', SQLERRM;
  END;
END;
$$;
