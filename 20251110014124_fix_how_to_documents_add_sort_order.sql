/*
  # Fix how_to_documents table - Add missing sort_order column
  
  1. Changes
    - Add `sort_order` column (integer, default 0)
    - Add `file_paths` column (jsonb array for multiple files)
    
  2. Security
    - No changes to existing RLS policies
*/

-- Add sort_order column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'how_to_documents' AND column_name = 'sort_order'
  ) THEN
    ALTER TABLE how_to_documents ADD COLUMN sort_order integer DEFAULT 0;
  END IF;
END $$;

-- Add file_paths column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'how_to_documents' AND column_name = 'file_paths'
  ) THEN
    ALTER TABLE how_to_documents ADD COLUMN file_paths jsonb DEFAULT '[]'::jsonb;
  END IF;
END $$;