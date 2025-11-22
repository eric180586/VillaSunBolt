/*
  # Create send_push_notification helper function
  
  This function calls the Edge Function to send push notifications.
  It reads the notification from the database and sends it to the user.
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
  v_supabase_url text;
  v_supabase_key text;
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

  -- Use the basic title and message (translations handled by client)
  v_title := v_notification.title;
  v_message := v_notification.message;

  -- Get Supabase URL and key from environment
  v_supabase_url := current_setting('app.supabase_url', true);
  v_supabase_key := current_setting('app.supabase_anon_key', true);

  -- Call Edge Function using pg_net extension
  -- Note: This requires pg_net extension to be enabled
  BEGIN
    PERFORM net.http_post(
      url := v_supabase_url || '/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_supabase_key
      ),
      body := jsonb_build_object(
        'user_ids', jsonb_build_array(p_user_id),
        'title', v_title,
        'body', v_message
      )
    );
  EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail the transaction
    RAISE WARNING 'Failed to send push notification: %', SQLERRM;
  END;
END;
$$;
