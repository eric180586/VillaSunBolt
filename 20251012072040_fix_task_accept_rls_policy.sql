/*
  # Fix Task Accept RLS Policy

  1. Changes
    - Update the UPDATE policy for tasks table
    - Allow staff to accept unassigned tasks by updating assigned_to to themselves
    - Keep admin full access
    - Keep existing permission for assigned users to update their tasks
  
  2. Security
    - Staff can only self-assign when task has no assignment
    - Staff cannot steal tasks from others
    - Admins retain full access
*/

-- Drop existing update policy
DROP POLICY IF EXISTS "Users can update tasks appropriately" ON tasks;

-- Create new update policy that allows accepting unassigned tasks
CREATE POLICY "Users can update tasks appropriately"
  ON tasks
  FOR UPDATE
  TO authenticated
  USING (
    -- Admins can update any task
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'admin'
    )
    -- Users assigned to the task can update it
    OR auth.uid() = assigned_to
    OR auth.uid() = secondary_assigned_to
    -- Staff can accept unassigned tasks (assigned_to is null)
    OR (
      assigned_to IS NULL 
      AND EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'staff'
      )
    )
  )
  WITH CHECK (
    -- Admins can make any changes
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'admin'
    )
    -- Users assigned to the task can update it
    OR auth.uid() = assigned_to
    OR auth.uid() = secondary_assigned_to
    -- Staff can only self-assign (not assign to others)
    OR (
      assigned_to = auth.uid()
      AND EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid() 
        AND profiles.role = 'staff'
      )
    )
  );
