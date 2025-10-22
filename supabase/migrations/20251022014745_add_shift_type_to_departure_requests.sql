/*
  # Add shift_type column to departure_requests

  1. Changes
    - Add `shift_type` column (text) to departure_requests table
    - This column stores whether the departure request is for early or late shift
    - Allows 'früh' or 'spät' values
  
  2. Security
    - No RLS changes needed
*/

-- Add shift_type column
ALTER TABLE departure_requests 
ADD COLUMN IF NOT EXISTS shift_type text NOT NULL DEFAULT 'spät' CHECK (shift_type IN ('früh', 'spät'));
