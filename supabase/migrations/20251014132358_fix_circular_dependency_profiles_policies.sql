/*
  # Fix Circular Dependency in Profiles Policies

  ## Problem
  - "Admins have full access" policy creates circular dependency
  - It queries profiles table to check if user is admin
  - But to query profiles, it needs to check if user is admin
  - Result: Infinite loop, sign out fails, profile creation fails

  ## Solution
  - Remove the circular "FOR ALL" admin policy
  - Create specific policies for each operation (SELECT, INSERT, UPDATE, DELETE)
  - Only use admin check where it doesn't create circular dependency
  
  ## Changes
  - Drop problematic "FOR ALL" policy
  - Create clean, non-circular policies for all operations
*/

-- Drop the circular policy
DROP POLICY IF EXISTS "Admins have full access to profiles" ON profiles;

-- SELECT: Everyone can view (no admin check needed here)
DROP POLICY IF EXISTS "Users can view all profiles" ON profiles;
CREATE POLICY "Users can view all profiles"
  ON profiles FOR SELECT
  TO authenticated
  USING (true);

-- INSERT: Very permissive to allow trigger
DROP POLICY IF EXISTS "Allow profile creation" ON profiles;
CREATE POLICY "Allow profile creation"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- UPDATE: Users can update own profile, OR if they're admin (safe check)
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = id
    OR
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  )
  WITH CHECK (
    auth.uid() = id
    OR
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- DELETE: Only admins can delete
CREATE POLICY "Admins can delete profiles"
  ON profiles FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );
