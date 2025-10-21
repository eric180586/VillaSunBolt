/*
  # Create Weekly Schedules and Time-Off Request System

  ## New Tables
  
  1. weekly_schedules
    - id (uuid, primary key)
    - staff_id (uuid, references profiles)
    - week_start_date (date) - Monday of the week
    - shifts (jsonb) - Array of daily shifts: [{day: 'monday', shift: 'early'/'late'/'off'}]
    - is_published (boolean)
    - created_by (uuid, references profiles)
    - published_at (timestamptz)
    - created_at (timestamptz)
    - updated_at (timestamptz)
  
  2. time_off_requests
    - id (uuid, primary key)
    - staff_id (uuid, references profiles)
    - request_date (date) - The date they want off
    - reason (text)
    - status (pending, approved, rejected)
    - admin_response (text) - Reason if rejected
    - reviewed_by (uuid, references profiles)
    - reviewed_at (timestamptz)
    - created_at (timestamptz)
    - updated_at (timestamptz)
  
  ## Security
  - Enable RLS on both tables
  - Admin can do everything
  - Staff can view their own schedules and create time-off requests
*/

-- Create weekly_schedules table
CREATE TABLE IF NOT EXISTS weekly_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  week_start_date date NOT NULL,
  shifts jsonb NOT NULL DEFAULT '[]',
  is_published boolean DEFAULT false,
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  published_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(staff_id, week_start_date)
);

-- Create time_off_requests table
CREATE TABLE IF NOT EXISTS time_off_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  request_date date NOT NULL,
  reason text NOT NULL,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_response text,
  reviewed_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE weekly_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE time_off_requests ENABLE ROW LEVEL SECURITY;

-- RLS Policies for weekly_schedules
CREATE POLICY "Users can view own schedules or admins view all"
  ON weekly_schedules FOR SELECT
  TO authenticated
  USING (
    staff_id = auth.uid() OR 
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

CREATE POLICY "Only admins can insert weekly schedules"
  ON weekly_schedules FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

CREATE POLICY "Only admins can update weekly schedules"
  ON weekly_schedules FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

CREATE POLICY "Only admins can delete weekly schedules"
  ON weekly_schedules FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

-- RLS Policies for time_off_requests
CREATE POLICY "Users can view own requests and admins can view all"
  ON time_off_requests FOR SELECT
  TO authenticated
  USING (
    staff_id = auth.uid() OR 
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

CREATE POLICY "Staff can create time-off requests"
  ON time_off_requests FOR INSERT
  TO authenticated
  WITH CHECK (staff_id = auth.uid());

CREATE POLICY "Only admins can update time-off requests"
  ON time_off_requests FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

CREATE POLICY "Users can delete own pending requests"
  ON time_off_requests FOR DELETE
  TO authenticated
  USING (
    staff_id = auth.uid() AND status = 'pending'
  );

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_weekly_schedules_staff_id ON weekly_schedules(staff_id);
CREATE INDEX IF NOT EXISTS idx_weekly_schedules_week_start ON weekly_schedules(week_start_date);
CREATE INDEX IF NOT EXISTS idx_weekly_schedules_published ON weekly_schedules(is_published);
CREATE INDEX IF NOT EXISTS idx_timeoff_staff_id ON time_off_requests(staff_id);
CREATE INDEX IF NOT EXISTS idx_timeoff_status ON time_off_requests(status);
CREATE INDEX IF NOT EXISTS idx_timeoff_date ON time_off_requests(request_date);