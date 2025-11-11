/*
  # Add Missing DELETE Policies for Admin Tables

  1. Updates
    - Add DELETE policies for tables that admins need to manage
    - Ensure super_admin has full access

  2. Tables Updated
    - humor_modules: Admin can delete
    - patrol_locations: Admin can delete
    - patrol_schedules: Admin can delete
    - how_to_documents: Admin can delete
    - how_to_steps: Admin can delete
    - tutorial_slides: Admin can delete
    - shopping_items: Admin can delete
    - patrol_rounds: Admin can delete
*/

-- Humor Modules: Admin can delete
DROP POLICY IF EXISTS "Admin can delete humor modules" ON humor_modules;
CREATE POLICY "Admin can delete humor modules"
  ON humor_modules FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- Patrol Locations: Admin can delete
DROP POLICY IF EXISTS "Admin can delete patrol locations" ON patrol_locations;
CREATE POLICY "Admin can delete patrol locations"
  ON patrol_locations FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- Patrol Schedules: Admin can delete
DROP POLICY IF EXISTS "Admin can delete patrol schedules" ON patrol_schedules;
CREATE POLICY "Admin can delete patrol schedules"
  ON patrol_schedules FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- How-To Documents: Admin can delete
DROP POLICY IF EXISTS "Admin can delete how-to documents" ON how_to_documents;
CREATE POLICY "Admin can delete how-to documents"
  ON how_to_documents FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- How-To Steps: Admin can delete
DROP POLICY IF EXISTS "Admin can delete how-to steps" ON how_to_steps;
CREATE POLICY "Admin can delete how-to steps"
  ON how_to_steps FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- Tutorial Slides: Admin can delete
DROP POLICY IF EXISTS "Admin can delete tutorial slides" ON tutorial_slides;
CREATE POLICY "Admin can delete tutorial slides"
  ON tutorial_slides FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- Shopping Items: Admin can delete
DROP POLICY IF EXISTS "Admin can delete shopping items" ON shopping_items;
CREATE POLICY "Admin can delete shopping items"
  ON shopping_items FOR DELETE
  TO authenticated
  USING (
    auth.uid() = created_by
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- Patrol Rounds: Admin can delete
DROP POLICY IF EXISTS "Admin can delete patrol rounds" ON patrol_rounds;
CREATE POLICY "Admin can delete patrol rounds"
  ON patrol_rounds FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );
