/*
  # Fix Notifications Type Constraint
  
  1. Changes
    - Add 'task_reopened' to allowed notification types
    - This is needed for the reopen_task_with_penalty function
  
  2. Security
    - Maintains existing RLS policies
*/

-- Drop existing constraint
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Add new constraint with task_reopened included
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
  CHECK (type IN ('info', 'success', 'warning', 'error', 'task', 'schedule', 'task_reopened', 'check_in', 'task_completed', 'task_approved', 'checklist', 'patrol', 'reception_note', 'departure_request'));
