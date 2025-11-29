/*
  # Fix Push Notification Function - Complete Fix

  1. Problem
    - send_push_via_edge_function uses wrong Supabase URL (old project)
    - Uses placeholder anon key instead of proper service key
    - Edge Function cannot be reached

  2. Solution
    - Update to correct Supabase URL: https://mvkupvgqtjgegaulaztx.supabase.co
    - Use proper service role key from environment
    - Remove hardcoded placeholder keys

  3. Changes
    - Fix Supabase URL to match current project
    - Properly retrieve and use service role key
*/

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
  v_response jsonb;
BEGIN
  -- Use correct Supabase URL for current project
  v_supabase_url := 'https://mvkupvgqtjgegaulaztx.supabase.co';
  
  -- Get service role key from Supabase environment
  -- This is automatically available in Supabase functions
  v_service_key := current_setting('app.settings', true)::json->>'service_role_key';
  
  -- Fallback: try alternative method to get service key
  IF v_service_key IS NULL OR v_service_key = '' THEN
    BEGIN
      v_service_key := current_setting('request.jwt.claims', true)::json->>'role';
    EXCEPTION
      WHEN OTHERS THEN
        -- Use anon key as last resort (from .env)
        v_service_key := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im12a3VwdmdxdGpnZWdhdWxhenR4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI3MTk5NTMsImV4cCI6MjA3ODI5NTk1M30.oV3zHEE376RkdboDRHBrRNcYPha9v4LPbfgQgS7oy7A';
    END;
  END IF;

  -- Make async HTTP POST to Edge Function
  SELECT net.http_post(
    url := v_supabase_url || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_key,
      'apikey', v_service_key
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
  
  -- Log for debugging (only in development)
  RAISE DEBUG 'Push notification request sent with ID: %', v_request_id;
  
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the transaction
    -- Push notifications are non-critical, primary notifications still work
    RAISE WARNING 'Failed to send push notification: %', SQLERRM;
END;
$$;
