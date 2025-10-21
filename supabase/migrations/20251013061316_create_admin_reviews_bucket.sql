/*
  # Create admin-reviews storage bucket
  
  ## Changes:
  1. Creates 'admin-reviews' bucket for admin photos during task/checklist rejection
  2. Sets bucket as public
  3. Adds RLS policies:
     - Admins can upload photos
     - Everyone (authenticated) can view photos
     - Admins can delete photos
*/

-- Create bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('admin-reviews', 'admin-reviews', true)
ON CONFLICT (id) DO NOTHING;

-- Policy: Admins can upload
CREATE POLICY "Admins can upload admin review photos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'admin-reviews'
  AND (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
);

-- Policy: Everyone can view
CREATE POLICY "Everyone can view admin review photos"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'admin-reviews');

-- Policy: Admins can delete
CREATE POLICY "Admins can delete admin review photos"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'admin-reviews'
  AND (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
);
