/*
  # Update Checklists Structure

  ## Changes
  
  1. Update checklists table
    - Ensure category field exists and uses same categories as tasks
    - Add recurrence field (one_time, daily, weekly, bi_weekly, monthly)
    - Add due_date field
    - Add points_value field
    - Add is_template field (all checklists are templates)
    - Add last_generated_date for recurring templates
  
  2. Create checklist_instances table
    - For tracking actual checklist completions
    - Links to template
    - Tracks completion status and who completed items
  
  3. Update RLS policies
    - Only admins can create/edit/delete checklists
    - Staff can view and complete checklist instances
*/

-- Update checklists table
DO $$
BEGIN
  -- Add recurrence field
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'checklists' AND column_name = 'recurrence') THEN
    ALTER TABLE checklists ADD COLUMN recurrence text DEFAULT 'one_time' 
    CHECK (recurrence IN ('one_time', 'daily', 'weekly', 'bi_weekly', 'monthly'));
  END IF;

  -- Add due_date field
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'checklists' AND column_name = 'due_date') THEN
    ALTER TABLE checklists ADD COLUMN due_date timestamptz;
  END IF;

  -- Add points_value field
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'checklists' AND column_name = 'points_value') THEN
    ALTER TABLE checklists ADD COLUMN points_value integer DEFAULT 10;
  END IF;

  -- Add is_template field
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'checklists' AND column_name = 'is_template') THEN
    ALTER TABLE checklists ADD COLUMN is_template boolean DEFAULT true;
  END IF;

  -- Add last_generated_date field
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'checklists' AND column_name = 'last_generated_date') THEN
    ALTER TABLE checklists ADD COLUMN last_generated_date timestamptz;
  END IF;

  -- Update category constraint if needed
  ALTER TABLE checklists DROP CONSTRAINT IF EXISTS checklists_category_check;
  ALTER TABLE checklists ADD CONSTRAINT checklists_category_check 
    CHECK (category IN ('daily_morning', 'room_cleaning', 'small_cleaning', 'extras', 'housekeeping', 'reception', 'shopping', 'repair', 'admin'));
END $$;

-- Create checklist_instances table
CREATE TABLE IF NOT EXISTS checklist_instances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  checklist_id uuid REFERENCES checklists(id) ON DELETE CASCADE NOT NULL,
  instance_date date NOT NULL,
  items jsonb NOT NULL,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed')),
  completed_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  completed_at timestamptz,
  points_awarded boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS on checklist_instances
ALTER TABLE checklist_instances ENABLE ROW LEVEL SECURITY;

-- RLS Policies for checklist_instances
CREATE POLICY "Users can view checklist instances based on role"
  ON checklist_instances FOR SELECT
  TO authenticated
  USING (
    CASE 
      WHEN EXISTS (
        SELECT 1 FROM checklists 
        WHERE checklists.id = checklist_instances.checklist_id 
        AND checklists.category = 'admin'
      ) THEN 
        EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
      ELSE true
    END
  );

CREATE POLICY "Staff can create checklist instances"
  ON checklist_instances FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Staff can update checklist instances"
  ON checklist_instances FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Only admins can delete checklist instances"
  ON checklist_instances FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_checklist_instances_checklist_id ON checklist_instances(checklist_id);
CREATE INDEX IF NOT EXISTS idx_checklist_instances_instance_date ON checklist_instances(instance_date);
CREATE INDEX IF NOT EXISTS idx_checklist_instances_status ON checklist_instances(status);
CREATE INDEX IF NOT EXISTS idx_checklists_recurrence ON checklists(recurrence);
CREATE INDEX IF NOT EXISTS idx_checklists_last_generated ON checklists(last_generated_date);