/*
  # Add Missing UPDATE Policies for Admin Tables

  1. Updates
    - Add UPDATE policies for tables that admins need to edit
    - Ensure super_admin has full access

  2. Tables Updated
    - humor_modules: Admin can update
    - patrol_locations: Admin can update
    - patrol_schedules: Admin can update
    - how_to_documents: Admin can update
    - how_to_steps: Admin can update
    - tutorial_slides: Admin can update
    - patrol_rounds: Staff can update own, admin can update all
*/

-- Humor Modules: Admin can update
DROP POLICY IF EXISTS "Admin can update humor modules" ON humor_modules;
CREATE POLICY "Admin can update humor modules"
  ON humor_modules FOR UPDATE
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

-- Patrol Locations: Admin can update
DROP POLICY IF EXISTS "Admin can update patrol locations" ON patrol_locations;
CREATE POLICY "Admin can update patrol locations"
  ON patrol_locations FOR UPDATE
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

-- Patrol Schedules: Admin can update
DROP POLICY IF EXISTS "Admin can update patrol schedules" ON patrol_schedules;
CREATE POLICY "Admin can update patrol schedules"
  ON patrol_schedules FOR UPDATE
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

-- How-To Documents: Admin can update
DROP POLICY IF EXISTS "Admin can update how-to documents" ON how_to_documents;
CREATE POLICY "Admin can update how-to documents"
  ON how_to_documents FOR UPDATE
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

-- How-To Steps: Admin can update
DROP POLICY IF EXISTS "Admin can update how-to steps" ON how_to_steps;
CREATE POLICY "Admin can update how-to steps"
  ON how_to_steps FOR UPDATE
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

-- Tutorial Slides: Admin can update
DROP POLICY IF EXISTS "Admin can update tutorial slides" ON tutorial_slides;
CREATE POLICY "Admin can update tutorial slides"
  ON tutorial_slides FOR UPDATE
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

-- Patrol Rounds: Staff can update their own rounds, admin can update all
DROP POLICY IF EXISTS "Users can update own patrol rounds" ON patrol_rounds;
CREATE POLICY "Users can update own patrol rounds"
  ON patrol_rounds FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = assigned_to
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  )
  WITH CHECK (
    auth.uid() = assigned_to
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );
