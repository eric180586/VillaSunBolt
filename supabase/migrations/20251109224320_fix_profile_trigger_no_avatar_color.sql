/*
  # Fix Profile Creation Trigger - Remove avatar_color

  1. Changes
    - Update handle_new_user function to not use avatar_color
    - Use only columns that exist in profiles table

  2. Notes
    - Profiles table has: id, email, full_name, role, avatar_url, total_points, created_at, updated_at, preferred_language
*/

-- Update function to handle profile creation without avatar_color
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'staff')
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = COALESCE(EXCLUDED.full_name, profiles.full_name),
    role = COALESCE(EXCLUDED.role, profiles.role);
  
  RETURN NEW;
END;
$$;
