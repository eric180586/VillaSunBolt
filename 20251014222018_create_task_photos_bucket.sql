/*
  # Create task-photos Storage Bucket
  
  ## Problem:
  - Staff kann Tasks nicht abschließen wenn Foto erforderlich ist
  - Upload schlägt fehl: Bucket 'task-photos' existiert nicht
  - Code versucht in nicht-existenten Bucket zu schreiben
  
  ## Lösung:
  1. Erstelle 'task-photos' Storage Bucket
  2. Setze Bucket als PUBLIC (Fotos müssen sichtbar sein)
  3. RLS Policies für sichere Uploads:
     - INSERT: Authenticated users können Fotos hochladen
     - SELECT: Alle können Fotos ansehen (public)
     - DELETE: Nur Admins können Fotos löschen
  
  ## Verwendung:
  - Task completion photos (photo_proof)
  - Task description photos (description_photo)
  - Task explanation photos (explanation_photo)
  - Admin review photos (admin_photo)
  - Checklist proof photos (photo_proof)
*/

-- ==========================================
-- 1. CREATE STORAGE BUCKET
-- ==========================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'task-photos',
  'task-photos',
  true,
  10485760, -- 10MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- ==========================================
-- 2. RLS POLICIES
-- ==========================================

-- Allow authenticated users to upload photos
CREATE POLICY "Authenticated users can upload task photos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'task-photos');

-- Allow everyone to view task photos (public bucket)
CREATE POLICY "Anyone can view task photos"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'task-photos');

-- Allow admins to delete task photos
CREATE POLICY "Admins can delete task photos"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'task-photos'
  AND (
    SELECT role FROM profiles WHERE id = auth.uid()
  ) = 'admin'
);

-- ==========================================
-- 3. VERIFICATION
-- ==========================================

-- Verify bucket exists
SELECT 
  '✅ Bucket created' as status,
  name,
  public,
  file_size_limit / 1024 / 1024 as size_limit_mb
FROM storage.buckets
WHERE name = 'task-photos';

-- Verify policies exist
SELECT 
  '✅ Policies created' as status,
  COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'storage'
AND tablename = 'objects'
AND policyname ILIKE '%task%photo%';
