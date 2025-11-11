/*
  # Create point_templates table

  For admins to manage point values for different actions.
  
  1. New Table
    - point_templates
      - id (uuid, primary key)
      - category (text) - e.g., 'task_completed', 'bonus', 'deduction'
      - name (text) - description
      - points (integer) - default point value
      - created_at (timestamptz)
      - updated_at (timestamptz)
  
  2. Security
    - Enable RLS
    - Only admins can modify
    - All authenticated can read
*/

CREATE TABLE IF NOT EXISTS point_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category text NOT NULL CHECK (category IN ('task_completed', 'bonus', 'deduction', 'achievement', 'other')),
  name text NOT NULL,
  points integer NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE point_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view point templates"
  ON point_templates
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Only admins can insert point templates"
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

CREATE POLICY "Only admins can update point templates"
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

CREATE POLICY "Only admins can delete point templates"
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

-- Insert some default templates
INSERT INTO point_templates (category, name, points) VALUES
  ('task_completed', 'Standard Task', 10),
  ('task_completed', 'Urgent Task', 20),
  ('bonus', 'Early Completion', 5),
  ('deduction', 'Late Completion', -5),
  ('achievement', 'Week Streak', 50),
  ('other', 'Manual Adjustment', 0)
ON CONFLICT DO NOTHING;
