/*
  # Prevent duplicate patrol rounds

  1. Changes
    - Add unique constraint to prevent duplicate patrol rounds
    - Ensures one round per date/time_slot/assigned_to combination

  2. Security
    - No RLS changes needed
*/

-- Add unique constraint to prevent duplicates
ALTER TABLE patrol_rounds
ADD CONSTRAINT unique_patrol_round 
UNIQUE (date, time_slot, assigned_to);
