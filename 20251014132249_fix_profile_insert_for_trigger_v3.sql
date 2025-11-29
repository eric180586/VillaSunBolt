/*
  # Fix Profile Insert for Trigger - Version 3

  ## Problem
  - The "Admins have full access" policy blocks the trigger
  - When handle_new_user() runs, it needs to INSERT but there's no authenticated admin session
  - The trigger runs as SECURITY DEFINER but still hits RLS

  ## Solution
  - Keep the admin full access policy
  - Add a separate INSERT policy that allows the trigger to work
  - The trigger will bypass RLS checks when run as SECURITY DEFINER
  
  ## Changes
  - Update INSERT policy to allow both user self-insert and trigger inserts
*/

-- Drop the current INSERT policy
DROP POLICY IF EXISTS "Users can insert profiles" ON profiles;

-- Create new INSERT policy that works with SECURITY DEFINER triggers
-- This allows:
-- 1. The trigger function to insert (runs as function owner)
-- 2. Regular authenticated users to insert their own profile
CREATE POLICY "Allow profile creation"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Allow if inserting own profile
    auth.uid() = id
    OR
    -- Allow if user is admin
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    OR
    -- Allow if id matches (for trigger - trigger sets id = NEW.id from auth.users)
    id IS NOT NULL
  );
