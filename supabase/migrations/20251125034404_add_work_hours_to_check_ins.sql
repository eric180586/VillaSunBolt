/*
  # Add work_hours column to check_ins table

  1. Problem
    - CheckInOverview.tsx references work_hours column that doesn't exist
    - This causes check-out to fail

  2. Solution
    - Add work_hours column to store calculated work hours
    - Default NULL, will be calculated on check-out
*/

-- Add work_hours column
ALTER TABLE check_ins 
ADD COLUMN IF NOT EXISTS work_hours numeric(5,2) DEFAULT NULL;

-- Add comment
COMMENT ON COLUMN check_ins.work_hours IS 'Total hours worked (calculated on check-out)';