/*
  # Add shift_date column to departure_requests

  1. Changes
    - Add `shift_date` column (date) to departure_requests table
    - This column stores which day the departure request is for
    - Used to prevent duplicate requests for the same day
  
  2. Security
    - No RLS changes needed
*/

-- Add shift_date column
ALTER TABLE departure_requests 
ADD COLUMN IF NOT EXISTS shift_date date NOT NULL DEFAULT CURRENT_DATE;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_departure_requests_shift_date 
ON departure_requests(user_id, shift_date);
