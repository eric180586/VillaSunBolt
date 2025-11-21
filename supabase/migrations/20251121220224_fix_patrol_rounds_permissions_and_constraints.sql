/*
  # Fix Patrol Rounds Permissions and Constraints

  1. Problem
    - Duplicate and inconsistent RLS policies on patrol tables
    - Staff can see patrol_rounds but policies are confusing
    - Multiple overlapping policies causing permission issues

  2. Solution
    - Remove duplicate policies
    - Create clear, consistent permission structure:
      - Everyone authenticated can VIEW all patrol data
      - Only assigned staff can UPDATE their rounds
      - Only staff can INSERT scans
      - Only admins can manage schedules and locations

  3. Tables Fixed
    - patrol_rounds
    - patrol_scans
    - patrol_locations
    - patrol_schedules
*/

-- ============================================================================
-- PATROL_ROUNDS: Clean up and consolidate policies
-- ============================================================================

-- Drop all existing policies
DROP POLICY IF EXISTS "Admin can delete patrol_rounds" ON patrol_rounds;
DROP POLICY IF EXISTS "Anyone authenticated can view patrol rounds" ON patrol_rounds;
DROP POLICY IF EXISTS "Staff can complete any patrol round" ON patrol_rounds;
DROP POLICY IF EXISTS "Staff can view all patrol rounds" ON patrol_rounds;
DROP POLICY IF EXISTS "System can manage patrol rounds" ON patrol_rounds;
DROP POLICY IF EXISTS "User or admin can update patrol_rounds" ON patrol_rounds;

-- Create new consolidated policies
CREATE POLICY "Everyone can view patrol rounds"
  ON patrol_rounds
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Assigned staff or admin can update patrol rounds"
  ON patrol_rounds
  FOR UPDATE
  TO authenticated
  USING (
    assigned_to = auth.uid() 
    OR EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() 
      AND role = 'admin'
    )
  )
  WITH CHECK (
    assigned_to = auth.uid() 
    OR EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() 
      AND role = 'admin'
    )
  );

CREATE POLICY "System can create patrol rounds"
  ON patrol_rounds
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Admin can delete patrol rounds"
  ON patrol_rounds
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() 
      AND role = 'admin'
    )
  );

-- ============================================================================
-- PATROL_SCANS: Clean up and consolidate policies
-- ============================================================================

-- Drop all existing policies
DROP POLICY IF EXISTS "Anyone authenticated can view patrol scans" ON patrol_scans;
DROP POLICY IF EXISTS "Staff can create patrol scans" ON patrol_scans;
DROP POLICY IF EXISTS "Staff can insert patrol scans" ON patrol_scans;
DROP POLICY IF EXISTS "Staff can view all patrol scans" ON patrol_scans;

-- Create new consolidated policies
CREATE POLICY "Everyone can view patrol scans"
  ON patrol_scans
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Staff can create patrol scans"
  ON patrol_scans
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
  );

-- ============================================================================
-- PATROL_LOCATIONS: Clean up and consolidate policies
-- ============================================================================

-- Drop duplicate policies
DROP POLICY IF EXISTS "Admin can view patrol_locations" ON patrol_locations;
DROP POLICY IF EXISTS "Anyone authenticated can view patrol locations" ON patrol_locations;

-- Create single clear policy
CREATE POLICY "Everyone can view patrol locations"
  ON patrol_locations
  FOR SELECT
  TO authenticated
  USING (true);

-- Keep admin management policies (they're fine)
-- "Admin can insert patrol_locations"
-- "Admin can update patrol_locations"
-- "Admin can delete patrol_locations"

-- ============================================================================
-- PATROL_SCHEDULES: Clean up and consolidate policies
-- ============================================================================

-- Drop duplicate policies
DROP POLICY IF EXISTS "Admin can view patrol_schedules" ON patrol_schedules;
DROP POLICY IF EXISTS "Anyone authenticated can view patrol schedules" ON patrol_schedules;

-- Create single clear policy
CREATE POLICY "Everyone can view patrol schedules"
  ON patrol_schedules
  FOR SELECT
  TO authenticated
  USING (true);

-- Keep admin management policies (they're fine)
-- "Admin can insert patrol_schedules"
-- "Admin can update patrol_schedules"
-- "Admin can delete patrol_schedules"