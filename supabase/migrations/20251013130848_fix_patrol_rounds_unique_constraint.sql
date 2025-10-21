/*
  # Fix Patrol Rounds Unique Constraint

  This migration adds a unique constraint to prevent duplicate patrol rounds
  for the same date, time_slot, and assigned_to combination.

  ## Changes
  - Add unique constraint on (date, time_slot, assigned_to)
  - This prevents the system from creating duplicate patrol rounds
*/

-- Add unique constraint to prevent duplicates
ALTER TABLE patrol_rounds 
ADD CONSTRAINT patrol_rounds_date_time_user_unique 
UNIQUE (date, time_slot, assigned_to);
