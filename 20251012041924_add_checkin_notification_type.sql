/*
  # Add check_in notification type

  1. Changes
    - Add 'check_in' to the allowed notification types
    - This enables check-in notifications to be created
*/

-- Drop the old constraint
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Add new constraint with check_in type included
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check 
CHECK (type = ANY (ARRAY['info'::text, 'success'::text, 'warning'::text, 'error'::text, 'task'::text, 'schedule'::text, 'check_in'::text]));
