/*
  # Fix Schedules Admin Insert Policy

  ## Changes:
  - Simplify admin check for INSERT
  - Remove manager role (not used in this system)
  - Ensure admin can create schedules
  
  ## Security:
  - Only admin can create schedules
  - All users can view schedules
  - Only admin can update/delete schedules
*/

-- Drop old policies
DROP POLICY IF EXISTS "Managers can create schedules" ON schedules;
DROP POLICY IF EXISTS "Managers can update schedules" ON schedules;
DROP POLICY IF EXISTS "Managers can delete schedules" ON schedules;

-- Create new simplified policies
CREATE POLICY "Admin can create schedules"
  ON schedules FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  );

CREATE POLICY "Admin can update schedules"
  ON schedules FOR UPDATE
  TO authenticated
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  )
  WITH CHECK (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  );

CREATE POLICY "Admin can delete schedules"
  ON schedules FOR DELETE
  TO authenticated
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  );

COMMENT ON POLICY "Admin can create schedules" ON schedules IS 
'Only admin can create new schedules for staff members';
