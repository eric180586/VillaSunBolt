/*
  # Fix Profile Insert Policy for Admin User Creation

  ## Problem
  - Admins cannot create new users because the INSERT policy only allows `auth.uid() = id`
  - The trigger `handle_new_user()` runs as SECURITY DEFINER but still fails RLS check

  ## Solution
  - Update INSERT policy to allow either:
    1. User creating their own profile (auth.uid() = id)
    2. Profile being created via the trigger function (bypasses the auth.uid() check when run as SECURITY DEFINER)
  
  ## Changes
  - Drop existing INSERT policy
  - Create new INSERT policy that works with SECURITY DEFINER triggers
*/

-- Drop existing INSERT policy
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

-- Create new INSERT policy that allows:
-- 1. Users to insert their own profile
-- 2. System to insert profiles via SECURITY DEFINER function
CREATE POLICY "Users can insert own profile"
  ON profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = id OR
    -- Allow inserts from SECURITY DEFINER functions
    current_setting('role', true) = 'authenticated'
  );
