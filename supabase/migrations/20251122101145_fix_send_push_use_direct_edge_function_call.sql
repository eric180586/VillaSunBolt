/*
  # Fix send_push_notification to call Edge Function directly
  
  1. Problem
    - Previous version tried to use request context which is not available
    - Push notifications don't work
  
  2. Solution
    - Use pg_net.http_post with hardcoded Supabase URL
    - Use service role for authentication
    - Make async call (fire and forget)
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
  v_request_id bigint;
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

  -- Call Edge Function using pg_net extension (async)
  -- Note: Project URL is mvkupvgqtjgegaulaztx.supabase.co
  BEGIN
    SELECT INTO v_request_id net.http_post(
      url := 'https://mvkupvgqtjgegaulaztx.supabase.co/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im12a3VwdmdxdGpnZWdhdWxhenR4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI3MTk5NTMsImV4cCI6MjA3ODI5NTk1M30.oV3zHEE376RkdboDRHBrRNcYPha9v4LPbfgQgS7oy7A'
      ),
      body := jsonb_build_object(
        'user_ids', jsonb_build_array(p_user_id::text),
        'title', v_title,
        'body', v_message,
        'data', jsonb_build_object(
          'notification_id', p_notification_id::text,
          'type', v_notification.type
        )
      )
    );
    
    -- Log the request ID for debugging
    RAISE NOTICE 'Push notification request sent with ID: %', v_request_id;
  EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail the transaction
    RAISE WARNING 'Failed to send push notification: %', SQLERRM;
  END;
END;
$$;

COMMENT ON FUNCTION send_push_notification IS 
'Sends a push notification to a user by calling the Edge Function. 
Uses pg_net for async HTTP calls to avoid blocking the main transaction.';
