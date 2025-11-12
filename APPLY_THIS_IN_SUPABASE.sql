-- ========================================
-- WICHTIG: Dieses SQL im Supabase Dashboard ausführen
-- ========================================
-- Gehen Sie zu: Supabase Dashboard → SQL Editor → New Query
-- Kopieren Sie dieses gesamte SQL und klicken Sie auf "Run"
-- ========================================

-- Fix Checklists Schema - Add Missing Photo Fields
DO $$
BEGIN
  -- Add photo_required column if not exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklists' AND column_name = 'photo_required'
  ) THEN
    ALTER TABLE checklists ADD COLUMN photo_required boolean DEFAULT false;
    RAISE NOTICE 'Added column: photo_required';
  ELSE
    RAISE NOTICE 'Column photo_required already exists';
  END IF;

  -- Add photo_required_sometimes column if not exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklists' AND column_name = 'photo_required_sometimes'
  ) THEN
    ALTER TABLE checklists ADD COLUMN photo_required_sometimes boolean DEFAULT false;
    RAISE NOTICE 'Added column: photo_required_sometimes';
  ELSE
    RAISE NOTICE 'Column photo_required_sometimes already exists';
  END IF;

  -- Add photo_explanation_text column if not exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklists' AND column_name = 'photo_explanation_text'
  ) THEN
    ALTER TABLE checklists ADD COLUMN photo_explanation_text text;
    RAISE NOTICE 'Added column: photo_explanation_text';
  ELSE
    RAISE NOTICE 'Column photo_explanation_text already exists';
  END IF;
END $$;

-- Verify the columns were added
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'checklists'
AND column_name IN ('photo_required', 'photo_required_sometimes', 'photo_explanation_text')
ORDER BY column_name;

-- ========================================
-- ERWARTETES ERGEBNIS:
-- Sie sollten 3 Zeilen sehen mit den neuen Spalten
-- ========================================
