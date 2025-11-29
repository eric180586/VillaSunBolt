/*
  # Add Check-in Notification Types

  ## Problem:
  - notifications table only allows: info, success, warning, error, task, schedule
  - Need 'checkin_pending' for check-in approval requests
  
  ## Solution:
  - Drop old constraint
  - Add new constraint with check-in types
*/

-- Drop old constraint
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Add new constraint with check-in types
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check 
  CHECK (type IN (
    'info', 
    'success', 
    'warning', 
    'error', 
    'task', 
    'schedule',
    'checkin_pending',
    'checkin_approved',
    'checkin_rejected'
  ));

COMMENT ON CONSTRAINT notifications_type_check ON notifications IS 
'Allowed notification types including check-in status notifications';
