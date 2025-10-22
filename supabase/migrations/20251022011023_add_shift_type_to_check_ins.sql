/*
  # Add shift_type Column to check_ins

  ## Problem:
  - process_check_in function tries to insert shift_type
  - Column doesn't exist in check_ins table
  
  ## Solution:
  - Add shift_type column
  - Allow 'früh' or 'spät' values
*/

-- Add shift_type column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'check_ins' AND column_name = 'shift_type'
  ) THEN
    ALTER TABLE check_ins ADD COLUMN shift_type text CHECK (shift_type IN ('früh', 'spät'));
  END IF;
END $$;

COMMENT ON COLUMN check_ins.shift_type IS 
'Type of shift: früh (early, 09:00) or spät (late, 15:00)';
