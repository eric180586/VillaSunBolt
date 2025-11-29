/*
  # Fix departure_requests Table - Add Missing Columns

  ## Problem
  The departure_requests table is missing critical columns:
  - shift_date (date) - to track which date the request is for
  - shift_type (text) - to track which shift (früh/spät)
  - admin_id (uuid) - to track who processed the request
  - processed_at (timestamptz) - to track when it was processed

  ## Solution
  Add these missing columns with proper types and defaults
*/

-- Add missing columns to departure_requests
ALTER TABLE departure_requests
  ADD COLUMN IF NOT EXISTS shift_date date,
  ADD COLUMN IF NOT EXISTS shift_type text,
  ADD COLUMN IF NOT EXISTS admin_id uuid REFERENCES profiles(id),
  ADD COLUMN IF NOT EXISTS processed_at timestamptz;

-- Add index for faster queries
CREATE INDEX IF NOT EXISTS idx_departure_requests_shift_date ON departure_requests(shift_date);
CREATE INDEX IF NOT EXISTS idx_departure_requests_user_status ON departure_requests(user_id, status);