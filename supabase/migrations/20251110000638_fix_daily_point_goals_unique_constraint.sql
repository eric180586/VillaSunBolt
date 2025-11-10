/*
  # Fix daily_point_goals unique constraint

  1. Changes
    - Remove incorrect UNIQUE constraint on goal_date alone
    - Keep correct UNIQUE constraint on (user_id, goal_date)
    - This allows multiple users to have goals for the same date

  2. Notes
    - The daily_point_goals_goal_date_key constraint is incorrect
    - Each user should have one goal per date
*/

-- Drop the incorrect constraint that only checks goal_date
ALTER TABLE daily_point_goals
DROP CONSTRAINT IF EXISTS daily_point_goals_goal_date_key;
