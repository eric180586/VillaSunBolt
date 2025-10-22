/*
  # Create Weekly Schedules Table

  ## New Tables:
  - `weekly_schedules`
    - `id` (uuid, primary key)
    - `staff_id` (uuid, references profiles)
    - `week_start_date` (date) - Monday of the week
    - `shifts` (jsonb) - Array of day shifts [{day, date, shift}]
    - `is_published` (boolean) - Whether schedule is published to staff
    - `created_by` (uuid, references profiles)
    - `created_at` (timestamptz)
    - `updated_at` (timestamptz)

  ## Security:
  - Enable RLS
  - Admin can create/update/delete schedules
  - All authenticated users can view schedules
  - One schedule per staff per week (unique constraint)
*/

CREATE TABLE IF NOT EXISTS weekly_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  week_start_date date NOT NULL,
  shifts jsonb NOT NULL DEFAULT '[]'::jsonb,
  is_published boolean DEFAULT false,
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Ensure one schedule per staff per week
CREATE UNIQUE INDEX IF NOT EXISTS idx_weekly_schedules_staff_week 
  ON weekly_schedules(staff_id, week_start_date);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_weekly_schedules_week_date ON weekly_schedules(week_start_date);
CREATE INDEX IF NOT EXISTS idx_weekly_schedules_staff_id ON weekly_schedules(staff_id);

ALTER TABLE weekly_schedules ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view schedules
CREATE POLICY "Users can view all weekly schedules"
  ON weekly_schedules FOR SELECT
  TO authenticated
  USING (true);

-- Admin can create schedules
CREATE POLICY "Admin can create weekly schedules"
  ON weekly_schedules FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  );

-- Admin can update schedules
CREATE POLICY "Admin can update weekly schedules"
  ON weekly_schedules FOR UPDATE
  TO authenticated
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  )
  WITH CHECK (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  );

-- Admin can delete schedules
CREATE POLICY "Admin can delete weekly schedules"
  ON weekly_schedules FOR DELETE
  TO authenticated
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  );

COMMENT ON TABLE weekly_schedules IS 
'Weekly work schedules for staff members showing early/late/off shifts for each day';

COMMENT ON COLUMN weekly_schedules.shifts IS 
'JSONB array of shift objects: [{day: "monday", date: "2025-01-13", shift: "early"}]';
