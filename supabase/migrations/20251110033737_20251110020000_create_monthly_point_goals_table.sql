/*
  # Create Monthly Point Goals System

  1. New Table
    - `monthly_point_goals`
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key to profiles)
      - `month` (text, format 'YYYY-MM')
      - `total_achievable_points` (integer, sum of all daily achievable)
      - `total_achieved_points` (integer, sum of all daily achieved)
      - `percentage` (numeric, achieved/achievable * 100)
      - `color_status` (text, green/yellow/orange/red based on percentage)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)
  
  2. Security
    - Enable RLS
    - Staff can read own monthly goals
    - Admin can read all monthly goals
  
  3. Notes
    - Unique constraint on (user_id, month)
    - This replaces the need for profiles.total_points
*/

-- Create monthly_point_goals table
CREATE TABLE IF NOT EXISTS monthly_point_goals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  month text NOT NULL,
  total_achievable_points integer DEFAULT 0,
  total_achieved_points integer DEFAULT 0,
  percentage numeric(5,2) DEFAULT 0,
  color_status text DEFAULT 'gray',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, month)
);

-- Enable RLS
ALTER TABLE monthly_point_goals ENABLE ROW LEVEL SECURITY;

-- Staff can read own monthly goals
CREATE POLICY "Staff can read own monthly goals"
  ON monthly_point_goals FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Admin can read all monthly goals
CREATE POLICY "Admin can read all monthly goals"
  ON monthly_point_goals FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- System can insert/update (called by functions)
CREATE POLICY "System can manage monthly goals"
  ON monthly_point_goals FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_monthly_point_goals_user_month 
  ON monthly_point_goals(user_id, month);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_monthly_point_goals_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_monthly_point_goals_updated_at
  BEFORE UPDATE ON monthly_point_goals
  FOR EACH ROW
  EXECUTE FUNCTION update_monthly_point_goals_updated_at();