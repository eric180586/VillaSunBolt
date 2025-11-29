/*
  # Fix Patrol Scans - Prevent Duplicate Location Scans

  1. Problem
    - Same location can be scanned multiple times in one patrol round
    - Race condition in frontend allows duplicate scans
    - No database constraint to prevent this

  2. Solution
    - Add UNIQUE constraint on (patrol_round_id, location_id)
    - This ensures one location can only be scanned once per round
    - Database will reject duplicate attempts

  3. Changes
    - Remove any existing duplicate scans
    - Add unique constraint
    - Update error handling
*/

-- First, remove duplicate scans (keep the earliest one for each location per round)
DELETE FROM patrol_scans ps1
WHERE EXISTS (
  SELECT 1 FROM patrol_scans ps2
  WHERE ps2.patrol_round_id = ps1.patrol_round_id
  AND ps2.location_id = ps1.location_id
  AND ps2.created_at < ps1.created_at
);

-- Add unique constraint to prevent future duplicates
ALTER TABLE patrol_scans
ADD CONSTRAINT patrol_scans_round_location_unique 
UNIQUE (patrol_round_id, location_id);
