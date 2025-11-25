/*
  # Complete ALL Notification Translations
  
  ## Missing Notification Types to Add
  1. task_available - New unassigned task broadcast
  2. task_deadline_approaching - Task deadline warning
  3. task_deadline_expired - Task overdue alert
  4. time_off_request - Vacation/time-off request
  5. patrol_deadline_approaching - Patrol reminder
  6. patrol_deadline_expired - Patrol missed
  7. patrol_missed - Patrol penalty
  8. patrol_completed - Patrol finished
  9. task_reopened - Task sent back for revision
  10. task_completed - Task finished by staff
  11. checklist - Checklist notifications
  12. fortune_wheel - Fortune wheel bonus
  13. bonus - Manual bonus points
  14. check_in - Check-in notifications
  
  ## All translations in DE/EN/KM
*/

-- ============================================================================
-- Insert/Update ALL notification translations
-- ============================================================================

INSERT INTO notification_translations (key, title_de, title_en, title_km, message_template_de, message_template_en, message_template_km)
VALUES 
  -- NEW: Task Available (Broadcast)
  ('task_available', 
   'Neue Aufgabe verfügbar', 
   'New Task Available', 
   'កិច្ចការថ្មីមាន',
   'Neue Aufgabe verfügbar: {task_title}',
   'New task available: {task_title}',
   'កិច្ចការថ្មីមាន: {task_title}'),

  -- NEW: Task Deadline Approaching
  ('task_deadline_approaching',
   'Deadline naht',
   'Deadline Approaching',
   'ថ្ងៃផុតកំណត់ខិតជិតមកដល់',
   'Deadline für "{task_title}" naht! Verbleibende Zeit: {time_remaining}',
   'Deadline for "{task_title}" is approaching! Time remaining: {time_remaining}',
   'ថ្ងៃផុតកំណត់សម្រាប់ "{task_title}" ខិតជិតមកដល់! ពេលវេលានៅសល់: {time_remaining}'),

  -- NEW: Task Deadline Expired
  ('task_deadline_expired',
   'Deadline abgelaufen',
   'Deadline Expired',
   'ថ្ងៃផុតកំណត់ផុតពេល',
   'Deadline für "{task_title}" ist abgelaufen!',
   'Deadline for "{task_title}" has expired!',
   'ថ្ងៃផុតកំណត់សម្រាប់ "{task_title}" ផុតពេលហើយ!'),

  -- NEW: Time-Off Request
  ('time_off_request',
   'Urlaubsantrag',
   'Time-Off Request',
   'សំណើឈប់សម្រាក',
   '{staff_name} beantragt Urlaub: {dates}',
   '{staff_name} requests time off: {dates}',
   '{staff_name} សុំឈប់សម្រាក: {dates}'),

  -- NEW: Patrol Deadline Approaching
  ('patrol_deadline_approaching',
   'Patrouille fällig',
   'Patrol Due',
   'ការល៉មដែកដល់ពេល',
   'Patrouille um {time} Uhr fällig!',
   'Patrol round at {time} is due!',
   'ការល៉មដែកនៅ {time} ដល់ពេលហើយ!'),

  -- NEW: Patrol Deadline Expired
  ('patrol_deadline_expired',
   'Patrouille verpasst',
   'Patrol Missed',
   'ការល៉មដែកខកខាន',
   'Patrouille um {time} Uhr wurde verpasst!',
   'Patrol round at {time} was missed!',
   'ការល៉មដែកនៅ {time} ខកខានហើយ!'),

  -- Patrol Missed (Penalty)
  ('patrol_missed',
   'Patrouille verpasst',
   'Patrol Missed',
   'ការល៉មដែកខកខាន',
   'Du hast die Patrouille verpasst. -1 Punkt Strafe',
   'You missed the patrol round. -1 point penalty',
   'អ្នកខកខានការល៉មដែក។ ពិន័យ -1 ពិន្ទុ'),

  -- Patrol Completed
  ('patrol_completed',
   'Patrouille abgeschlossen',
   'Patrol Completed',
   'ការល៉មដែកបានបញ្ចប់',
   'Patrouille erfolgreich abgeschlossen! +{points} Punkte',
   'Patrol completed successfully! +{points} points',
   'ការល៉មដែកបានបញ្ចប់ដោយជោគជ័យ! +{points} ពិន្ទុ'),

  -- Task Reopened
  ('task_reopened',
   'Aufgabe zur Überarbeitung',
   'Task Reopened',
   'កិច្ចការត្រូវបានបើកឡើងវិញ',
   'Bitte überarbeite: "{task_title}". {admin_notes}',
   'Please revise: "{task_title}". {admin_notes}',
   'សូមពិនិត្យឡើងវិញ: "{task_title}"។ {admin_notes}'),

  -- Task Completed (Staff finished)
  ('task_completed',
   'Aufgabe erledigt',
   'Task Completed',
   'កិច្ចការបានបញ្ចប់',
   '"{task_title}" wurde zur Überprüfung eingereicht',
   '"{task_title}" has been submitted for review',
   '"{task_title}" ត្រូវបានដាក់ស្នើសម្រាប់ពិនិត្យ'),

  -- Checklist
  ('checklist',
   'Checkliste',
   'Checklist',
   'បញ្ជីពិនិត្យ',
   'Checkliste: {checklist_name}',
   'Checklist: {checklist_name}',
   'បញ្ជីពិនិត្យ: {checklist_name}'),

  -- Fortune Wheel
  ('fortune_wheel',
   'Glücksrad',
   'Fortune Wheel',
   'កង់វាសនា',
   'Du hast {points} Punkte im Glücksrad gewonnen!',
   'You won {points} points from the Fortune Wheel!',
   'អ្នកឈ្នះបាន {points} ពិន្ទុពីកង់វាសនា!'),

  -- Bonus Points
  ('bonus',
   'Bonus Punkte',
   'Bonus Points',
   'ពិន្ទុបន្ថែម',
   'Du hast {points} Bonus-Punkte erhalten!',
   'You received {points} bonus points!',
   'អ្នកបានទទួល {points} ពិន្ទុបន្ថែម!'),

  -- Check-In
  ('check_in',
   'Check-In',
   'Check-In',
   'ការចុះឈ្មោះ',
   'Check-In erfolgreich: {message}',
   'Check-in successful: {message}',
   'ការចុះឈ្មោះជោគជ័យ: {message}')

ON CONFLICT (key) 
DO UPDATE SET
  title_de = EXCLUDED.title_de,
  title_en = EXCLUDED.title_en,
  title_km = EXCLUDED.title_km,
  message_template_de = EXCLUDED.message_template_de,
  message_template_en = EXCLUDED.message_template_en,
  message_template_km = EXCLUDED.message_template_km;

-- ============================================================================
-- Verify all translations are complete
-- ============================================================================

DO $$
DECLARE
  v_missing integer;
BEGIN
  SELECT COUNT(*) INTO v_missing
  FROM notification_translations
  WHERE title_de IS NULL 
     OR title_en IS NULL 
     OR title_km IS NULL
     OR message_template_de IS NULL
     OR message_template_en IS NULL
     OR message_template_km IS NULL;
  
  IF v_missing > 0 THEN
    RAISE NOTICE 'WARNING: % notification translations are incomplete!', v_missing;
  ELSE
    RAISE NOTICE 'SUCCESS: All notification translations are complete!';
  END IF;
END $$;

COMMENT ON TABLE notification_translations IS 
'Complete translations for all notification types in German, English, and Khmer';
