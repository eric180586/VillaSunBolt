/*
  # Remove Super Admin Role

  1. Changes
    - Update all storage policies to only use 'admin' role
    - Remove 'super_admin' from all IN clauses
    
  2. Security
    - Maintain same access control, just with 'admin' role only
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
      AND profiles.role = 'admin'
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
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    bucket_id = 'how-to-files'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
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
      AND profiles.role = 'admin'
    )
  );

-- Task Photos: Upload (INSERT)
DROP POLICY IF EXISTS "Admins can upload task photos" ON storage.objects;
CREATE POLICY "Admins can upload task photos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'task-photos'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Task Photos: Update
DROP POLICY IF EXISTS "Admins can update task photos" ON storage.objects;
CREATE POLICY "Admins can update task photos"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'task-photos'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    bucket_id = 'task-photos'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Task Photos: Delete
DROP POLICY IF EXISTS "Admins can delete task photos" ON storage.objects;
CREATE POLICY "Admins can delete task photos"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'task-photos'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Admin Reviews: Upload (INSERT)
DROP POLICY IF EXISTS "Admins can upload admin reviews" ON storage.objects;
CREATE POLICY "Admins can upload admin reviews"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'admin-reviews'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Admin Reviews: Update
DROP POLICY IF EXISTS "Admins can update admin reviews" ON storage.objects;
CREATE POLICY "Admins can update admin reviews"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'admin-reviews'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    bucket_id = 'admin-reviews'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Admin Reviews: Delete
DROP POLICY IF EXISTS "Admins can delete admin reviews" ON storage.objects;
CREATE POLICY "Admins can delete admin reviews"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'admin-reviews'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Chat Photos: Upload (INSERT)
DROP POLICY IF EXISTS "Admins can upload chat photos" ON storage.objects;
CREATE POLICY "Admins can upload chat photos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'chat-photos'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Chat Photos: Update
DROP POLICY IF EXISTS "Admins can update chat photos" ON storage.objects;
CREATE POLICY "Admins can update chat photos"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'chat-photos'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    bucket_id = 'chat-photos'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Chat Photos: Delete
DROP POLICY IF EXISTS "Admins can delete chat photos" ON storage.objects;
CREATE POLICY "Admins can delete chat photos"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'chat-photos'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );
