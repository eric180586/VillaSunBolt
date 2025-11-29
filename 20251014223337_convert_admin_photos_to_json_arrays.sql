/*
  # Convert Admin Photo Fields to JSON Arrays
  
  ## Änderungen:
  Ermöglicht Admin-Usern das Hochladen mehrerer Fotos bei:
  - Task Erstellung (description_photo, explanation_photo)
  - Task Review/Reopen (admin_photo)
  - Checklist Erstellung (explanation_photo)
  - Checklist Review/Rejection (admin_photo)
  
  ## Details:
  1. **Tasks Table:**
     - `description_photo`: text → jsonb (Admin: Task Description Photos)
     - `explanation_photo`: text → jsonb (Admin: Reference Photos for Staff)
     - `admin_photo`: text → jsonb (Admin: Review/Reopen Photos)
     - `photo_proof`: bleibt text (Staff: nur 1 Completion Photo)
  
  2. **Checklists Table:**
     - `explanation_photo`: text → jsonb (Admin: Reference Photos)
  
  3. **Checklist_Instances Table:**
     - `admin_photo`: text → jsonb (Admin: Review/Rejection Photos)
     - `photo_proof`: bleibt text (Staff: nur 1 Completion Photo)
  
  ## Migration Strategy:
  - Konvertiert bestehende single URLs zu JSON arrays
  - NULL bleibt NULL (wird im Frontend zu [] behandelt)
  - Bestehende Daten bleiben erhalten
  
  ## Backward Compatibility:
  - Frontend muss aktualisiert werden um Arrays zu verarbeiten
  - Alte single URLs werden zu 1-element Arrays
*/

-- ==========================================
-- 1. TASKS TABLE - Admin Photo Fields
-- ==========================================

-- Convert description_photo: text → jsonb array
ALTER TABLE tasks
  ALTER COLUMN description_photo TYPE jsonb 
  USING CASE 
    WHEN description_photo IS NULL OR description_photo = '' THEN NULL
    ELSE jsonb_build_array(description_photo)
  END;

-- Convert explanation_photo: text → jsonb array
ALTER TABLE tasks
  ALTER COLUMN explanation_photo TYPE jsonb 
  USING CASE 
    WHEN explanation_photo IS NULL OR explanation_photo = '' THEN NULL
    ELSE jsonb_build_array(explanation_photo)
  END;

-- Convert admin_photo: text → jsonb array
ALTER TABLE tasks
  ALTER COLUMN admin_photo TYPE jsonb 
  USING CASE 
    WHEN admin_photo IS NULL OR admin_photo = '' THEN NULL
    ELSE jsonb_build_array(admin_photo)
  END;

-- photo_proof bleibt text (Staff Upload - nur 1 Foto)

-- ==========================================
-- 2. CHECKLISTS TABLE - Admin Photo Fields
-- ==========================================

-- Convert explanation_photo: text → jsonb array
ALTER TABLE checklists
  ALTER COLUMN explanation_photo TYPE jsonb 
  USING CASE 
    WHEN explanation_photo IS NULL OR explanation_photo = '' THEN NULL
    ELSE jsonb_build_array(explanation_photo)
  END;

-- ==========================================
-- 3. CHECKLIST_INSTANCES TABLE - Admin Photo Fields
-- ==========================================

-- Convert admin_photo: text → jsonb array
ALTER TABLE checklist_instances
  ALTER COLUMN admin_photo TYPE jsonb 
  USING CASE 
    WHEN admin_photo IS NULL OR admin_photo = '' THEN NULL
    ELSE jsonb_build_array(admin_photo)
  END;

-- photo_proof bleibt text (Staff Upload - nur 1 Foto)

-- ==========================================
-- 4. VERIFICATION
-- ==========================================

-- Verify tasks table structure
SELECT 
  '=== TASKS TABLE PHOTO FIELDS ===' as section,
  column_name,
  data_type,
  CASE 
    WHEN column_name = 'description_photo' THEN '✅ JSONB (Admin: Multiple)'
    WHEN column_name = 'explanation_photo' THEN '✅ JSONB (Admin: Multiple)'
    WHEN column_name = 'admin_photo' THEN '✅ JSONB (Admin: Multiple)'
    WHEN column_name = 'photo_proof' THEN '✅ TEXT (Staff: Single)'
    ELSE 'Other'
  END as new_type
FROM information_schema.columns
WHERE table_name = 'tasks'
AND column_name ILIKE '%photo%'
ORDER BY ordinal_position;

-- Verify checklists table
SELECT 
  '=== CHECKLISTS TABLE PHOTO FIELDS ===' as section,
  column_name,
  data_type,
  CASE 
    WHEN column_name = 'explanation_photo' THEN '✅ JSONB (Admin: Multiple)'
    ELSE 'Other'
  END as new_type
FROM information_schema.columns
WHERE table_name = 'checklists'
AND column_name ILIKE '%photo%'
ORDER BY ordinal_position;

-- Verify checklist_instances table
SELECT 
  '=== CHECKLIST_INSTANCES TABLE PHOTO FIELDS ===' as section,
  column_name,
  data_type,
  CASE 
    WHEN column_name = 'admin_photo' THEN '✅ JSONB (Admin: Multiple)'
    WHEN column_name = 'photo_proof' THEN '✅ TEXT (Staff: Single)'
    ELSE 'Other'
  END as new_type
FROM information_schema.columns
WHERE table_name = 'checklist_instances'
AND column_name ILIKE '%photo%'
ORDER BY ordinal_position;

-- Check if any existing data was migrated
SELECT 
  '=== DATA MIGRATION CHECK ===' as section,
  COUNT(*) as total_tasks,
  COUNT(*) FILTER (WHERE description_photo IS NOT NULL) as has_description_photos,
  COUNT(*) FILTER (WHERE explanation_photo IS NOT NULL) as has_explanation_photos,
  COUNT(*) FILTER (WHERE admin_photo IS NOT NULL) as has_admin_photos
FROM tasks;
