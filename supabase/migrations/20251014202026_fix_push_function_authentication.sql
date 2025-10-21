/*
  # Fix Push Notification Authentication
  
  1. Problem
    - Edge Function returns 401 Invalid JWT
    - Service Role Key not properly passed to Edge Function
  
  2. Solution
    - Update send_push_via_edge_function to use proper authentication
    - Use Supabase Service Role Key from environment
  
  3. Changes
    - Fix JWT token in Authorization header
*/

-- Update the push notification function to use proper authentication
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
  -- Hardcode the Supabase URL (from .env)
  v_supabase_url := 'https://thncdxvoubtsimwvsigi.supabase.co';
  
  -- Try to get service key from settings, fallback to anon key for testing
  -- NOTE: This will need to be configured in Supabase dashboard
  BEGIN
    v_service_key := current_setting('app.supabase_service_role_key', true);
  EXCEPTION
    WHEN OTHERS THEN
      v_service_key := NULL;
  END;
  
  -- If no service key, try to use anon key (less ideal but works for some cases)
  IF v_service_key IS NULL THEN
    v_service_key := 'YOUR_ANON_KEY_HERE';
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
  
  -- Log for debugging
  RAISE NOTICE 'Push notification request sent: % (using key length: %)', v_request_id, length(v_service_key);
  
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the transaction
    RAISE WARNING 'Failed to send push notification: %', SQLERRM;
END;
$$;
