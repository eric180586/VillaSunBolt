/*
  # Fix Departure Requests - Add Default Status
  
  1. Problem
    - status column has no default value, so new requests have NULL status
    - Frontend checks for 'pending' status, so duplicate detection fails
  
  2. Solution
    - Set default value for status column to 'pending'
    - Update existing NULL status records to 'pending'
*/

-- Update existing NULL status records to 'pending'
UPDATE departure_requests 
SET status = 'pending' 
WHERE status IS NULL;

-- Set default value for status column
ALTER TABLE departure_requests 
ALTER COLUMN status SET DEFAULT 'pending';

-- Also ensure status is NOT NULL going forward
ALTER TABLE departure_requests 
ALTER COLUMN status SET NOT NULL;