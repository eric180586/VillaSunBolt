/*
  # Cleanup Incorrectly Completed Patrol Rounds

  ## Problem
  Before the trigger fix, patrol_rounds were marked as completed
  after only 1 scan instead of requiring all 3 locations.
  
  This left incomplete rounds marked as completed, preventing users
  from continuing to scan the remaining locations.

  ## Solution
  Reset any patrol_rounds that are marked as completed but have
  less than the total number of locations scanned.

  ## Changes
  - Reset completed_at, points_calculated, points_awarded for incomplete rounds
  - This allows users to continue scanning these rounds
*/

-- Reset incorrectly completed rounds (completed but less than all locations scanned)
UPDATE patrol_rounds pr
SET 
  completed_at = NULL,
  points_calculated = false,
  points_awarded = 0
WHERE completed_at IS NOT NULL
  AND (
    SELECT COUNT(DISTINCT location_id) 
    FROM patrol_scans ps 
    WHERE ps.patrol_round_id = pr.id
  ) < (SELECT COUNT(*) FROM patrol_locations);

-- Add comment explaining the fix
COMMENT ON TABLE patrol_rounds IS 
'Patrol rounds tracking. A round is only completed when all locations have been scanned.
The trigger award_patrol_scan_point() manages the completed_at status automatically.';
