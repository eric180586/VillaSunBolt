/*
  # Fix Checklists Photo Fields Schema Mismatch

  ## Problem
  Frontend uses: photo_required, photo_required_sometimes, photo_explanation_text
  Database has: photo_requirement (text), photo_explanation (text)
  
  ## Changes
  1. Add missing columns to match frontend expectations:
     - photo_required (boolean) - Always require photo
     - photo_required_sometimes (boolean) - Sometimes require photo
     - photo_explanation_text (text) - Explanation text for photo requirements
  
  2. Keep existing photo_requirement and photo_explanation for backward compatibility
  
  ## Migration Strategy
  - Add new columns with defaults
  - Migrate existing data from photo_requirement to new boolean fields
  - Keep old columns for now (can be removed later after verification)
*/

-- Add new columns that frontend expects
ALTER TABLE checklists 
ADD COLUMN IF NOT EXISTS photo_required boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS photo_required_sometimes boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS photo_explanation_text text;

-- Migrate existing data from photo_requirement to new boolean fields
UPDATE checklists
SET 
  photo_required = CASE WHEN photo_requirement = 'always' THEN true ELSE false END,
  photo_required_sometimes = CASE WHEN photo_requirement = 'sometimes' THEN true ELSE false END
WHERE photo_requirement IS NOT NULL;

-- Migrate photo_explanation to photo_explanation_text
UPDATE checklists
SET photo_explanation_text = photo_explanation
WHERE photo_explanation IS NOT NULL AND photo_explanation_text IS NULL;

-- Note: We keep photo_requirement and photo_explanation columns for now
-- They can be dropped in a future migration after verification
