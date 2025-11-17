/*
  # Add Missing Notification Types
  
  1. Changes
    - Add fortune_wheel type
    - Add bonus type
    - These are used but were missing from constraint
*/

ALTER TABLE notifications
DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE notifications
ADD CONSTRAINT notifications_type_check
CHECK (type = ANY (ARRAY[
  'info', 'success', 'warning', 'error',
  'task', 'schedule', 'task_reopened', 'check_in',
  'task_completed', 'task_approved', 'task_assigned', 'task_rejected',
  'checkin_approved', 'checkin_late',
  'departure_approved', 'departure_rejected', 'departure_request',
  'points_earned', 'points_deducted',
  'checklist', 'patrol', 'patrol_missed', 'patrol_completed',
  'reception_note',
  'fortune_wheel', 'bonus'
]));
