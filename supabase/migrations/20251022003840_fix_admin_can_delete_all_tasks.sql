/*
  # Fix Admin Delete Permission for Tasks

  ## Changes:
  - Admin can delete ANY task (not just created by them)
  - Staff can only delete tasks they created
  
  ## Security:
  - Admin role verified through profiles table
*/

-- Drop existing delete policy
DROP POLICY IF EXISTS "Users can delete their created tasks" ON tasks;

-- Create new policies: one for staff, one for admin
CREATE POLICY "Staff can delete their created tasks"
  ON tasks FOR DELETE
  TO authenticated
  USING (
    auth.uid() = created_by 
    AND (SELECT role FROM profiles WHERE id = auth.uid()) = 'staff'
  );

CREATE POLICY "Admin can delete any task"
  ON tasks FOR DELETE
  TO authenticated
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  );

COMMENT ON POLICY "Admin can delete any task" ON tasks IS 
'Allows admin to delete any task regardless of who created it';
