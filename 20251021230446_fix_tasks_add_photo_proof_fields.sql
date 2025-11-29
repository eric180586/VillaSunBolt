/*
  # Add Photo Proof Fields to Tasks Table

  1. Changes
    - Add `photo_proof_required` (boolean) - Whether photo is always required for this task
    - Add `photo_required_sometimes` (boolean) - Whether photo might be required via dice roll
    
  2. Notes
    - These fields match the existing fields in the checklists table
    - Allows tasks to have the same photo requirement functionality as checklists
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'photo_proof_required'
  ) THEN
    ALTER TABLE tasks ADD COLUMN photo_proof_required boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'photo_required_sometimes'
  ) THEN
    ALTER TABLE tasks ADD COLUMN photo_required_sometimes boolean DEFAULT false;
  END IF;
END $$;
