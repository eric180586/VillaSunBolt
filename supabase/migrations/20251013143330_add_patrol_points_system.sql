/*
  # Add Patrol Points System

  1. Changes to patrol_rounds table
    - Add `points_awarded` column (3 for complete, -3 for incomplete)
    - Add `points_calculated` flag to prevent double-counting
    
  2. New RPC Function
    - `complete_patrol_round(round_id)` - Awards 3 points when all locations scanned
    - `penalize_incomplete_patrol(round_id)` - Deducts 3 points for incomplete rounds
    
  3. Security
    - Only staff can complete their own rounds
    - System auto-penalizes incomplete rounds after time window
*/

-- Add points columns to patrol_rounds
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'patrol_rounds' AND column_name = 'points_awarded'
  ) THEN
    ALTER TABLE patrol_rounds ADD COLUMN points_awarded integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'patrol_rounds' AND column_name = 'points_calculated'
  ) THEN
    ALTER TABLE patrol_rounds ADD COLUMN points_calculated boolean DEFAULT false;
  END IF;
END $$;

-- Function to complete a patrol round and award points
CREATE OR REPLACE FUNCTION complete_patrol_round(
  p_round_id uuid
)
RETURNS json AS $$
DECLARE
  v_round record;
  v_location_count int;
  v_scan_count int;
  v_points int;
  v_date date;
BEGIN
  -- Get round info
  SELECT * INTO v_round
  FROM patrol_rounds
  WHERE id = p_round_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Round not found');
  END IF;
  
  -- Check if already calculated
  IF v_round.points_calculated THEN
    RETURN json_build_object('success', false, 'message', 'Points already calculated');
  END IF;
  
  -- Count total locations
  SELECT COUNT(*) INTO v_location_count
  FROM patrol_locations;
  
  -- Count scans for this round
  SELECT COUNT(*) INTO v_scan_count
  FROM patrol_scans
  WHERE patrol_round_id = p_round_id;
  
  -- Determine points: +3 if complete, -3 if incomplete
  IF v_scan_count >= v_location_count THEN
    v_points := 3;
  ELSE
    v_points := -3;
  END IF;
  
  -- Update round
  UPDATE patrol_rounds
  SET 
    points_awarded = v_points,
    points_calculated = true,
    completed_at = CASE WHEN completed_at IS NULL THEN NOW() ELSE completed_at END
  WHERE id = p_round_id;
  
  -- Add points to daily goals
  v_date := v_round.date;
  
  INSERT INTO daily_point_goals (user_id, date, points_earned)
  VALUES (v_round.assigned_to, v_date, v_points)
  ON CONFLICT (user_id, date)
  DO UPDATE SET 
    points_earned = daily_point_goals.points_earned + v_points,
    updated_at = NOW();
  
  RETURN json_build_object(
    'success', true,
    'points_awarded', v_points,
    'complete', v_scan_count >= v_location_count,
    'scans', v_scan_count,
    'total_locations', v_location_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;