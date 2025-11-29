/*
  # Add admin_id and processed_at columns to departure_requests

  1. Changes
    - Add `admin_id` column (uuid) to track which admin approved/rejected the request
    - Add `processed_at` column (timestamptz) to track when the request was processed
    - These replace the old approved_by and approved_at columns
  
  2. Security
    - No RLS changes needed
*/

-- Add admin_id column (references profiles)
ALTER TABLE departure_requests 
ADD COLUMN IF NOT EXISTS admin_id uuid REFERENCES profiles(id);

-- Add processed_at column
ALTER TABLE departure_requests 
ADD COLUMN IF NOT EXISTS processed_at timestamptz;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_departure_requests_admin_id 
ON departure_requests(admin_id);
