/*
  # Add helper_id column to tasks table

  1. Changes
    - Add helper_id column to tasks table
    - This allows tracking a second staff member who helped complete the task
    - Helper receives 50% of the points

  2. Security
    - Column is nullable (not all tasks have helpers)
    - Foreign key references profiles table
*/

-- Add helper_id column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'helper_id'
  ) THEN
    ALTER TABLE tasks ADD COLUMN helper_id uuid REFERENCES profiles(id);
  END IF;
END $$;
