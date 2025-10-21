/*
  # Setup pg_cron for automatic scheduled notifications
  
  ## What this does:
  1. Enable pg_cron extension (if not already enabled)
  2. Create a cron job that runs every 5 minutes
  3. Calls database functions directly to check for notifications
  
  ## How it works:
  - pg_cron runs inside the database
  - Every 5 minutes it calls our notification functions
  - The functions create notifications, which trigger push notifications
*/

-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Enable http extension for calling Edge Functions
CREATE EXTENSION IF NOT EXISTS http;

-- Create a wrapper function that calls both notification checks
CREATE OR REPLACE FUNCTION run_scheduled_notification_checks()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check for overdue patrols (5+ minutes late)
  DECLARE
    v_patrol record;
  BEGIN
    FOR v_patrol IN 
      SELECT id, assigned_to, date, time_slot
      FROM patrol_rounds
      WHERE completed_at IS NULL
      AND notification_sent = false
      AND scheduled_time IS NOT NULL
      AND scheduled_time <= now() - interval '5 minutes'
    LOOP
      -- Call notify function
      PERFORM notify_patrol_due(v_patrol.id);
      
      -- Mark as notified
      UPDATE patrol_rounds
      SET notification_sent = true
      WHERE id = v_patrol.id;
    END LOOP;
  END;
  
  -- Check for tasks approaching deadline
  PERFORM notify_task_deadline_approaching();
  
  RAISE NOTICE 'Scheduled notification checks completed at %', now();
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION run_scheduled_notification_checks() TO postgres;

-- Schedule the job to run every 5 minutes
-- First, try to unschedule if it exists (ignore error if it doesn't)
DO $$
BEGIN
  PERFORM cron.unschedule('check-scheduled-notifications');
EXCEPTION
  WHEN OTHERS THEN
    -- Job doesn't exist yet, that's okay
    NULL;
END $$;

-- Now schedule the job
SELECT cron.schedule(
  'check-scheduled-notifications',
  '*/5 * * * *',
  'SELECT run_scheduled_notification_checks();'
);