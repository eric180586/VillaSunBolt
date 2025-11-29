/*
  # Add items column to checklists

  ## Changes
  - Add items (jsonb) column to checklists table to store checklist items
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'checklists' AND column_name = 'items'
  ) THEN
    ALTER TABLE checklists ADD COLUMN items jsonb NOT NULL DEFAULT '[]';
  END IF;
END $$;