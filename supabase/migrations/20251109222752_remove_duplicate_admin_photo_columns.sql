/*
  # Remove Duplicate admin_photo Columns

  1. Changes
    - Drop `admin_photo` column from `checklist_instances` (keeping `admin_photos`)
    - Drop `admin_photo` column from `tasks` (keeping `admin_photos`)

  2. Notes
    - This removes the singular column name and keeps the plural version
    - The plural version uses jsonb and supports multiple photos
*/

-- Remove admin_photo from checklist_instances (keep admin_photos)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklist_instances' AND column_name = 'admin_photo'
  ) THEN
    ALTER TABLE checklist_instances DROP COLUMN admin_photo;
  END IF;
END $$;

-- Remove admin_photo from tasks (keep admin_photos)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'admin_photo'
  ) THEN
    ALTER TABLE tasks DROP COLUMN admin_photo;
  END IF;
END $$;
