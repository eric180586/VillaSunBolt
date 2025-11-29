/*
  # Add photo_explanation to patrol_locations

  1. Changes
    - Add `photo_explanation` column to `patrol_locations` table
    - Optional text field for explaining what should be shown in the photo
    
  2. Purpose
    - Allows admins to specify what users should photograph at each patrol location
    - Example: "Show that the pool gate is locked" or "Capture the entire parking area"
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'patrol_locations' AND column_name = 'photo_explanation'
  ) THEN
    ALTER TABLE patrol_locations ADD COLUMN photo_explanation text;
  END IF;
END $$;
