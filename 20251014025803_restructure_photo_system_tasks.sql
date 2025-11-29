/*
  # Restructure photo system for tasks

  1. Changes
    - Add `photo_required_sometimes` column for dice-roll photo requirement (30% chance)
    - Rename `photo_explanation` to `description_photo` for clarity (explanation uploaded by creator)
    - Keep `photo_proof_required` for mandatory photo requirement
    - Keep `photo_proof` for staff completion photo
    - Keep `explanation_photo` for reference photo shown at completion
    
  2. Photo System Structure:
    - Option 1: `description_photo` - Explanation photo by creator (optional)
    - Option 2: `photo_proof_required` - Mandatory photo by staff (admin sets checkbox)
    - Option 3: `photo_required_sometimes` - Dice-roll 30% chance (admin sets checkbox)
    - Option 4: `photo_proof` - Optional photo by staff at completion
*/

-- Add new column for "sometimes required" photo
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS photo_required_sometimes boolean DEFAULT false;

-- Rename photo_explanation to description_photo for clarity
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'photo_explanation'
  ) THEN
    ALTER TABLE tasks RENAME COLUMN photo_explanation TO description_photo;
  END IF;
END $$;
