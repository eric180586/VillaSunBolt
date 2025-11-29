/*
  # Fix Task Acceptance RLS Policy

  1. Changes
    - Update RLS policy to allow staff to accept unassigned tasks
    - Staff can update tasks if they are unassigned (assigned_to IS NULL) OR if they are the creator OR assigned user

  2. Security
    - Maintains security by only allowing updates to tasks that are:
      - Created by the user
      - Assigned to the user
      - Unassigned (allowing staff to accept tasks)
*/

-- Drop the old policy
DROP POLICY IF EXISTS "Users can update their created or assigned tasks" ON tasks;

-- Create new policy that allows accepting unassigned tasks
CREATE POLICY "Users can update their created or assigned tasks"
  ON tasks
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = created_by 
    OR auth.uid() = assigned_to 
    OR assigned_to IS NULL
  )
  WITH CHECK (
    auth.uid() = created_by 
    OR auth.uid() = assigned_to
  );
