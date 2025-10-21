/*
  # Add description_photo column to tasks

  1. Changes
    - Add `description_photo` (jsonb array) column to tasks table
    - This stores URLs of photos that explain/describe the task

  2. Security
    - No RLS changes needed - existing policies cover all columns
*/

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tasks' AND column_name = 'description_photo'
  ) THEN
    ALTER TABLE tasks ADD COLUMN description_photo jsonb DEFAULT '[]'::jsonb;
  END IF;
END $$;
