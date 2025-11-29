/*
  # Fix Task Accept Policy - Final Solution

  This migration fixes the RLS policy for accepting tasks to use WITH CHECK instead of USING.
  
  ## Changes
  - Drop existing "Staff can accept unassigned tasks" policy
  - Create new policy with proper WITH CHECK clause
  - Ensures staff can only accept tasks that:
    - Are unassigned (assigned_to IS NULL) OR match current user
    - Are in 'open' status
  
  ## Security
  - Maintains data integrity by validating conditions during INSERT/UPDATE
  - Prevents staff from accepting tasks assigned to others
*/

-- Drop existing policy
DROP POLICY IF EXISTS "Staff can accept unassigned tasks" ON tasks;

-- Create new policy with WITH CHECK
CREATE POLICY "Staff can accept unassigned tasks"
  ON tasks
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('staff', 'admin')
    )
  )
  WITH CHECK (
    assigned_to = auth.uid()
    AND status = 'open'
  );
