-- ========================================
-- KORREKTUR: Checklists sind jetzt Teil der TASKS Tabelle
-- ========================================
-- Die photo_required Felder werden zur TASKS Tabelle hinzugefügt
-- ========================================

DO $$
BEGIN
  -- Add photo_required column to TASKS if not exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'photo_required'
  ) THEN
    ALTER TABLE tasks ADD COLUMN photo_required boolean DEFAULT false;
    RAISE NOTICE 'Added column to tasks: photo_required';
  ELSE
    RAISE NOTICE 'Column photo_required already exists in tasks';
  END IF;

  -- Add photo_required_sometimes column to TASKS if not exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'photo_required_sometimes'
  ) THEN
    ALTER TABLE tasks ADD COLUMN photo_required_sometimes boolean DEFAULT false;
    RAISE NOTICE 'Added column to tasks: photo_required_sometimes';
  ELSE
    RAISE NOTICE 'Column photo_required_sometimes already exists in tasks';
  END IF;

END $$;

-- Verify the columns were added to TASKS
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'tasks'
AND column_name IN ('photo_required', 'photo_required_sometimes', 'photo_explanation_text')
ORDER BY column_name;

-- ========================================
-- ERWARTETES ERGEBNIS:
-- Sie sollten 3 Zeilen sehen (photo_explanation_text existiert bereits)
-- ========================================
