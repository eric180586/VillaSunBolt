/*
  # Fix Reception Note Notification Type

  ## Problem:
  - Trigger notify_reception_note() uses 'reception_note' as notification type
  - But this type is not in the notifications_type_check constraint
  - This prevents creating reception notes
  
  ## Solution:
  - Add 'reception_note' to the allowed notification types
*/

-- Drop the old constraint
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Add the new constraint with 'reception_note' included
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
CHECK (type = ANY (ARRAY[
  'info'::text,
  'success'::text,
  'warning'::text,
  'error'::text,
  'task'::text,
  'schedule'::text,
  'check_in'::text,
  'patrol_due'::text,
  'task_deadline'::text,
  'departure_approved'::text,
  'chat_message'::text,
  'admin_task_review'::text,
  'admin_checklist_review'::text,
  'admin_checkin'::text,
  'admin_departure_request'::text,
  'reception_note'::text
]));
