/*
  # Add Missing Notification Types

  ## Problem
  - notifications_type_check constraint doesn't include new notification types
  - Missing: time_off_request, task_available, task_deadline_approaching, 
    task_deadline_expired, patrol_deadline_approaching, patrol_deadline_expired

  ## Solution
  - Drop old constraint
  - Create new constraint with all notification types
*/

-- Drop old constraint
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Create new constraint with ALL notification types
ALTER TABLE notifications
ADD CONSTRAINT notifications_type_check
CHECK (type = ANY (ARRAY[
  'info'::text,
  'success'::text,
  'warning'::text,
  'error'::text,
  'task'::text,
  'schedule'::text,
  'task_reopened'::text,
  'check_in'::text,
  'task_completed'::text,
  'task_approved'::text,
  'task_assigned'::text,
  'task_rejected'::text,
  'checkin_approved'::text,
  'checkin_late'::text,
  'departure_approved'::text,
  'departure_rejected'::text,
  'departure_request'::text,
  'points_earned'::text,
  'points_deducted'::text,
  'checklist'::text,
  'patrol'::text,
  'patrol_missed'::text,
  'patrol_completed'::text,
  'reception_note'::text,
  'fortune_wheel'::text,
  'bonus'::text,
  -- NEW TYPES:
  'time_off_request'::text,
  'task_available'::text,
  'task_deadline_approaching'::text,
  'task_deadline_expired'::text,
  'patrol_deadline_approaching'::text,
  'patrol_deadline_expired'::text
]));

COMMENT ON CONSTRAINT notifications_type_check ON notifications IS 
'Allowed notification types including all new deadline and time-off types';
