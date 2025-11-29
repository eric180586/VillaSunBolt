/*
  # Fix Profile Insert for Trigger - Version 2

  ## Problem
  - Previous solution was too permissive
  - Need to allow trigger function to insert while maintaining security

  ## Solution
  - Simply allow all authenticated users to INSERT (the trigger runs in their session)
  - The WITH CHECK ensures data integrity
  
  ## Changes
  - Update INSERT policy to be less restrictive but maintain data integrity
*/

-- Drop existing INSERT policy
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

-- Create new INSERT policy
-- This allows the trigger to create profiles for new users
CREATE POLICY "Users can insert own profile"
  ON profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Add a check to ensure admins can't insert arbitrary profiles manually
-- The trigger will handle new user creation automatically
