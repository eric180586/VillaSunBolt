/*
  # Add Daily Checklist Generation Cron Job

  ## Problem:
  - generate_due_checklists() is never called automatically
  - Daily checklists are not being generated each day
  - Users don't see recurring checklists like "Again and Again"
  
  ## Solution:
  - Add a cron job that runs daily at 00:05 Cambodia time (17:05 UTC)
  - Calls generate_due_checklists() to create instances for daily/weekly/monthly checklists
*/

-- Schedule checklist generation daily at 00:05 Cambodia time (17:05 UTC)
-- First unschedule if exists
DO $$
BEGIN
  PERFORM cron.unschedule('generate-daily-checklists');
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END $$;

-- Schedule the job to run daily at 17:05 UTC (00:05 Cambodia time, UTC+7)
SELECT cron.schedule(
  'generate-daily-checklists',
  '5 17 * * *',
  'SELECT generate_due_checklists();'
);
