/*
  # Create Tutorial Slides System (Cleaning Guide / Sunny's Comic Tutorial)

  ## Problems Being Fixed:
  1. tutorial_slides table doesn't exist
  2. tutorial_slides storage bucket doesn't exist
  3. Images can't be uploaded or loaded
  4. Missing slide 6 (needs to be added manually after bucket creation)

  ## What This Creates:

  1. **New Table: tutorial_slides**
     - `id` (uuid, primary key)
     - `order_index` (integer) - Slide order (0, 1, 2, ...)
     - `image_url` (text) - URL to comic/image in storage
     - `title` (text) - Slide title
     - `description` (text, optional) - Additional explanation
     - `created_at` (timestamptz)
     - `created_by` (uuid) - Admin who created it

  2. **Storage Bucket: tutorial_slides**
     - Public bucket for comic images
     - Admins can upload
     - Everyone can view

  3. **Security**
     - Enable RLS on table
     - Everyone can view slides
     - Only admins can create/update/delete
*/

-- ============================================================================
-- 1. UPDATE EXISTING TABLE (table already exists from previous manual creation)
-- ============================================================================

-- The table already exists with: id, title, image_url, description, order_index, category, tips, created_at
-- We only need to add the created_by column if it doesn't exist

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tutorial_slides' AND column_name = 'created_by'
  ) THEN
    ALTER TABLE tutorial_slides ADD COLUMN created_by uuid REFERENCES profiles(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Create index for ordering if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_tutorial_slides_order ON tutorial_slides(order_index);

-- ============================================================================
-- 2. ENABLE RLS
-- ============================================================================
ALTER TABLE tutorial_slides ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 3. RLS POLICIES
-- ============================================================================

-- Everyone (including unauthenticated) can view slides
CREATE POLICY "Anyone can view tutorial slides"
  ON tutorial_slides
  FOR SELECT
  USING (true);

-- Only admins can insert slides
CREATE POLICY "Admins can insert tutorial slides"
  ON tutorial_slides
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Only admins can update slides
CREATE POLICY "Admins can update tutorial slides"
  ON tutorial_slides
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

-- Only admins can delete slides
CREATE POLICY "Admins can delete tutorial slides"
  ON tutorial_slides
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- ============================================================================
-- 4. CREATE STORAGE BUCKET
-- ============================================================================

-- Insert bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'tutorial_slides',
  'tutorial_slides',
  true,
  10485760, -- 10MB limit
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']::text[]
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 5. STORAGE BUCKET POLICIES
-- ============================================================================

-- Everyone can view images (public bucket)
CREATE POLICY "Anyone can view tutorial slide images"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'tutorial_slides');

-- Only admins can upload images
CREATE POLICY "Admins can upload tutorial slide images"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'tutorial_slides'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Only admins can update images
CREATE POLICY "Admins can update tutorial slide images"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'tutorial_slides'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    bucket_id = 'tutorial_slides'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Only admins can delete images
CREATE POLICY "Admins can delete tutorial slide images"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'tutorial_slides'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- ============================================================================
-- 6. SAMPLE DATA (Optional - for testing)
-- ============================================================================

/*
-- You can insert sample slides like this:
INSERT INTO tutorial_slides (title, description, image_url, order_index) VALUES
  ('Welcome to Sunny''s Cleaning Guide!', 'Learn the proper way to clean rooms at Villa Sun', 'https://example.com/slide1.jpg', 0),
  ('Step 1: Preparation', 'Gather all cleaning supplies', 'https://example.com/slide2.jpg', 1),
  ('Step 2: Dusting', 'Start from top to bottom', 'https://example.com/slide3.jpg', 2),
  ('Step 3: Bathroom Cleaning', 'Clean toilet, shower, and sink', 'https://example.com/slide4.jpg', 3),
  ('Step 4: Floor Cleaning', 'Vacuum and mop the floor', 'https://example.com/slide5.jpg', 4),
  ('Step 5: Final Check', 'Check everything is perfect!', 'https://example.com/slide6.jpg', 5);
*/

-- ============================================================================
-- VALIDATION QUERIES
-- ============================================================================

/*
-- Test 1: Check if table exists and is empty
SELECT COUNT(*) as slide_count FROM tutorial_slides;

-- Test 2: Check if bucket exists
SELECT * FROM storage.buckets WHERE id = 'tutorial_slides';

-- Test 3: Check RLS policies
SELECT schemaname, tablename, policyname, roles, cmd
FROM pg_policies
WHERE tablename = 'tutorial_slides';

-- Test 4: Check storage policies
SELECT name, definition
FROM pg_policies
WHERE tablename = 'objects'
AND definition LIKE '%tutorial_slides%';
*/
