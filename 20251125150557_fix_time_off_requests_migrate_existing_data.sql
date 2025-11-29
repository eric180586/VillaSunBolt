/*
  # Fix Time-Off Requests - Migrate Existing Data

  ## Problem
  - Added start_date and end_date as NOT NULL
  - But existing rows have NULL values
  - Need to migrate request_date to start_date/end_date

  ## Solution
  1. Make start_date and end_date nullable first
  2. Migrate existing data: request_date → start_date and end_date
  3. Set defaults for new rows
  4. Update constraint to allow NULL only if request_date exists (backwards compatibility)
*/

-- ============================================================================
-- 1. Make start_date and end_date nullable
-- ============================================================================

ALTER TABLE time_off_requests 
  ALTER COLUMN start_date DROP NOT NULL,
  ALTER COLUMN end_date DROP NOT NULL;

-- ============================================================================
-- 2. Migrate existing data: Copy request_date to start_date and end_date
-- ============================================================================

UPDATE time_off_requests
SET 
  start_date = request_date,
  end_date = request_date
WHERE start_date IS NULL AND request_date IS NOT NULL;

-- ============================================================================
-- 3. Add check constraint: Either (start_date AND end_date) OR request_date must exist
-- ============================================================================

ALTER TABLE time_off_requests
DROP CONSTRAINT IF EXISTS time_off_dates_check;

ALTER TABLE time_off_requests
ADD CONSTRAINT time_off_dates_check 
CHECK (
  (start_date IS NOT NULL AND end_date IS NOT NULL) 
  OR 
  request_date IS NOT NULL
);

-- ============================================================================
-- 4. Create function to auto-fill start_date/end_date from request_date
-- ============================================================================

CREATE OR REPLACE FUNCTION auto_fill_time_off_dates()
RETURNS TRIGGER AS $$
BEGIN
  -- If start_date and end_date are NULL but request_date exists, copy it
  IF NEW.start_date IS NULL AND NEW.end_date IS NULL AND NEW.request_date IS NOT NULL THEN
    NEW.start_date := NEW.request_date;
    NEW.end_date := NEW.request_date;
  END IF;
  
  -- If start_date and end_date exist but request_date doesn't, copy start_date
  IF NEW.request_date IS NULL AND NEW.start_date IS NOT NULL THEN
    NEW.request_date := NEW.start_date;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 5. Create trigger to auto-fill dates
-- ============================================================================

DROP TRIGGER IF EXISTS trigger_auto_fill_time_off_dates ON time_off_requests;

CREATE TRIGGER trigger_auto_fill_time_off_dates
  BEFORE INSERT OR UPDATE ON time_off_requests
  FOR EACH ROW
  EXECUTE FUNCTION auto_fill_time_off_dates();

COMMENT ON FUNCTION auto_fill_time_off_dates IS 
'Auto-fills start_date/end_date from request_date for backwards compatibility';

COMMENT ON CONSTRAINT time_off_dates_check ON time_off_requests IS 
'Ensures either (start_date AND end_date) OR request_date is provided';
