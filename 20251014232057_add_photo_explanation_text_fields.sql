/*
  # Add Photo Explanation Text Fields
  
  ## Problem:
  - Admins müssen Referenz-Fotos hochladen um Staff zu zeigen, wo Fotos gemacht werden sollen
  - Text-Beschreibung wäre oft klarer und schneller
  
  ## Lösung:
  Neue Text-Felder für Foto-Anweisungen hinzufügen:
  - `tasks.photo_explanation_text` - Text statt Referenz-Foto
  - `checklists.photo_explanation_text` - Text statt Referenz-Foto
  
  ## Verwendung:
  Wenn Admin bei Task/Checklist "Foto erforderlich" oder "Foto manchmal" aktiviert:
  - Admin kann Text eingeben: "Wo soll das Foto gemacht werden?"
  - Beispiel: "Foto vom Poolbereich nach der Reinigung, von der Eingangstür aus"
  - Staff sieht diese Anweisung wenn Foto erforderlich ist
  
  ## Vorteile:
  1. Klarer als Fotos - Text ist oft präziser
  2. Kein Storage verbraucht
  3. Schneller für Admin
  4. Flexibler - genaue Beschreibung möglich
  
  ## Hinweis:
  - `explanation_photo` (jsonb) bleibt bestehen für andere Zwecke
  - Das neue Text-Feld ist optional (NULL erlaubt)
*/

-- ==========================================
-- 1. TASKS TABLE - Add photo explanation text
-- ==========================================

ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS photo_explanation_text text;

COMMENT ON COLUMN tasks.photo_explanation_text IS 
  'Text-Anweisung für Staff: Wo/Was soll fotografiert werden (z.B. "Foto vom Pool nach Reinigung")';

-- ==========================================
-- 2. CHECKLISTS TABLE - Add photo explanation text
-- ==========================================

ALTER TABLE checklists
  ADD COLUMN IF NOT EXISTS photo_explanation_text text;

COMMENT ON COLUMN checklists.photo_explanation_text IS 
  'Text-Anweisung für Staff: Wo/Was soll fotografiert werden';

-- ==========================================
-- 3. VERIFICATION
-- ==========================================

-- Verify tasks table
SELECT 
  '=== TASKS TABLE ===' as section,
  column_name,
  data_type,
  is_nullable,
  CASE 
    WHEN column_name = 'photo_explanation_text' THEN '✅ NEU: Text-Anweisung für Staff'
    WHEN column_name = 'explanation_photo' THEN '✅ BLEIBT: Allgemeine Erklärungs-Fotos'
    WHEN column_name = 'photo_proof_required' THEN '✅ Foto immer erforderlich'
    WHEN column_name = 'photo_required_sometimes' THEN '✅ Foto manchmal erforderlich'
    ELSE 'Other'
  END as description
FROM information_schema.columns
WHERE table_name = 'tasks'
AND (
  column_name ILIKE '%photo%' 
  OR column_name ILIKE '%explanation%'
)
ORDER BY ordinal_position;

-- Verify checklists table
SELECT 
  '=== CHECKLISTS TABLE ===' as section,
  column_name,
  data_type,
  is_nullable,
  CASE 
    WHEN column_name = 'photo_explanation_text' THEN '✅ NEU: Text-Anweisung für Staff'
    WHEN column_name = 'explanation_photo' THEN '✅ BLEIBT: Allgemeine Erklärungs-Fotos'
    WHEN column_name = 'photo_required' THEN '✅ Foto immer erforderlich'
    WHEN column_name = 'photo_required_sometimes' THEN '✅ Foto manchmal erforderlich'
    ELSE 'Other'
  END as description
FROM information_schema.columns
WHERE table_name = 'checklists'
AND (
  column_name ILIKE '%photo%' 
  OR column_name ILIKE '%explanation%'
)
ORDER BY ordinal_position;

-- Show usage example
SELECT 
  '=== USAGE EXAMPLE ===' as info,
  'Admin erstellt Task mit photo_proof_required = true' as step_1,
  'Admin gibt text ein: "Foto vom Pool nach Reinigung"' as step_2,
  'Speichert in: photo_explanation_text' as step_3,
  'Staff sieht Text wenn Foto erforderlich ist' as step_4;
