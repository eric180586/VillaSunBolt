/*
  # Cleanup duplicate photo columns in tasks table

  1. Changes
    - Remove `explanation_photo` column (duplicate of description_photo)
    - Remove `photo_explanation` column (old unused field)
    - Keep only `description_photo` for task explanation photos
  
  2. Notes
    - These columns were accidentally duplicated
    - Frontend only uses `description_photo`
*/

-- Remove duplicate/unused photo columns
ALTER TABLE tasks DROP COLUMN IF EXISTS explanation_photo;
ALTER TABLE tasks DROP COLUMN IF EXISTS photo_explanation;
