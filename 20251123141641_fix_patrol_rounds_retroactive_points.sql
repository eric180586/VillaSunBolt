/*
  # Fix Patrol Rounds Points Display

  Update patrol_rounds.points_awarded for all completed rounds.
  The points ARE being tracked in points_history correctly, 
  but the display column was never updated.
  
  ## Changes
  - Update all completed patrol_rounds to show points_awarded = 1
  - Modify trigger to also update patrol_rounds.points_awarded column
  
  ## Security
  - No RLS changes needed
*/

-- Fix all existing patrol rounds that were completed
UPDATE patrol_rounds
SET points_awarded = 1
WHERE completed_at IS NOT NULL
  AND points_awarded = 0;

-- Update the trigger to also set points_awarded
CREATE OR REPLACE FUNCTION award_patrol_scan_point()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id uuid;
  v_location_name text;
  v_patrol_date date;
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

  -- Mark patrol_round as completed AND set points_awarded
  UPDATE patrol_rounds
  SET 
    completed_at = NEW.scanned_at,
    points_awarded = 1,
    points_calculated = true
  WHERE id = NEW.patrol_round_id
    AND completed_at IS NULL;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
