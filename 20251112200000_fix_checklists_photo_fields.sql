/*
  # Fix Checklists Schema - Add Missing Photo Fields

  1. New Columns
    - photo_required (boolean) - Ob Foto zwingend erforderlich ist
    - photo_required_sometimes (boolean) - Ob Foto manchmal erforderlich ist
    - photo_explanation_text (text) - Erklärung für Foto-Anforderung

  2. Changes
    - Fügt fehlende Spalten zu checklists Tabelle hinzu
    - Setzt Default-Werte
*/

-- Check if columns already exist, then add them
DO $$
BEGIN
  -- Add photo_required column if not exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklists' AND column_name = 'photo_required'
  ) THEN
    ALTER TABLE checklists ADD COLUMN photo_required boolean DEFAULT false;
  END IF;

  -- Add photo_required_sometimes column if not exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklists' AND column_name = 'photo_required_sometimes'
  ) THEN
    ALTER TABLE checklists ADD COLUMN photo_required_sometimes boolean DEFAULT false;
  END IF;

  -- Add photo_explanation_text column if not exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklists' AND column_name = 'photo_explanation_text'
  ) THEN
    ALTER TABLE checklists ADD COLUMN photo_explanation_text text;
  END IF;
END $$;
