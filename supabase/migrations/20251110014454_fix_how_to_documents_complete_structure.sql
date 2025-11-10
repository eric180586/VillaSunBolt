/*
  # Fix how_to_documents table - Add all missing columns
  
  1. Changes
    - Add `file_url` (text, required)
    - Add `file_type` (text, required - 'pdf', 'video', or 'image')
    - Add `file_name` (text, required)
    - Add `file_size` (bigint, required)
    
  2. Security
    - No changes to existing RLS policies
*/

-- Add file_url column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'how_to_documents' AND column_name = 'file_url'
  ) THEN
    ALTER TABLE how_to_documents ADD COLUMN file_url text NOT NULL DEFAULT '';
  END IF;
END $$;

-- Add file_type column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'how_to_documents' AND column_name = 'file_type'
  ) THEN
    ALTER TABLE how_to_documents ADD COLUMN file_type text NOT NULL DEFAULT 'pdf';
  END IF;
END $$;

-- Add file_name column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'how_to_documents' AND column_name = 'file_name'
  ) THEN
    ALTER TABLE how_to_documents ADD COLUMN file_name text NOT NULL DEFAULT '';
  END IF;
END $$;

-- Add file_size column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'how_to_documents' AND column_name = 'file_size'
  ) THEN
    ALTER TABLE how_to_documents ADD COLUMN file_size bigint NOT NULL DEFAULT 0;
  END IF;
END $$;