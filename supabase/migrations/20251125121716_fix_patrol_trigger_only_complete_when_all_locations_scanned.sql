/*
  # Fix Patrol Scan Trigger - Only Complete When All Locations Scanned

  ## Problem
  The trigger `award_patrol_scan_point()` marks patrol_rounds as completed 
  after EVERY scan, even if only 1 location was scanned.
  
  This prevents scanning multiple locations per round!

  ## Solution
  Only mark patrol_round as completed when:
  - ALL locations have been scanned (count unique scanned locations)
  - Compare with total number of patrol_locations

  ## Changes
  - Rewrite trigger function to check if all locations are scanned
  - Award +1 point per scan (keep existing logic)
  - Only set completed_at when uniqueLocations === totalLocations
*/

CREATE OR REPLACE FUNCTION award_patrol_scan_point()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id uuid;
  v_location_name text;
  v_patrol_date date;
  v_total_locations integer;
  v_scanned_locations integer;
BEGIN
  -- When a new scan is inserted
  v_user_id := NEW.user_id;

  -- Get location name
  SELECT name INTO v_location_name
  FROM patrol_locations
  WHERE id = NEW.location_id;

  -- Get patrol date from patrol_round
  SELECT date INTO v_patrol_date
  FROM patrol_rounds
  WHERE id = NEW.patrol_round_id;

  -- Award +1 point for completing patrol scan
  IF v_user_id IS NOT NULL THEN
    INSERT INTO points_history (
      user_id,
      points_change,
      reason,
      category,
      created_by
    ) VALUES (
      v_user_id,
      1,
      'Patrol scan completed: ' || COALESCE(v_location_name, 'Location'),
      'patrol_completed',
      v_user_id
    );

    -- Update daily point goals
    PERFORM update_daily_point_goals_for_user(v_user_id, v_patrol_date);
  END IF;

  -- Check if ALL locations have been scanned for this round
  SELECT COUNT(*) INTO v_total_locations
  FROM patrol_locations;

  SELECT COUNT(DISTINCT location_id) INTO v_scanned_locations
  FROM patrol_scans
  WHERE patrol_round_id = NEW.patrol_round_id;

  -- Only mark as completed if ALL locations scanned
  IF v_scanned_locations >= v_total_locations THEN
    UPDATE patrol_rounds
    SET 
      completed_at = NEW.scanned_at,
      points_awarded = v_total_locations,
      points_calculated = true
    WHERE id = NEW.patrol_round_id
      AND completed_at IS NULL;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION award_patrol_scan_point IS 
'Awards +1 point per patrol scan. Marks patrol_round as completed ONLY when all locations are scanned.';
