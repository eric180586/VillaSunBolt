/*
  # Fix Storage Policies for Super Admin

  1. Problem
    - Storage policies only check for 'admin', not 'super_admin'
    - This blocks super_admin from uploading/managing files

  2. Solution
    - Update all storage policies to include super_admin
    - Add WITH CHECK where missing
*/

-- How-To Files: Upload (INSERT)
DROP POLICY IF EXISTS "Admins can upload how-to files" ON storage.objects;
CREATE POLICY "Admins can upload how-to files"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'how-to-files'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- How-To Files: Update
DROP POLICY IF EXISTS "Admins can update how-to files" ON storage.objects;
CREATE POLICY "Admins can update how-to files"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'how-to-files'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  )
  WITH CHECK (
    bucket_id = 'how-to-files'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );

-- How-To Files: Delete
DROP POLICY IF EXISTS "Admins can delete how-to files" ON storage.objects;
CREATE POLICY "Admins can delete how-to files"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'how-to-files'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'super_admin')
    )
  );
