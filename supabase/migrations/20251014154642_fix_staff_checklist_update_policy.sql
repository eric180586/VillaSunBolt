/*
  # Fix staff checklist update policy

  ## Problem
  - Staff cannot update checklist_instances
  - UPDATE policy has WITH CHECK = null (blocks all updates)
  
  ## Solution
  - Add proper WITH CHECK clause to allow staff to update checklists
*/

-- Drop existing policy
DROP POLICY IF EXISTS "Staff can update checklist instances" ON checklist_instances;

-- Create new policy with proper WITH CHECK
CREATE POLICY "Staff can update checklist instances"
ON checklist_instances
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role IN ('staff', 'admin')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role IN ('staff', 'admin')
  )
);
