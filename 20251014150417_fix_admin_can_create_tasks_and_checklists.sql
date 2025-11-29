/*
  # Fix Admin Permissions for Tasks and Checklists

  ## Problem
  - Admin cannot create tasks
  - Admin cannot create checklists
  - Only staff can create repair tasks

  ## Solution
  - Add INSERT policy for admin on tasks table
  - Add INSERT policy for admin on checklists table
  - Admin should be able to create ANY task/checklist
*/

-- Add INSERT policy for admins on tasks
CREATE POLICY "Admins can create any task"
ON tasks
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'admin'
  )
);

-- Add INSERT policy for admins on checklists
CREATE POLICY "Admins can create checklists"
ON checklists
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'admin'
  )
);
