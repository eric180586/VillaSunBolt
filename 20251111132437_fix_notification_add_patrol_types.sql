/*
  # Add patrol notification types

  1. Changes
    - Update notifications type constraint to include patrol-related types
    - Uses 'patrol' (generic) instead of 'patrol_missed'

  2. Security
    - No RLS changes needed
*/

-- Drop the old constraint
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Add new constraint with all existing types plus patrol types
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
CHECK (type IN (
  'info',
  'success',
  'warning',
  'error',
  'task',
  'schedule',
  'task_reopened',
  'check_in',
  'task_completed',
  'task_approved',
  'checklist',
  'patrol',
  'patrol_missed',
  'patrol_completed',
  'reception_note',
  'departure_request'
));