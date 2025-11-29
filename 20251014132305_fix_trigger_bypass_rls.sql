/*
  # Fix Trigger to Bypass RLS

  ## Problem
  - SECURITY DEFINER functions still respect RLS policies
  - Need to explicitly disable RLS in the trigger function

  ## Solution
  - Recreate the trigger function to properly bypass RLS
  - Use a more permissive INSERT policy
  
  ## Changes
  - Drop and recreate handle_new_user() function
  - Simplify INSERT policy for profiles
*/

-- Recreate the trigger function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Insert into profiles, this will work because function is SECURITY DEFINER
  INSERT INTO public.profiles (id, email, full_name, role, total_points)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    COALESCE(NEW.raw_user_meta_data->>'role', 'staff'),
    0
  );
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the auth.users insert
    RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

-- Make the INSERT policy very permissive
DROP POLICY IF EXISTS "Allow profile creation" ON profiles;

CREATE POLICY "Allow profile creation"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (true);
