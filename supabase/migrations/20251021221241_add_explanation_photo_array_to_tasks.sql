/*
  # Add explanation_photo array column to tasks

  1. Changes
    - Add `explanation_photo` (jsonb array) column to tasks table
    - This stores multiple URLs of photos that explain how to complete the task
    - Different from photo_explanation which was a single URL

  2. Security
    - No RLS changes needed - existing policies cover all columns
*/

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tasks' AND column_name = 'explanation_photo'
  ) THEN
    ALTER TABLE tasks ADD COLUMN explanation_photo jsonb DEFAULT '[]'::jsonb;
  END IF;
END $$;
