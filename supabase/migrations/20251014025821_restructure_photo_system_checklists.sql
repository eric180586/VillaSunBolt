/*
  # Restructure photo system for checklists

  1. Changes
    - Add `photo_required_sometimes` column for dice-roll photo requirement (30% chance)
    - Rename `photo_explanation` to `description_photo` for clarity
    - Keep `photo_required` for mandatory photo requirement
    - Keep `explanation_photo` for reference photo shown at completion
    
  2. Photo System Structure (same as tasks):
    - Option 1: `description_photo` - Explanation photo by creator (optional, text)
    - Option 2: `photo_required` - Mandatory photo by staff (admin sets checkbox)
    - Option 3: `photo_required_sometimes` - Dice-roll 30% chance (admin sets checkbox)
    - Option 4: Staff can always upload photo optionally at completion
*/

-- Add new column for "sometimes required" photo
ALTER TABLE checklists 
ADD COLUMN IF NOT EXISTS photo_required_sometimes boolean DEFAULT false;

-- Rename photo_explanation to description_photo for clarity
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklists' AND column_name = 'photo_explanation'
  ) THEN
    ALTER TABLE checklists RENAME COLUMN photo_explanation TO description_photo;
  END IF;
END $$;
