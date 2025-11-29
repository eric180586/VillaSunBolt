/*
  # Create Point Templates System

  1. New Tables
    - `point_templates`
      - `id` (uuid, primary key)
      - `name` (text) - Template name (e.g., "Excellent Cleaning", "Late Arrival")
      - `points` (integer) - Point value (positive or negative)
      - `reason` (text) - Default reason text
      - `category` (text) - Category (bonus, penalty, achievement, etc.)
      - `created_by` (uuid) - Admin who created the template
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on `point_templates` table
    - Add policy for all authenticated users to read templates
    - Add policy for admin users to manage templates
*/

CREATE TABLE IF NOT EXISTS point_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  points integer NOT NULL,
  reason text NOT NULL,
  category text DEFAULT 'general',
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE point_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read point templates"
  ON point_templates
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can insert point templates"
  ON point_templates
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can update point templates"
  ON point_templates
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

CREATE POLICY "Admins can delete point templates"
  ON point_templates
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Insert default templates
INSERT INTO point_templates (name, points, reason, category) VALUES
  ('Excellent Work', 10, 'Outstanding performance and dedication', 'bonus'),
  ('Great Teamwork', 5, 'Excellent collaboration with team members', 'bonus'),
  ('Perfect Cleaning', 8, 'Spotless cleaning with attention to detail', 'achievement'),
  ('Guest Compliment', 15, 'Received special compliment from guest', 'achievement'),
  ('Late Arrival', -5, 'Late arrival to shift', 'penalty'),
  ('Minor Issue', -3, 'Small mistake or oversight', 'penalty'),
  ('Punctual Check-In', 5, 'On-time arrival and check-in', 'bonus')
ON CONFLICT DO NOTHING;

-- Add photo_url column to points_history for photo evidence
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'points_history' AND column_name = 'photo_url'
  ) THEN
    ALTER TABLE points_history ADD COLUMN photo_url text;
  END IF;
END $$;