/*
  # Add duration_minutes to tasks table

  1. Changes
    - Add duration_minutes column to tasks table with default 30 minutes
    - Set realistic defaults based on task priority for existing tasks
    - Add helpful comment explaining the field's purpose

  2. Reasoning
    - Tasks need duration estimates for accurate daily time calculations
    - Different priorities typically require different time investments:
      * Urgent tasks: 60 minutes (complex, time-sensitive)
      * High priority: 45 minutes (important, needs attention)
      * Medium priority: 30 minutes (standard task)
      * Low priority: 15 minutes (quick tasks)
    - Matches checklist_instances structure for consistency
    - Enables accurate ProgressBar time estimation display

  3. Security
    - No RLS changes needed (inherits existing tasks table policies)
*/

-- Add duration_minutes column to tasks table
ALTER TABLE tasks
ADD COLUMN IF NOT EXISTS duration_minutes integer DEFAULT 30;

-- Add helpful comment explaining the field
COMMENT ON COLUMN tasks.duration_minutes IS
  'Estimated duration in minutes for completing this task. Used for daily time calculations in the dashboard. Default: 30 minutes.';

-- Set realistic defaults based on priority for existing tasks
UPDATE tasks
SET duration_minutes = CASE
  WHEN priority = 'urgent' THEN 60
  WHEN priority = 'high' THEN 45
  WHEN priority = 'medium' THEN 30
  WHEN priority = 'low' THEN 15
  ELSE 30
END
WHERE duration_minutes IS NULL OR duration_minutes = 30;