# 🚀 MIGRATIONS ANWENDUNGS-GUIDE
## Villa Sun App - Konsolidierte Migrations

**Status:** PRODUKTIONSBEREIT
**Estimated Time:** 75 Minuten (alle 5 Phasen)
**Oder:** 30 Minuten (nur Phase 1+2 für sofortigen Betrieb)

---

## ⚠️ VOR DEM START

### 1. Backup erstellen
```
Supabase Dashboard → Database → Backups → Create Backup
```

### 2. Prüfe aktuelle Datenbankversion
```sql
SELECT * FROM supabase_migrations.schema_migrations
ORDER BY version DESC LIMIT 10;
```

---

## 📋 PHASE 1: CRITICAL FOUNDATION (20 Min)

### Dateien anzuwenden (in dieser Reihenfolge):

```bash
# Via Supabase Dashboard SQL Editor:

# 1. Shopping List
supabase/migrations/20251012015837_create_shopping_list_table.sql

# 2. Notes Admin Permissions
supabase/migrations/20251012014059_update_notes_admin_permissions.sql

# 3. Dynamic Points System
supabase/migrations/20251012050504_create_dynamic_points_system.sql

# 4. Task Approval System
supabase/migrations/20251012050610_update_task_approval_with_deadline_bonus_and_reopen_penalty.sql

# 5. Checklist Admin Approval
supabase/migrations/20251012231041_add_checklist_admin_approval_system.sql

# 6. Check-in System
supabase/migrations/20251011143526_update_checkin_approval_system.sql
supabase/migrations/20251014084822_fix_checkin_points_award_correctly.sql

# 7. Patrol Rounds
supabase/migrations/20251012023157_create_patrol_rounds_system.sql

# 8. How-To Documents
supabase/migrations/20251012231815_create_how_to_documents_system.sql
```

### ✅ Test nach Phase 1:

```sql
-- 1. Prüfe ob RPC-Funktionen existieren
SELECT routine_name FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN (
  'approve_task_with_points',
  'reopen_task_with_penalty',
  'approve_checklist_instance',
  'reject_checklist_instance',
  'process_check_in',
  'approve_check_in',
  'reject_check_in'
);
-- Erwartung: 7 Zeilen

-- 2. Prüfe Tabellen
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
  'shopping_items',
  'daily_point_goals',
  'patrol_locations',
  'patrol_schedules',
  'patrol_rounds',
  'patrol_scans',
  'how_to_documents'
);
-- Erwartung: 7 Zeilen

-- 3. Prüfe Task-Spalten
SELECT column_name FROM information_schema.columns
WHERE table_name = 'tasks'
AND column_name IN ('deadline_bonus_awarded', 'initial_points_value', 'secondary_assigned_to');
-- Erwartung: 3 Zeilen

-- 4. Prüfe Checklist-Spalten
SELECT column_name FROM information_schema.columns
WHERE table_name = 'checklist_instances'
AND column_name IN ('admin_reviewed', 'admin_approved');
-- Erwartung: 2 Zeilen
```

**✅ Wenn alle Tests erfolgreich:** Weiter zu Phase 2
**❌ Wenn Tests fehlschlagen:** Stopp! Debug vor Fortsetzung

---

## 📋 PHASE 2: FINAL POINTS SYSTEM (10 Min)

⚠️ **WICHTIG:** Diese Migration überschreibt alle vorherigen Point-Calculation Funktionen!

### Datei anzuwenden:

```bash
supabase/migrations/20251017120000_FINAL_APPROVED_points_calculation_system.sql
```

### ✅ Test nach Phase 2:

```sql
-- 1. Test Individual Points Calculation
SELECT calculate_daily_achievable_points(
  '<user_id>'::uuid,
  CURRENT_DATE
);
-- Sollte: Integer zurückgeben

-- 2. Test Team Points Calculation
SELECT calculate_team_achievable_points(CURRENT_DATE);
-- Sollte: Integer zurückgeben

-- 3. Test Monthly Progress
SELECT calculate_monthly_progress('<user_id>'::uuid);
-- Sollte: JSONB mit "percentage" key zurückgeben

-- 4. Prüfe ob Unassigned Tasks korrekt berechnet werden
-- Erstelle Test-Task:
INSERT INTO tasks (title, points_value, due_date, status, created_by)
VALUES ('Test Unassigned', 10, CURRENT_DATE, 'pending', auth.uid())
RETURNING id;

-- Prüfe ob ALLE Staff-User diese Punkte sehen:
SELECT
  p.full_name,
  calculate_daily_achievable_points(p.id, CURRENT_DATE) as achievable
FROM profiles p
WHERE p.role = 'staff';
-- Erwartung: Alle haben +10 Punkte mehr

-- Cleanup:
DELETE FROM tasks WHERE title = 'Test Unassigned';
```

---

## 📋 PHASE 3: EXTENDED FEATURES (15 Min)

### Dateien anzuwenden:

```bash
# Team Chat
supabase/migrations/20251012233216_create_team_chat_system.sql

# Fortune Wheel
supabase/migrations/20251013003610_create_fortune_wheel_system.sql
supabase/migrations/20251016185223_fix_fortune_wheel_bonus_points_actually_work.sql

# Quiz System
supabase/migrations/20251015001121_add_quiz_highscores_table.sql

# Tutorial System
supabase/migrations/20251017140000_create_tutorial_slides_system.sql
supabase/migrations/20251018140000_create_complete_room_cleaning_tutorial.sql

# Performance Tracking
supabase/migrations/20251013064839_add_daily_task_counts.sql
supabase/migrations/20251013064951_add_user_daily_task_counts.sql
supabase/migrations/20251013073207_create_team_daily_totals_table.sql
```

### ✅ Test nach Phase 3:

```sql
-- Prüfe neue Tabellen
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
  'chat_messages',
  'fortune_wheel_results',
  'quiz_highscores',
  'tutorial_categories',
  'tutorial_slides',
  'team_daily_totals'
);
-- Erwartung: 6 Zeilen

-- Prüfe add_bonus_points Funktion
SELECT routine_name FROM information_schema.routines
WHERE routine_name = 'add_bonus_points';
-- Erwartung: 1 Zeile

-- Prüfe Storage Buckets
SELECT name FROM storage.buckets
WHERE name IN ('chat-photos', 'tutorial-images');
-- Erwartung: 2 Zeilen
```

---

## 📋 PHASE 4: ADMIN PERMISSIONS (10 Min)

### Dateien anzuwenden:

```bash
# Profile Management
supabase/migrations/20251014131257_fix_profile_insert_policy_for_admin_creation.sql
supabase/migrations/20251014132249_fix_profile_insert_for_trigger_v3.sql
supabase/migrations/20251014132305_fix_trigger_bypass_rls.sql
supabase/migrations/20251014132358_fix_circular_dependency_profiles_policies.sql

# Admin Full Access
supabase/migrations/20251014124613_add_full_admin_permissions_correct.sql
supabase/migrations/20251014131702_fix_all_admin_permissions_complete.sql

# Schedule Visibility
supabase/migrations/20251013100000_fix_staff_schedule_visibility.sql

# Admin Edit Profiles
supabase/migrations/20251012112538_fix_admin_can_edit_all_profiles.sql
```

### ✅ Test nach Phase 4:

Als Admin einloggen und testen:

```sql
-- 1. Admin kann alle Profiles sehen
SELECT id, full_name, role FROM profiles;
-- Sollte: Alle User zurückgeben

-- 2. Admin kann Profile anderer User bearbeiten
UPDATE profiles
SET full_name = 'Test Name'
WHERE id = '<staff_user_id>';
-- Sollte: Erfolgreich sein

-- Rollback test:
UPDATE profiles
SET full_name = '<original_name>'
WHERE id = '<staff_user_id>';

-- 3. Staff kann alle Schedules sehen
-- Als Staff-User einloggen:
SELECT * FROM schedules;
-- Sollte: Alle Schedules zurückgeben
```

---

## 📋 PHASE 5: OPTIMIZATIONS & FIXES (20 Min)

### Notification System (8 Migrations):

```bash
supabase/migrations/20251014085026_create_push_notifications_system.sql
supabase/migrations/20251014085242_add_reception_note_notifications.sql
supabase/migrations/20251014120627_add_remaining_notifications_v2.sql
supabase/migrations/20251014121002_add_notification_sent_to_patrol_rounds_v2.sql
supabase/migrations/20251014201121_update_all_triggers_with_push_notifications.sql
supabase/migrations/20251014201213_update_scheduled_notification_functions_with_push.sql
supabase/migrations/20251014152342_fix_notify_new_task_type.sql
supabase/migrations/20251014153848_fix_all_invalid_notification_types.sql
```

### Photo Systems (6 Migrations):

```bash
supabase/migrations/20251014024140_add_explanation_photo_to_tasks.sql
supabase/migrations/20251014025803_restructure_photo_system_tasks.sql
supabase/migrations/20251014025821_restructure_photo_system_checklists.sql
supabase/migrations/20251014222018_create_task_photos_bucket.sql
supabase/migrations/20251013061316_create_admin_reviews_bucket.sql
supabase/migrations/20251013040532_create_checklist_explanations_bucket.sql
```

### Checklist Improvements (12 Migrations):

```bash
supabase/migrations/20251012202941_add_checklist_auto_generation_and_points.sql
supabase/migrations/20251012212409_fix_checklists_oneTime_and_add_duration.sql
supabase/migrations/20251012220317_add_photo_requirement_to_checklists.sql
supabase/migrations/20251012231041_add_checklist_admin_approval_system.sql
supabase/migrations/20251013025650_update_checklist_instances_from_template.sql
supabase/migrations/20251013035320_add_admin_photo_to_checklist_instances.sql
supabase/migrations/20251013035348_update_checklist_approval_with_admin_photo.sql
supabase/migrations/20251013040353_add_explanation_photo_to_checklists.sql
supabase/migrations/20251013061113_add_checklist_creation_trigger.sql
supabase/migrations/20251013073054_fix_approve_checklist_function_conflict.sql
supabase/migrations/20251014150417_fix_admin_can_create_tasks_and_checklists.sql
supabase/migrations/20251014154642_fix_staff_checklist_update_policy.sql
```

### Check-in Improvements (8 Migrations):

```bash
supabase/migrations/20251012041256_update_checkin_auto_detect_shift.sql
supabase/migrations/20251012041924_add_checkin_notification_type.sql
supabase/migrations/20251012043910_fix_checkin_approval_and_points_display.sql
supabase/migrations/20251012195932_fix_timezone_to_cambodia.sql
supabase/migrations/20251013143202_add_checkout_to_checkins_and_integrate_departure.sql
supabase/migrations/20251014133748_add_late_reason_to_checkins.sql
supabase/migrations/20251014141101_fix_process_checkin_sql_error.sql
supabase/migrations/20251014143150_fix_prevent_duplicate_checkin_same_day.sql
```

### Timezone & Scheduling (5 Migrations):

```bash
supabase/migrations/20251012043103_add_preferred_language_to_profiles.sql
supabase/migrations/20251012070902_fix_sunday_week_calculation.sql
supabase/migrations/20251012195932_fix_timezone_to_cambodia.sql
supabase/migrations/20251015202505_add_daily_checklist_generation_cron.sql
supabase/migrations/20251014121940_setup_pg_cron_for_notifications_v2.sql
```

### Archive & Cleanup (4 Migrations):

```bash
supabase/migrations/20251012094656_add_archived_status_to_tasks.sql
supabase/migrations/20251012112448_create_reset_all_points_function.sql
supabase/migrations/20251012122043_fix_reset_all_points_rls_safe.sql
supabase/migrations/20251019053001_fix_task_archival_automatic_cleanup_v2.sql
```

### ✅ Final Test nach Phase 5:

```sql
-- 1. Zähle alle Tabellen
SELECT COUNT(*) FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
-- Erwartung: ~30 Tabellen

-- 2. Zähle alle RPC-Funktionen
SELECT COUNT(*) FROM information_schema.routines
WHERE routine_schema = 'public';
-- Erwartung: ~20 Funktionen

-- 3. Zähle alle Storage Buckets
SELECT COUNT(*) FROM storage.buckets;
-- Erwartung: ~8 Buckets

-- 4. Prüfe Push Notifications Config
SELECT * FROM notifications LIMIT 1;
-- Sollte: Funktionieren

-- 5. Prüfe Timezone (sollte Kambodscha sein)
SHOW timezone;
-- Erwartung: Asia/Phnom_Penh oder UTC+7
```

---

## 🎯 SCHNELL-START (NUR KRITISCHE FEATURES)

Wenn du nur die App sofort zum Laufen bringen willst:

### Nur Phase 1 + 2 anwenden (30 Min)

Das gibt dir:
- ✅ Task Approval System
- ✅ Checklist Approval System
- ✅ Korrektes Punktesystem
- ✅ Check-in mit Punkten
- ✅ Shopping List
- ✅ Patrol Rounds
- ✅ How-To Documents

**App ist danach voll funktionsfähig!**

---

## 🚨 TROUBLESHOOTING

### Problem: "Function already exists"

```sql
-- Lösung: Droppe die Funktion und wende Migration erneut an
DROP FUNCTION IF EXISTS function_name CASCADE;
```

### Problem: "Column already exists"

```sql
-- Lösung: Überspringe diese Migration, ist bereits angewendet
```

### Problem: "RLS policy conflict"

```sql
-- Lösung: Droppe die Policy
DROP POLICY IF EXISTS "policy_name" ON table_name;
-- Dann Migration erneut anwenden
```

### Problem: Punkte werden nicht vergeben

```sql
-- Debug:
SELECT * FROM pg_trigger WHERE tgname LIKE '%point%';
SELECT * FROM pg_proc WHERE proname LIKE '%point%';

-- Test manuell:
INSERT INTO points_history (user_id, points_change, reason, category)
VALUES (auth.uid(), 10, 'Test', 'manual');

-- Prüfe:
SELECT * FROM profiles WHERE id = auth.uid();
```

---

## 📊 ERWARTETE DAUER

| Phase | Dauer | Kumulativ |
|-------|-------|-----------|
| Phase 1 | 20 Min | 20 Min |
| Phase 2 | 10 Min | 30 Min |
| Phase 3 | 15 Min | 45 Min |
| Phase 4 | 10 Min | 55 Min |
| Phase 5 | 20 Min | 75 Min |

---

## ✅ FINAL CHECKLIST

Nach allen Phasen:

- [ ] Alle RPC-Funktionen existieren (~20)
- [ ] Alle Tabellen existieren (~30)
- [ ] Alle Storage Buckets existieren (~8)
- [ ] Task Approval funktioniert
- [ ] Checklist Approval funktioniert
- [ ] Punktesystem zeigt korrekte Werte
- [ ] Check-in vergibt Punkte
- [ ] Shopping List zeigt Items
- [ ] Patrol Rounds funktionieren
- [ ] Frontend build läuft ohne Fehler

```bash
npm run build
```

---

## 🎉 FERTIG!

**Deine Villa Sun App ist jetzt vollständig funktionsfähig!**

Nächste Schritte:
1. Frontend deployen (Vercel/Netlify)
2. Environment Variables setzen
3. Test mit echten Usern
4. Genießen! 🌞
