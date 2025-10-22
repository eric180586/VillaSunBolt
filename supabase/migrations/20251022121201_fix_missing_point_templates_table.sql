/*
  # Fix Missing point_templates Table
  
  ## Problem
  The point_templates table was missing from the consolidated migrations, causing
  INSERT operations on tasks to fail because triggers call functions that reference
  this table.
  
  ## Solution
  1. Create point_templates table with correct schema (action_type, base_points)
  2. Insert default check_in entry with 0 points (as per current system design)
  3. Add RLS policies for security
  
  ## Tables Created
  - point_templates
    - id: uuid primary key
    - action_type: text (e.g., 'check_in', 'task_complete', etc.)
    - base_points: integer (point value for this action)
    - description: text (optional description)
    - created_at: timestamptz
    - updated_at: timestamptz
    
  ## Security
  - RLS enabled
  - All authenticated users can read
  - Only admins can modify
*/

-- Create point_templates table
CREATE TABLE IF NOT EXISTS point_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action_type text UNIQUE NOT NULL,
  base_points integer NOT NULL DEFAULT 0,
  description text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE point_templates ENABLE ROW LEVEL SECURITY;

-- RLS Policies
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

-- Insert default values
-- Check-in is set to 0 points as per current system design
INSERT INTO point_templates (action_type, base_points, description) VALUES
  ('check_in', 0, 'Base points for checking in (currently set to 0)'),
  ('task_complete', 0, 'Base points for task completion (points come from task itself)'),
  ('patrol_complete', 3, 'Points per patrol round completion')
ON CONFLICT (action_type) DO NOTHING;

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_point_templates_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_point_templates_updated_at
  BEFORE UPDATE ON point_templates
  FOR EACH ROW
  EXECUTE FUNCTION update_point_templates_updated_at();
