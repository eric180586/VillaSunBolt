/*
  # Fix Missing WITH CHECK for Check-Ins and Departure Requests

  1. Problem
    - check_ins and departure_requests UPDATE policies missing WITH CHECK
    - This blocks admins from approving/modifying these records

  2. Solution
    - Add WITH CHECK to UPDATE policies
    - Ensure super_admin has full access
*/

-- Check-Ins: Admin can update with WITH CHECK
DROP POLICY IF EXISTS "Admins can update check_ins" ON check_ins;
CREATE POLICY "Admins can update check_ins"
  ON check_ins FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- Departure Requests: Admin can update with WITH CHECK
DROP POLICY IF EXISTS "Admins can update departure_requests" ON departure_requests;
CREATE POLICY "Admins can update departure_requests"
  ON departure_requests FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );
