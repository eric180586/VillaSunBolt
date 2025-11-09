/*
  # Fix daily_point_goals table structure
  
  Adds missing columns:
  - user_id (references profiles)
  - theoretically_achievable_points
  - achieved_points
  - percentage
  - color_status
  
  Also removes duplicate calculate_monthly_progress function
*/

-- Add missing columns to daily_point_goals
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'daily_point_goals' AND column_name = 'user_id') THEN
    ALTER TABLE daily_point_goals ADD COLUMN user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'daily_point_goals' AND column_name = 'theoretically_achievable_points') THEN
    ALTER TABLE daily_point_goals ADD COLUMN theoretically_achievable_points integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'daily_point_goals' AND column_name = 'achieved_points') THEN
    ALTER TABLE daily_point_goals ADD COLUMN achieved_points integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'daily_point_goals' AND column_name = 'percentage') THEN
    ALTER TABLE daily_point_goals ADD COLUMN percentage numeric(5,2) DEFAULT 0.00;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'daily_point_goals' AND column_name = 'color_status') THEN
    ALTER TABLE daily_point_goals ADD COLUMN color_status text DEFAULT 'red';
  END IF;
END $$;

-- Add unique constraint on user_id and goal_date
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'daily_point_goals_user_id_goal_date_key'
  ) THEN
    ALTER TABLE daily_point_goals ADD CONSTRAINT daily_point_goals_user_id_goal_date_key UNIQUE(user_id, goal_date);
  END IF;
END $$;

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_daily_point_goals_user_date ON daily_point_goals(user_id, goal_date);
CREATE INDEX IF NOT EXISTS idx_daily_point_goals_date ON daily_point_goals(goal_date);

-- Drop the old calculate_monthly_progress function that returns a table
DROP FUNCTION IF EXISTS calculate_monthly_progress(integer, integer, uuid);

-- Keep only the version that returns jsonb
-- This is the one with signature: (p_user_id uuid, p_year integer, p_month integer)