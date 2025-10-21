/*
  ============================================================================
  MIGRATIONS TEST SCRIPT - Villa Sun App
  ============================================================================

  Dieses Script testet systematisch alle Migrations-Phasen.

  USAGE:
  1. Führe nach jeder Phase die entsprechenden Tests aus
  2. Alle Tests müssen erfolgreich sein bevor du zur nächsten Phase gehst
  3. Bei Fehlern: Stopp und behebe das Problem bevor du weitermachst

  ============================================================================
*/

-- ============================================================================
-- PHASE 1 TESTS: CRITICAL FOUNDATION
-- ============================================================================

\echo '========================================';
\echo 'PHASE 1 TESTS: Critical Foundation';
\echo '========================================';

-- Test 1.1: RPC-Funktionen existieren
\echo '\n TEST 1.1: Prüfe RPC-Funktionen...';
SELECT
  CASE
    WHEN COUNT(*) = 7 THEN '✅ PASS: Alle 7 RPC-Funktionen existieren'
    ELSE '❌ FAIL: Nur ' || COUNT(*) || ' von 7 RPC-Funktionen gefunden'
  END as test_result
FROM information_schema.routines
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

-- Test 1.2: Tabellen existieren
\echo '\n TEST 1.2: Prüfe Tabellen...';
SELECT
  CASE
    WHEN COUNT(*) = 7 THEN '✅ PASS: Alle 7 Tabellen existieren'
    ELSE '❌ FAIL: Nur ' || COUNT(*) || ' von 7 Tabellen gefunden'
  END as test_result
FROM information_schema.tables
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

-- Test 1.3: Task-Spalten existieren
\echo '\n TEST 1.3: Prüfe Task-Spalten...';
SELECT
  CASE
    WHEN COUNT(*) = 3 THEN '✅ PASS: Alle 3 Task-Spalten existieren'
    ELSE '❌ FAIL: Nur ' || COUNT(*) || ' von 3 Task-Spalten gefunden'
  END as test_result
FROM information_schema.columns
WHERE table_name = 'tasks'
AND column_name IN ('deadline_bonus_awarded', 'initial_points_value', 'secondary_assigned_to');

-- Test 1.4: Checklist-Spalten existieren
\echo '\n TEST 1.4: Prüfe Checklist-Spalten...';
SELECT
  CASE
    WHEN COUNT(*) >= 2 THEN '✅ PASS: Checklist-Spalten existieren'
    ELSE '❌ FAIL: Nur ' || COUNT(*) || ' Checklist-Spalten gefunden'
  END as test_result
FROM information_schema.columns
WHERE table_name = 'checklist_instances'
AND column_name IN ('admin_reviewed', 'admin_approved');

-- Test 1.5: Patrol Locations vorbefüllt
\echo '\n TEST 1.5: Prüfe Patrol Locations...';
SELECT
  CASE
    WHEN COUNT(*) >= 3 THEN '✅ PASS: Patrol Locations vorbefüllt (' || COUNT(*) || ' Locations)'
    ELSE '❌ FAIL: Nur ' || COUNT(*) || ' Patrol Locations gefunden'
  END as test_result
FROM patrol_locations;

-- Test 1.6: daily_point_goals Spalten
\echo '\n TEST 1.6: Prüfe daily_point_goals Struktur...';
SELECT
  CASE
    WHEN COUNT(*) >= 8 THEN '✅ PASS: daily_point_goals korrekt strukturiert'
    ELSE '❌ FAIL: daily_point_goals incomplete (' || COUNT(*) || ' Spalten)'
  END as test_result
FROM information_schema.columns
WHERE table_name = 'daily_point_goals';

\echo '\n========================================';
\echo 'PHASE 1 TESTS ABGESCHLOSSEN';
\echo '========================================';
\echo 'Wenn alle Tests ✅ PASS: Weiter zu Phase 2';
\echo 'Wenn Tests ❌ FAIL: Debug vor Fortsetzung!';
\echo '';

-- ============================================================================
-- PHASE 2 TESTS: FINAL POINTS SYSTEM
-- ============================================================================

\echo '========================================';
\echo 'PHASE 2 TESTS: Final Points System';
\echo '========================================';

-- Test 2.1: calculate_daily_achievable_points existiert
\echo '\n TEST 2.1: Prüfe calculate_daily_achievable_points...';
SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM pg_proc
      WHERE proname = 'calculate_daily_achievable_points'
    ) THEN '✅ PASS: calculate_daily_achievable_points existiert'
    ELSE '❌ FAIL: calculate_daily_achievable_points fehlt'
  END as test_result;

-- Test 2.2: calculate_team_achievable_points existiert
\echo '\n TEST 2.2: Prüfe calculate_team_achievable_points...';
SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM pg_proc
      WHERE proname = 'calculate_team_achievable_points'
    ) THEN '✅ PASS: calculate_team_achievable_points existiert'
    ELSE '❌ FAIL: calculate_team_achievable_points fehlt'
  END as test_result;

-- Test 2.3: calculate_monthly_progress existiert
\echo '\n TEST 2.3: Prüfe calculate_monthly_progress...';
SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM pg_proc
      WHERE proname = 'calculate_monthly_progress'
    ) THEN '✅ PASS: calculate_monthly_progress existiert'
    ELSE '❌ FAIL: calculate_monthly_progress fehlt'
  END as test_result;

-- Test 2.4: Test calculate_monthly_progress Rückgabe
\echo '\n TEST 2.4: Test calculate_monthly_progress Output...';
DO $$
DECLARE
  v_user_id uuid;
  v_result jsonb;
BEGIN
  -- Hole ersten Staff-User
  SELECT id INTO v_user_id FROM profiles WHERE role = 'staff' LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE NOTICE '⚠️  WARNING: Kein Staff-User gefunden für Test';
    RETURN;
  END IF;

  -- Test Funktion
  SELECT calculate_monthly_progress(v_user_id) INTO v_result;

  IF v_result ? 'percentage' AND v_result ? 'total_achievable' THEN
    RAISE NOTICE '✅ PASS: calculate_monthly_progress gibt korrektes JSONB zurück';
  ELSE
    RAISE EXCEPTION '❌ FAIL: calculate_monthly_progress gibt fehlerhaftes JSONB zurück';
  END IF;
END $$;

\echo '\n========================================';
\echo 'PHASE 2 TESTS ABGESCHLOSSEN';
\echo '========================================';
\echo 'Wenn alle Tests ✅ PASS: Weiter zu Phase 3';
\echo 'Wenn Tests ❌ FAIL: Debug vor Fortsetzung!';
\echo '';

-- ============================================================================
-- PHASE 3 TESTS: EXTENDED FEATURES
-- ============================================================================

\echo '========================================';
\echo 'PHASE 3 TESTS: Extended Features';
\echo '========================================';

-- Test 3.1: Extended Tabellen existieren
\echo '\n TEST 3.1: Prüfe Extended Tabellen...';
SELECT
  CASE
    WHEN COUNT(*) >= 5 THEN '✅ PASS: Extended Tabellen existieren (' || COUNT(*) || ' gefunden)'
    ELSE '❌ FAIL: Nur ' || COUNT(*) || ' Extended Tabellen gefunden'
  END as test_result
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
  'chat_messages',
  'fortune_wheel_results',
  'quiz_highscores',
  'tutorial_categories',
  'tutorial_slides'
);

-- Test 3.2: add_bonus_points Funktion
\echo '\n TEST 3.2: Prüfe add_bonus_points...';
SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM pg_proc
      WHERE proname = 'add_bonus_points'
    ) THEN '✅ PASS: add_bonus_points existiert'
    ELSE '❌ FAIL: add_bonus_points fehlt'
  END as test_result;

-- Test 3.3: Storage Buckets
\echo '\n TEST 3.3: Prüfe Storage Buckets...';
SELECT
  CASE
    WHEN COUNT(*) >= 2 THEN '✅ PASS: Storage Buckets existieren (' || COUNT(*) || ' gefunden)'
    ELSE '❌ FAIL: Nur ' || COUNT(*) || ' Storage Buckets gefunden'
  END as test_result
FROM storage.buckets
WHERE name IN ('chat-photos', 'tutorial-images');

\echo '\n========================================';
\echo 'PHASE 3 TESTS ABGESCHLOSSEN';
\echo '========================================';

-- ============================================================================
-- PHASE 4 TESTS: ADMIN PERMISSIONS
-- ============================================================================

\echo '========================================';
\echo 'PHASE 4 TESTS: Admin Permissions';
\echo '========================================';

-- Test 4.1: Admin Profile Policies
\echo '\n TEST 4.1: Prüfe Admin Profile Policies...';
SELECT
  CASE
    WHEN COUNT(*) >= 3 THEN '✅ PASS: Admin Profile Policies existieren'
    ELSE '❌ FAIL: Nicht genug Admin Profile Policies'
  END as test_result
FROM pg_policies
WHERE tablename = 'profiles'
AND policyname LIKE '%admin%';

-- Test 4.2: Schedule Visibility Policies
\echo '\n TEST 4.2: Prüfe Schedule Policies...';
SELECT
  CASE
    WHEN COUNT(*) >= 1 THEN '✅ PASS: Schedule Policies existieren'
    ELSE '❌ FAIL: Schedule Policies fehlen'
  END as test_result
FROM pg_policies
WHERE tablename = 'schedules';

\echo '\n========================================';
\echo 'PHASE 4 TESTS ABGESCHLOSSEN';
\echo '========================================';

-- ============================================================================
-- PHASE 5 TESTS: OPTIMIZATIONS & FIXES
-- ============================================================================

\echo '========================================';
\echo 'PHASE 5 TESTS: Optimizations & Fixes';
\echo '========================================';

-- Test 5.1: Notification System
\echo '\n TEST 5.1: Prüfe Notification Spalten...';
SELECT
  CASE
    WHEN column_name = 'priority' THEN '✅ PASS: Notification priority Spalte existiert'
    ELSE '⚠️  INFO: Notification priority Spalte fehlt (optional)'
  END as test_result
FROM information_schema.columns
WHERE table_name = 'notifications'
AND column_name = 'priority'
UNION ALL
SELECT '✅ PASS: Notifications Tabelle existiert' as test_result
WHERE EXISTS (
  SELECT 1 FROM information_schema.tables
  WHERE table_name = 'notifications'
);

-- Test 5.2: Photo Buckets
\echo '\n TEST 5.2: Prüfe Photo Buckets...';
SELECT
  CASE
    WHEN COUNT(*) >= 2 THEN '✅ PASS: Photo Buckets existieren (' || COUNT(*) || ' gefunden)'
    ELSE '⚠️  WARNING: Nur ' || COUNT(*) || ' Photo Buckets gefunden'
  END as test_result
FROM storage.buckets
WHERE name IN ('task-photos', 'admin-reviews', 'checklist-explanations');

-- Test 5.3: Archived Status
\echo '\n TEST 5.3: Prüfe Archived Status...';
SELECT
  CASE
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_name = 'tasks'
      AND column_name = 'archived'
    ) OR EXISTS (
      SELECT 1 FROM pg_type
      WHERE typname = 'task_status'
      AND 'archived' = ANY(enum_range(NULL::task_status)::text[])
    ) THEN '✅ PASS: Archived Status verfügbar'
    ELSE '⚠️  INFO: Archived Status nicht gefunden (optional)'
  END as test_result;

\echo '\n========================================';
\echo 'PHASE 5 TESTS ABGESCHLOSSEN';
\echo '========================================';

-- ============================================================================
-- FINAL COMPREHENSIVE TEST
-- ============================================================================

\echo '\n========================================';
\echo 'FINAL COMPREHENSIVE TEST';
\echo '========================================';

-- Zähle alle Tabellen
\echo '\n Gesamt-Tabellen:';
SELECT COUNT(*) || ' Tabellen' as total_tables
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_type = 'BASE TABLE';

-- Zähle alle RPC-Funktionen
\echo '\n Gesamt-RPC-Funktionen:';
SELECT COUNT(*) || ' RPC-Funktionen' as total_functions
FROM information_schema.routines
WHERE routine_schema = 'public';

-- Zähle alle Storage Buckets
\echo '\n Gesamt-Storage-Buckets:';
SELECT COUNT(*) || ' Storage Buckets' as total_buckets
FROM storage.buckets;

-- Zähle alle Policies
\echo '\n Gesamt-RLS-Policies:';
SELECT COUNT(*) || ' RLS Policies' as total_policies
FROM pg_policies
WHERE schemaname = 'public';

\echo '\n========================================';
\echo '🎉 ALLE TESTS ABGESCHLOSSEN!';
\echo '========================================';
\echo '';
\echo 'Erwartete Werte (nach allen Phasen):';
\echo '  - Tabellen: ~30';
\echo '  - RPC-Funktionen: ~20';
\echo '  - Storage Buckets: ~8';
\echo '  - RLS Policies: ~100';
\echo '';
\echo 'Nächste Schritte:';
\echo '  1. npm run build';
\echo '  2. Frontend deployen';
\echo '  3. Environment Variables setzen';
\echo '  4. Mit echten Usern testen';
\echo '';
\echo '========================================';
