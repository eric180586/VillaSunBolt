/*
  # Backfill translations for existing notifications
  
  1. Changes
    - Add all missing notification types to the type constraint
    - Update all existing notifications with their translations
    - Use notification_translations table to lookup translations by type
  
  2. Notes
    - Old notifications don't have title_de, title_en, title_km filled
    - This causes users to see wrong language notifications
*/

-- First, expand the type constraint to include all notification types
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE notifications ADD CONSTRAINT notifications_type_check 
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
  'points_earned'::text,
  'points_deducted'::text,
  'checklist'::text, 
  'patrol'::text, 
  'patrol_missed'::text, 
  'patrol_completed'::text, 
  'reception_note'::text, 
  'departure_request'::text
]));

-- Now backfill all existing notifications
UPDATE notifications n
SET 
  title_de = COALESCE(n.title_de, nt.title_de, n.title),
  title_en = COALESCE(n.title_en, nt.title_en, n.title),
  title_km = COALESCE(n.title_km, nt.title_km, n.title),
  message_de = COALESCE(n.message_de, nt.message_template_de, n.message),
  message_en = COALESCE(n.message_en, nt.message_template_en, n.message),
  message_km = COALESCE(n.message_km, nt.message_template_km, n.message)
FROM notification_translations nt
WHERE nt.key = n.type
  AND (n.title_de IS NULL OR n.title_en IS NULL OR n.title_km IS NULL);

-- For notifications without translation entries, use the title/message as fallback
UPDATE notifications
SET 
  title_de = COALESCE(title_de, title),
  title_en = COALESCE(title_en, title),
  title_km = COALESCE(title_km, title),
  message_de = COALESCE(message_de, message),
  message_en = COALESCE(message_en, message),
  message_km = COALESCE(message_km, message)
WHERE title_de IS NULL OR title_en IS NULL OR title_km IS NULL;
