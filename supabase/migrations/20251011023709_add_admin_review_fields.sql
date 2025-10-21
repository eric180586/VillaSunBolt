/*
  # Add Admin Review Fields

  ## Changes
  
  1. Update tasks table
    - Add admin_notes field for admin review feedback
    - Add admin_photo field for admin review photo
    - Add reopened_count to track how many times task was reopened
  
  ## Purpose
  - Allow admin to add notes and photos when reviewing completed tasks
  - Track task reopening for quality control
*/

DO $$
BEGIN
  -- Add admin_notes field
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'admin_notes') THEN
    ALTER TABLE tasks ADD COLUMN admin_notes text;
  END IF;

  -- Add admin_photo field
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'admin_photo') THEN
    ALTER TABLE tasks ADD COLUMN admin_photo text;
  END IF;

  -- Add reopened_count field
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'reopened_count') THEN
    ALTER TABLE tasks ADD COLUMN reopened_count integer DEFAULT 0;
  END IF;
END $$;