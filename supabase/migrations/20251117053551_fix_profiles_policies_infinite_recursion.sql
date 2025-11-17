/*
  # Fix profiles policies to prevent infinite recursion
  
  1. Problem
    - Policies created with "FOR ALL" apply to SELECT queries too
    - This causes infinite recursion when checking "EXISTS (SELECT FROM profiles WHERE role = admin)"
    
  2. Solution
    - Drop all incorrectly created ALL policies
    - Recreate with specific commands (INSERT, UPDATE, DELETE)
    - Keep SELECT policy simple (no subquery on profiles table)
  
  3. Security
    - All users can view all profiles (needed for app functionality)
    - Only users can update their own profile
    - Only admins can create/update/delete any profile
*/

-- Drop problematic policies
DROP POLICY IF EXISTS "Admin can create profiles" ON profiles;
DROP POLICY IF EXISTS "Admin can update any profile" ON profiles;
DROP POLICY IF EXISTS "Super admin can delete profiles" ON profiles;

-- Recreate INSERT policy for admins
CREATE POLICY "Admin can insert profiles"
  ON profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- Recreate UPDATE policy for admins
CREATE POLICY "Admin can update all profiles"
  ON profiles
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- Recreate DELETE policy for admins
CREATE POLICY "Admin can delete profiles"
  ON profiles
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );
