/*
  # Fix Task Completion and Accept Functionality
  
  ## Problems Identified
  1. Missing completion_notes column in tasks table
  2. RLS policy prevents staff from accepting unassigned tasks
  
  ## Solutions
  1. Add completion_notes column to tasks table
  2. Update RLS policy to allow staff to accept unassigned tasks
  
  ## Changes
  - Add completion_notes text column to tasks
  - Modify UPDATE policy to allow accepting unassigned tasks
  
  ## Security
  - Staff can only accept tasks (set assigned_to) if:
    - Task is currently unassigned (assigned_to IS NULL), OR
    - They are already assigned (assigned_to = auth.uid()), OR
    - They created the task (created_by = auth.uid())
  - Maintains existing security for updates
*/

-- Add completion_notes column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'completion_notes'
  ) THEN
    ALTER TABLE tasks ADD COLUMN completion_notes text;
  END IF;
END $$;

-- Drop old restrictive UPDATE policy
DROP POLICY IF EXISTS "Users can update their created or assigned tasks" ON tasks;

-- Create new UPDATE policy that allows accepting unassigned tasks
CREATE POLICY "Users can update tasks they created, are assigned to, or can accept"
  ON tasks
  FOR UPDATE
  TO authenticated
  USING (
    -- Can update if: created by me, assigned to me, or is unassigned
    auth.uid() = created_by 
    OR auth.uid() = assigned_to
    OR assigned_to IS NULL
  )
  WITH CHECK (
    -- When updating, ensure you don't break ownership rules
    -- You can:
    -- 1. Update your own created tasks
    -- 2. Update tasks assigned to you
    -- 3. Accept unassigned tasks (assign to yourself)
    auth.uid() = created_by 
    OR auth.uid() = assigned_to
    OR (
      -- Allow accepting unassigned tasks
      -- OLD.assigned_to was NULL and NEW.assigned_to is me
      EXISTS (
        SELECT 1 FROM tasks old_task
        WHERE old_task.id = tasks.id
        AND old_task.assigned_to IS NULL
      )
      AND assigned_to = auth.uid()
    )
  );

-- Comment for clarity
COMMENT ON POLICY "Users can update tasks they created, are assigned to, or can accept" ON tasks IS 
  'Allows users to update tasks they created or are assigned to. Also allows staff to accept unassigned tasks by setting assigned_to to their own ID.';
