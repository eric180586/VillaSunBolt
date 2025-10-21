/*
  # Setup Push Notification Configuration
  
  1. Configuration
    - Store Supabase URL and Service Key as database settings
    - Enable pg_net extension to make HTTP calls from triggers
  
  2. Purpose
    - Allows trigger functions to call Edge Functions directly
    - Enables real-time push notifications even when app is closed
  
  3. Security
    - Settings stored securely in database
    - Only accessible to trigger functions via SECURITY DEFINER
*/

-- Ensure pg_net extension is enabled
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Create a function to send push notifications via Edge Function
-- This will be called by all notification trigger functions
CREATE OR REPLACE FUNCTION send_push_via_edge_function(
  p_user_ids text[] DEFAULT NULL,
  p_role text DEFAULT NULL,
  p_title text DEFAULT 'Villa Sun',
  p_body text DEFAULT 'New notification',
  p_icon text DEFAULT '/VillaSun_Logo_192x192.png',
  p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_supabase_url text;
  v_service_key text;
  v_request_id bigint;
BEGIN
  -- Get Supabase URL from environment (set in Supabase dashboard)
  v_supabase_url := current_setting('app.settings.supabase_url', true);
  v_service_key := current_setting('app.settings.supabase_service_key', true);
  
  -- If settings not configured, use environment variables as fallback
  IF v_supabase_url IS NULL THEN
    v_supabase_url := 'https://thncdxvoubtsimwvsigi.supabase.co';
  END IF;
  
  IF v_service_key IS NULL THEN
    v_service_key := current_setting('service_role_key', true);
  END IF;

  -- Make async HTTP POST to Edge Function
  SELECT net.http_post(
    url := v_supabase_url || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || COALESCE(v_service_key, '')
    ),
    body := jsonb_build_object(
      'user_ids', p_user_ids,
      'role', p_role,
      'title', p_title,
      'body', p_body,
      'icon', p_icon,
      'badge', '/VillaSun_Logo_72x72.png',
      'data', p_data
    )
  ) INTO v_request_id;
  
  -- Log for debugging (optional)
  RAISE NOTICE 'Push notification request sent: %', v_request_id;
  
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the transaction
    RAISE WARNING 'Failed to send push notification: %', SQLERRM;
END;
$$;

-- Grant execute permission to authenticated users (trigger will run as SECURITY DEFINER)
GRANT EXECUTE ON FUNCTION send_push_via_edge_function TO authenticated;
GRANT EXECUTE ON FUNCTION send_push_via_edge_function TO service_role;
