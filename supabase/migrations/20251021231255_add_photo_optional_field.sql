/*
  # Add photo_optional Field to Tasks and Checklists

  1. Changes
    - Add `photo_optional` (boolean) to tasks table - Photo is optional for completion
    - Add `photo_optional` (boolean) to checklists table - Photo is optional for completion
    
  2. Notes
    - This field allows marking photos as optional vs required
    - Complements existing photo_proof_required and photo_required_sometimes fields
    - Provides a third option: photo is nice to have but not mandatory
*/

DO $$
BEGIN
  -- Add to tasks table
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'photo_optional'
  ) THEN
    ALTER TABLE tasks ADD COLUMN photo_optional boolean DEFAULT false;
  END IF;

  -- Add to checklists table
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklists' AND column_name = 'photo_optional'
  ) THEN
    ALTER TABLE checklists ADD COLUMN photo_optional boolean DEFAULT false;
  END IF;
END $$;
