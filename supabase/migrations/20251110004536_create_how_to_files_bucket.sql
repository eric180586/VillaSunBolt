/*
  # Create How-To Files Storage Bucket

  1. Storage
    - Create public bucket for how-to documents
    - Allow authenticated users to upload
    - Allow public read access

  2. Security
    - Admins can upload, update, delete
    - All users can read
*/

-- Create the bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('how-to-files', 'how-to-files', true)
ON CONFLICT (id) DO NOTHING;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Admins can upload how-to files" ON storage.objects;
DROP POLICY IF EXISTS "Admins can update how-to files" ON storage.objects;
DROP POLICY IF EXISTS "Admins can delete how-to files" ON storage.objects;
DROP POLICY IF EXISTS "Public can view how-to files" ON storage.objects;

-- Allow authenticated admins to upload files
CREATE POLICY "Admins can upload how-to files"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'how-to-files' AND
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'admin'
  )
);

-- Allow authenticated admins to update files
CREATE POLICY "Admins can update how-to files"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'how-to-files' AND
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'admin'
  )
);

-- Allow authenticated admins to delete files
CREATE POLICY "Admins can delete how-to files"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'how-to-files' AND
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'admin'
  )
);

-- Allow everyone to read files (public bucket)
CREATE POLICY "Public can view how-to files"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'how-to-files');
