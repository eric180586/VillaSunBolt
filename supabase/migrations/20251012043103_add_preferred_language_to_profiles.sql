/*
  # Add preferred language support to profiles

  ## Changes
  - Add `preferred_language` column to `profiles` table
    - Type: text with constraint for valid language codes
    - Valid values: 'de' (German), 'en' (English), 'km' (Khmer)
    - Default: 'de' (German)
    - Not null constraint
  
  ## Notes
  - Existing users will default to German
  - Users can change their preferred language in their profile settings
  - This enables personalized UI language per user
*/

-- Add preferred_language column to profiles table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'preferred_language'
  ) THEN
    ALTER TABLE profiles 
    ADD COLUMN preferred_language text NOT NULL DEFAULT 'de' 
    CHECK (preferred_language IN ('de', 'en', 'km'));
  END IF;
END $$;