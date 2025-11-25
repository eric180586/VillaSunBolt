/*
  # Setup Cron Jobs for Deadline Notifications

  ## Cron Jobs to Schedule
  
  1. Task Deadline Approaching - Every 15 minutes
  2. Task Deadline Expired - Every hour
  3. Patrol Deadline Approaching - Every 5 minutes
  4. Patrol Deadline Expired - Every 15 minutes
  
  ## Note
  - Uses pg_cron extension (must be enabled)
  - All times in UTC (Supabase default)
  - Functions convert to Cambodia time internally
*/

-- Enable pg_cron if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ============================================================================
-- Remove old cron jobs if they exist
-- ============================================================================

DO $$
BEGIN
  -- Remove by jobname
  PERFORM cron.unschedule('check-task-deadlines-approaching');
  PERFORM cron.unschedule('check-task-deadlines-expired');
  PERFORM cron.unschedule('check-patrol-deadlines-approaching');
  PERFORM cron.unschedule('check-patrol-deadlines-expired');
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Some cron jobs did not exist, continuing...';
END $$;

-- ============================================================================
-- 1. Task Deadline Approaching - Every 15 minutes
-- ============================================================================

SELECT cron.schedule(
  'check-task-deadlines-approaching',
  '*/15 * * * *',  -- Every 15 minutes
  $$SELECT check_task_deadlines_approaching()$$
);

-- ============================================================================
-- 2. Task Deadline Expired - Every hour
-- ============================================================================

SELECT cron.schedule(
  'check-task-deadlines-expired',
  '0 * * * *',  -- Every hour at :00
  $$SELECT check_task_deadlines_expired()$$
);

-- ============================================================================
-- 3. Patrol Deadline Approaching - Every 5 minutes
-- ============================================================================

SELECT cron.schedule(
  'check-patrol-deadlines-approaching',
  '*/5 * * * *',  -- Every 5 minutes
  $$SELECT check_patrol_deadlines_approaching()$$
);

-- ============================================================================
-- 4. Patrol Deadline Expired - Every 15 minutes
-- ============================================================================

SELECT cron.schedule(
  'check-patrol-deadlines-expired',
  '*/15 * * * *',  -- Every 15 minutes
  $$SELECT check_patrol_deadlines_expired()$$
);

-- ============================================================================
-- Verify scheduled jobs
-- ============================================================================

-- Query to see all scheduled jobs:
-- SELECT * FROM cron.job ORDER BY jobname;

COMMENT ON EXTENSION pg_cron IS 
'Cron scheduler for deadline notifications: tasks and patrol rounds';
