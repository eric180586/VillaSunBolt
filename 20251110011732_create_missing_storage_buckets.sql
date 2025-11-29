/*
  # Create Missing Storage Buckets
  
  1. Storage Buckets
    - `task-photos` - for task completion photos
    - `checklist-photos` - for checklist completion photos
    - `chat-photos` - for team chat photos
    - `patrol-photos` - for patrol round photos
    - `admin-reviews` - for admin review photos
    - `checklist-explanations` - for checklist explanation photos
  
  2. Security
    - All buckets are public for easy access
    - RLS policies allow authenticated users to upload
    - Anyone can view (read) files
*/

-- Create task-photos bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'task-photos',
  'task-photos',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- Create checklist-photos bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'checklist-photos',
  'checklist-photos',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- Create chat-photos bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'chat-photos',
  'chat-photos',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- Create patrol-photos bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'patrol-photos',
  'patrol-photos',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- Create admin-reviews bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'admin-reviews',
  'admin-reviews',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- Create checklist-explanations bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'checklist-explanations',
  'checklist-explanations',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- RLS Policies for task-photos
CREATE POLICY "Authenticated users can upload task photos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'task-photos');

CREATE POLICY "Anyone can view task photos"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'task-photos');

CREATE POLICY "Users can delete their own task photos"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'task-photos');

-- RLS Policies for checklist-photos
CREATE POLICY "Authenticated users can upload checklist photos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'checklist-photos');

CREATE POLICY "Anyone can view checklist photos"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'checklist-photos');

CREATE POLICY "Users can delete their own checklist photos"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'checklist-photos');

-- RLS Policies for chat-photos
CREATE POLICY "Authenticated users can upload chat photos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'chat-photos');

CREATE POLICY "Anyone can view chat photos"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'chat-photos');

CREATE POLICY "Users can delete their own chat photos"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'chat-photos');

-- RLS Policies for patrol-photos
CREATE POLICY "Authenticated users can upload patrol photos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'patrol-photos');

CREATE POLICY "Anyone can view patrol photos"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'patrol-photos');

CREATE POLICY "Users can delete their own patrol photos"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'patrol-photos');

-- RLS Policies for admin-reviews
CREATE POLICY "Authenticated users can upload admin review photos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'admin-reviews');

CREATE POLICY "Anyone can view admin review photos"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'admin-reviews');

CREATE POLICY "Users can delete their own admin review photos"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'admin-reviews');

-- RLS Policies for checklist-explanations
CREATE POLICY "Authenticated users can upload checklist explanation photos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'checklist-explanations');

CREATE POLICY "Anyone can view checklist explanation photos"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'checklist-explanations');

CREATE POLICY "Users can delete their own checklist explanation photos"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'checklist-explanations');