/*
  # Add Missing Patrol Round Points Columns

  ## Problem
  patrol_rounds table is missing columns for points tracking:
  - points_awarded (integer) - Points given when round is completed
  - points_calculated (boolean) - Flag to track if points were already calculated
  
  ## Solution
  Add these columns with proper defaults
*/

-- Add missing points columns
ALTER TABLE patrol_rounds
  ADD COLUMN IF NOT EXISTS points_awarded integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS points_calculated boolean DEFAULT false;