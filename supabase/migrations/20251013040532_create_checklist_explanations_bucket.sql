/*
  # Create checklist-explanations storage bucket
  
  ## Changes
  - Create public storage bucket for checklist explanation photos
  - Set up RLS policies for uploading photos
*/

-- Create bucket for checklist explanation photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('checklist-explanations', 'checklist-explanations', true)
ON CONFLICT (id) DO NOTHING;

-- Allow admins to upload photos
CREATE POLICY "Admins can upload checklist explanation photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'checklist-explanations' AND
  (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
);

-- Allow everyone to read photos (public bucket)
CREATE POLICY "Anyone can view checklist explanation photos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'checklist-explanations');

-- Allow admins to delete photos
CREATE POLICY "Admins can delete checklist explanation photos"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'checklist-explanations' AND
  (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
);
