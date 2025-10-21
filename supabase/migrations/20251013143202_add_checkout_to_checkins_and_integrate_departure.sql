/*
  # Add Checkout Time and Integrate Departure Requests

  1. Changes to check_ins table
    - Add `checkout_time` column for tracking when staff checks out
    - Add `work_hours` column to store calculated work duration
    
  2. Security
    - RLS policies remain unchanged - same access as check-ins
*/

-- Add checkout_time and work_hours to check_ins
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'check_ins' AND column_name = 'checkout_time'
  ) THEN
    ALTER TABLE check_ins ADD COLUMN checkout_time timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'check_ins' AND column_name = 'work_hours'
  ) THEN
    ALTER TABLE check_ins ADD COLUMN work_hours numeric(4,2) DEFAULT 0;
  END IF;
END $$;

-- Function to calculate work hours when checkout happens
CREATE OR REPLACE FUNCTION calculate_work_hours()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.checkout_time IS NOT NULL AND NEW.check_in_time IS NOT NULL THEN
    NEW.work_hours := EXTRACT(EPOCH FROM (NEW.checkout_time - NEW.check_in_time)) / 3600.0;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-calculate work hours
DROP TRIGGER IF EXISTS trigger_calculate_work_hours ON check_ins;
CREATE TRIGGER trigger_calculate_work_hours
  BEFORE INSERT OR UPDATE OF checkout_time
  ON check_ins
  FOR EACH ROW
  EXECUTE FUNCTION calculate_work_hours();