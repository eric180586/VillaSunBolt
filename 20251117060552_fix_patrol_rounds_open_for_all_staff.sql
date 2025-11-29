/*
  # Fix patrol rounds to be open for all staff
  
  1. Changes
    - All staff can view all patrol rounds (not just assigned ones)
    - All staff can complete any patrol round
    - Penalties are only applied to the assigned_to person
  
  2. Security
    - Staff can view and complete patrol rounds
    - Admins have full access
*/

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "Users can update own patrol rounds" ON patrol_rounds;
DROP POLICY IF EXISTS "Staff can view their assigned patrol rounds" ON patrol_rounds;

-- Allow all staff to view all patrol rounds
CREATE POLICY "Staff can view all patrol rounds"
  ON patrol_rounds
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
    )
  );

-- Allow all staff to complete any patrol round
CREATE POLICY "Staff can complete any patrol round"
  ON patrol_rounds
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
    )
  );

-- Allow all staff to insert patrol scans for any round
DROP POLICY IF EXISTS "Users can insert own patrol scans" ON patrol_scans;

CREATE POLICY "Staff can insert patrol scans"
  ON patrol_scans
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
    )
  );

-- Update patrol scans select policy
DROP POLICY IF EXISTS "Users can view own patrol scans" ON patrol_scans;

CREATE POLICY "Staff can view all patrol scans"
  ON patrol_scans
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
    )
  );
