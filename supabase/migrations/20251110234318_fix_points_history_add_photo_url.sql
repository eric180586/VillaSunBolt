/*
  # Add photo_url column to points_history

  1. Changes
    - Add `photo_url` column to `points_history` table for evidence photos
    - Allows admins to attach photo proof when manually awarding/deducting points
  
  2. Notes
    - Column is optional (nullable) since not all point awards require photo evidence
    - Used by manual point awards from PointsManager component
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'points_history' AND column_name = 'photo_url'
  ) THEN
    ALTER TABLE points_history ADD COLUMN photo_url TEXT;
  END IF;
END $$;
