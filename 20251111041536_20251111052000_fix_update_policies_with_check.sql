/*
  # Fix UPDATE Policies - Add WITH CHECK clauses

  1. Problem
    - Many UPDATE policies have USING but no WITH CHECK
    - This prevents admins from actually modifying data

  2. Solution
    - Add WITH CHECK clauses to all critical UPDATE policies
    - Ensure super_admin has full access

  3. Tables Fixed
    - tasks
    - checklists
    - checklist_instances
    - profiles
    - daily_point_goals
    - shopping_items
*/

-- Tasks: Admin can update
DROP POLICY IF EXISTS "Admin can update tasks" ON tasks;
CREATE POLICY "Admin can update tasks"
  ON tasks FOR UPDATE
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

-- Checklists: Admin can update
DROP POLICY IF EXISTS "Admin can update checklists" ON checklists;
CREATE POLICY "Admin can update checklists"
  ON checklists FOR UPDATE
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

-- Checklist Instances: Admin can update
DROP POLICY IF EXISTS "Admin can update checklist instances" ON checklist_instances;
CREATE POLICY "Admin can update checklist instances"
  ON checklist_instances FOR UPDATE
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

-- Profiles: Admin can update any profile
DROP POLICY IF EXISTS "Admin can update any profile" ON profiles;
CREATE POLICY "Admin can update any profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'super_admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'super_admin')
    )
  );

-- Daily Point Goals: Admin can update
DROP POLICY IF EXISTS "Admin can update daily goals" ON daily_point_goals;
CREATE POLICY "Admin can update daily goals"
  ON daily_point_goals FOR UPDATE
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

-- Shopping Items: Admin can update
DROP POLICY IF EXISTS "Admin can update shopping items" ON shopping_items;
CREATE POLICY "Admin can update shopping items"
  ON shopping_items FOR UPDATE
  TO authenticated
  USING (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  )
  WITH CHECK (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );
