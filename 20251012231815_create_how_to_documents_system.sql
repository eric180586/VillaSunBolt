/*
  # Create How-To Documents System

  1. New Tables
    - `how_to_documents`
      - `id` (uuid, primary key)
      - `title` (text) - Document title
      - `description` (text) - Optional description
      - `file_url` (text) - URL to file in storage
      - `file_type` (text) - pdf, video, image
      - `file_name` (text) - Original filename
      - `file_size` (integer) - File size in bytes
      - `category` (text) - Category for organization
      - `sort_order` (integer) - For custom sorting
      - `created_by` (uuid, FK to auth.users)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Storage
    - Create storage bucket for how-to files
    - Allow authenticated users to read
    - Only admins can upload/delete

  3. Security
    - Enable RLS on how_to_documents
    - All authenticated users can read
    - Only admins can create/update/delete
*/

-- Create how_to_documents table
CREATE TABLE IF NOT EXISTS how_to_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text DEFAULT '',
  file_url text NOT NULL,
  file_type text NOT NULL CHECK (file_type IN ('pdf', 'video', 'image')),
  file_name text NOT NULL,
  file_size integer DEFAULT 0,
  category text DEFAULT 'general',
  sort_order integer DEFAULT 0,
  created_by uuid REFERENCES auth.users(id) NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE how_to_documents ENABLE ROW LEVEL SECURITY;

-- Policies: All authenticated users can read
CREATE POLICY "Authenticated users can view how-to documents"
  ON how_to_documents
  FOR SELECT
  TO authenticated
  USING (true);

-- Only admins can insert
CREATE POLICY "Admins can create how-to documents"
  ON how_to_documents
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Only admins can update
CREATE POLICY "Admins can update how-to documents"
  ON how_to_documents
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Only admins can delete
CREATE POLICY "Admins can delete how-to documents"
  ON how_to_documents
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Create storage bucket for how-to files
INSERT INTO storage.buckets (id, name, public)
VALUES ('how-to-files', 'how-to-files', false)
ON CONFLICT (id) DO NOTHING;

-- Storage policies: Authenticated users can read
CREATE POLICY "Authenticated users can view how-to files"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (bucket_id = 'how-to-files');

-- Only admins can upload
CREATE POLICY "Admins can upload how-to files"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'how-to-files'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Only admins can delete files
CREATE POLICY "Admins can delete how-to files"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'how-to-files'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Index for sorting
CREATE INDEX IF NOT EXISTS how_to_documents_sort_order_idx ON how_to_documents(sort_order, created_at DESC);