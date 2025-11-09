/*
  # Fix Missing Database Structures

  1. New Tables
    - `time_off_requests`
      - `id` (uuid, primary key)
      - `staff_id` (uuid, foreign key to profiles)
      - `request_date` (date)
      - `reason` (text)
      - `status` (text) - pending, approved, rejected
      - `admin_id` (uuid, foreign key to profiles)
      - `processed_at` (timestamptz)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Changes
    - Add `published_at` column to `weekly_schedules` table

  3. Security
    - Enable RLS on `time_off_requests` table
    - Add policies for staff to view/create their own requests
    - Add policies for admin to view/update all requests
*/

-- Create time_off_requests table
CREATE TABLE IF NOT EXISTS time_off_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  request_date date NOT NULL,
  reason text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  processed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Add published_at column to weekly_schedules if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'weekly_schedules' AND column_name = 'published_at'
  ) THEN
    ALTER TABLE weekly_schedules ADD COLUMN published_at timestamptz;
  END IF;
END $$;

-- Enable RLS on time_off_requests
ALTER TABLE time_off_requests ENABLE ROW LEVEL SECURITY;

-- Staff can view their own time-off requests
CREATE POLICY "Staff can view own time-off requests"
  ON time_off_requests
  FOR SELECT
  TO authenticated
  USING (auth.uid() = staff_id);

-- Staff can create their own time-off requests
CREATE POLICY "Staff can create own time-off requests"
  ON time_off_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = staff_id);

-- Staff can update their own pending requests
CREATE POLICY "Staff can update own pending requests"
  ON time_off_requests
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = staff_id AND status = 'pending')
  WITH CHECK (auth.uid() = staff_id AND status = 'pending');

-- Admin can view all time-off requests
CREATE POLICY "Admin can view all time-off requests"
  ON time_off_requests
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Admin can update all time-off requests
CREATE POLICY "Admin can update all time-off requests"
  ON time_off_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Admin can delete time-off requests
CREATE POLICY "Admin can delete time-off requests"
  ON time_off_requests
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_time_off_requests_staff_id ON time_off_requests(staff_id);
CREATE INDEX IF NOT EXISTS idx_time_off_requests_request_date ON time_off_requests(request_date);
CREATE INDEX IF NOT EXISTS idx_time_off_requests_status ON time_off_requests(status);
