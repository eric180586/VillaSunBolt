/*
  # Add missing notification translations
  
  1. Changes
    - Add translations for all notification types that are missing
    - Covers: info, success, warning, error, task, schedule, patrol
  
  2. Languages
    - German (de)
    - English (en)
    - Khmer (km)
*/

INSERT INTO notification_translations (key, title_de, title_en, title_km, message_template_de, message_template_en, message_template_km)
VALUES
  -- General notification types
  ('info', 'Information', 'Information', 'ព័ត៌មាន', '{message}', '{message}', '{message}'),
  ('success', 'Erfolg', 'Success', 'ជោគជ័យ', '{message}', '{message}', '{message}'),
  ('warning', 'Warnung', 'Warning', 'ការព្រមាន', '{message}', '{message}', '{message}'),
  ('error', 'Fehler', 'Error', 'កំហុស', '{message}', '{message}', '{message}'),
  
  -- Task notifications
  ('task', 'Aufgabe', 'Task', 'កិច្ចការ', '{message}', '{message}', '{message}'),
  
  -- Schedule notifications
  ('schedule', 'Dienstplan', 'Schedule', 'កាលវិភាគ', '{message}', '{message}', '{message}'),
  
  -- Patrol notifications
  ('patrol', 'Rundgang', 'Patrol', 'ការល្បាត', '{message}', '{message}', '{message}')
ON CONFLICT (key) DO UPDATE SET
  title_de = EXCLUDED.title_de,
  title_en = EXCLUDED.title_en,
  title_km = EXCLUDED.title_km,
  message_template_de = EXCLUDED.message_template_de,
  message_template_en = EXCLUDED.message_template_en,
  message_template_km = EXCLUDED.message_template_km;

-- Now re-run the backfill for all notifications
UPDATE notifications n
SET 
  title_de = nt.title_de,
  title_en = nt.title_en,
  title_km = nt.title_km,
  message_de = nt.message_template_de,
  message_en = nt.message_template_en,
  message_km = nt.message_template_km
FROM notification_translations nt
WHERE nt.key = n.type;
