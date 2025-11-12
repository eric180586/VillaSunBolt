/*
  # Fix fortune_wheel_spins table structure

  1. Problem
    - Table is missing columns that the frontend tries to save
    - check_in_id, reward_type, reward_value, reward_label missing

  2. Solution
    - Add missing columns
    - Keep existing points_won column

  3. Schema
    - check_in_id: Link to check-in
    - reward_type: Type of reward (always 'bonus_points')
    - reward_value: Display value (5, 10, etc)
    - reward_label: Display label
    - points_won: Actual points awarded
*/

-- Add missing columns to fortune_wheel_spins
ALTER TABLE fortune_wheel_spins 
ADD COLUMN IF NOT EXISTS check_in_id uuid REFERENCES check_ins(id),
ADD COLUMN IF NOT EXISTS reward_type text DEFAULT 'bonus_points',
ADD COLUMN IF NOT EXISTS reward_value integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS reward_label text DEFAULT '';

-- Update existing entries if any
UPDATE fortune_wheel_spins
SET reward_type = 'bonus_points'
WHERE reward_type IS NULL;