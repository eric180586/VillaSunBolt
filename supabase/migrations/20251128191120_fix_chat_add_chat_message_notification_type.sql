/*
  # Fix Chat - Add chat_message to Notification Types
  
  Roger cannot send chat messages because the chat trigger creates
  notifications with type 'chat_message', but this type is missing
  from the notifications type CHECK constraint.
  
  Changes:
  - Add 'chat_message' to the allowed notification types
*/

-- Drop the old constraint
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Create new constraint with chat_message included
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
CHECK (type = ANY (ARRAY[
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
  'task_assigned',
  'task_rejected',
  'checkin_approved',
  'checkin_late',
  'departure_approved',
  'departure_rejected',
  'departure_request',
  'points_earned',
  'points_deducted',
  'checklist',
  'patrol',
  'patrol_missed',
  'patrol_completed',
  'reception_note',
  'fortune_wheel',
  'bonus',
  'time_off_request',
  'task_available',
  'task_deadline_approaching',
  'task_deadline_expired',
  'patrol_deadline_approaching',
  'patrol_deadline_expired',
  'chat_message'
]::text[]));

COMMENT ON CONSTRAINT notifications_type_check ON notifications IS 
'Ensures notification type is one of the allowed values including chat_message';
