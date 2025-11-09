/*
  # Add review columns to tasks table

  1. Changes
    - Add admin_reviewed boolean to track if admin has reviewed
    - Add admin_approved boolean to track approval status
    - Add reviewed_by uuid to track which admin reviewed
    - Add reviewed_at timestamp to track when reviewed

  2. Notes
    - These columns are used by the task approval system
    - admin_reviewed = true when admin has reviewed (approved or not)
    - admin_approved = true/false for approval status
*/

-- Add review columns if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'admin_reviewed'
  ) THEN
    ALTER TABLE tasks ADD COLUMN admin_reviewed boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'admin_approved'
  ) THEN
    ALTER TABLE tasks ADD COLUMN admin_approved boolean;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'reviewed_by'
  ) THEN
    ALTER TABLE tasks ADD COLUMN reviewed_by uuid REFERENCES profiles(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'reviewed_at'
  ) THEN
    ALTER TABLE tasks ADD COLUMN reviewed_at timestamptz;
  END IF;
END $$;
