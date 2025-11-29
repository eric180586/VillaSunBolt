/*
  # Fix Check-In: Add Missing check_in_date Column

  ## Problem
  - process_check_in function tries to INSERT into check_in_date column
  - This column doesn't exist in the check_ins table
  - Causes 400 error on check-in

  ## Solution
  - Add check_in_date column to check_ins table
  - This stores the date portion separately for easier querying

  ## Changes
  - Add check_in_date text column to check_ins
*/

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'check_ins' AND column_name = 'check_in_date'
  ) THEN
    ALTER TABLE check_ins ADD COLUMN check_in_date text;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_check_ins_date ON check_ins(check_in_date);
