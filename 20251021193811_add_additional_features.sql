/*
  # Add Additional Features
  
  1. New Tables
    - `quiz_highscores` - Track quiz game statistics
    - `tutorial_slides` - Tutorial/how-to slides system
    - `fortune_wheel_spins` - Fortune wheel spin tracking
    - `chat_messages` - Team chat system
    - `how_to_documents` - How-to documentation
    - `motivational_messages` - Daily motivational messages
    - `push_notification_tokens` - Push notification device tokens
    
  2. Storage Buckets
    - tutorial_slides (for comic/tutorial images)
    - chat_photos (for chat attachments)
    
  3. Security
    - RLS enabled on all tables
    - Appropriate access policies
*/

-- Quiz Highscores Table
CREATE TABLE IF NOT EXISTS quiz_highscores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  games_played integer DEFAULT 0,
  games_won integer DEFAULT 0,
  total_points integer DEFAULT 0,
  best_score integer DEFAULT 0,
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE quiz_highscores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view highscores"
  ON quiz_highscores FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can insert their own highscores"
  ON quiz_highscores FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = profile_id);

CREATE POLICY "Users can update their own highscores"
  ON quiz_highscores FOR UPDATE TO authenticated
  USING (auth.uid() = profile_id) WITH CHECK (auth.uid() = profile_id);

-- Tutorial Slides Table
CREATE TABLE IF NOT EXISTS tutorial_slides (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_index integer NOT NULL,
  image_url text NOT NULL,
  title text NOT NULL,
  description text,
  category text DEFAULT 'general',
  tips jsonb DEFAULT '[]'::jsonb,
  created_at timestamptz DEFAULT now(),
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL
);

ALTER TABLE tutorial_slides ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view tutorial slides"
  ON tutorial_slides FOR SELECT USING (true);

CREATE POLICY "Admins can manage tutorial slides"
  ON tutorial_slides FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

CREATE INDEX IF NOT EXISTS idx_tutorial_slides_order ON tutorial_slides(order_index);

-- Fortune Wheel Spins Table
CREATE TABLE IF NOT EXISTS fortune_wheel_spins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  check_in_id uuid REFERENCES check_ins(id) ON DELETE CASCADE,
  spin_date date NOT NULL DEFAULT CURRENT_DATE,
  reward_type text NOT NULL,
  reward_value integer NOT NULL,
  reward_label text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, spin_date)
);

ALTER TABLE fortune_wheel_spins ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own spins"
  ON fortune_wheel_spins FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create own spins"
  ON fortune_wheel_spins FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all spins"
  ON fortune_wheel_spins FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

-- Chat Messages Table
CREATE TABLE IF NOT EXISTS chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  message text NOT NULL,
  photo_url text,
  created_at timestamptz DEFAULT now(),
  is_deleted boolean DEFAULT false
);

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view messages"
  ON chat_messages FOR SELECT TO authenticated
  USING (NOT is_deleted OR sender_id = auth.uid());

CREATE POLICY "Users can send messages"
  ON chat_messages FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can delete own messages"
  ON chat_messages FOR UPDATE TO authenticated
  USING (auth.uid() = sender_id)
  WITH CHECK (auth.uid() = sender_id);

-- How-To Documents Table
CREATE TABLE IF NOT EXISTS how_to_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  content text NOT NULL,
  category text DEFAULT 'general',
  order_index integer DEFAULT 0,
  is_published boolean DEFAULT true,
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE how_to_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view how-to documents"
  ON how_to_documents FOR SELECT TO authenticated
  USING (is_published = true);

CREATE POLICY "Admins can manage how-to documents"
  ON how_to_documents FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

-- Motivational Messages Table
CREATE TABLE IF NOT EXISTS motivational_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message text NOT NULL,
  language text DEFAULT 'de' CHECK (language IN ('de', 'en', 'km')),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE motivational_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view motivational messages"
  ON motivational_messages FOR SELECT TO authenticated
  USING (is_active = true);

CREATE POLICY "Admins can manage motivational messages"
  ON motivational_messages FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

-- Push Notification Tokens Table
CREATE TABLE IF NOT EXISTS push_notification_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  token text NOT NULL UNIQUE,
  device_type text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE push_notification_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own tokens"
  ON push_notification_tokens FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Storage Buckets
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('tutorial_slides', 'tutorial_slides', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']::text[]),
  ('chat_photos', 'chat_photos', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']::text[])
ON CONFLICT (id) DO NOTHING;

-- Storage Policies for tutorial_slides
CREATE POLICY "Anyone can view tutorial slide images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'tutorial_slides');

CREATE POLICY "Admins can upload tutorial slide images"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'tutorial_slides'
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

-- Storage Policies for chat_photos
CREATE POLICY "Anyone can view chat photos"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'chat_photos');

CREATE POLICY "Users can upload chat photos"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'chat_photos' AND auth.uid() IS NOT NULL);

-- Insert sample motivational messages
INSERT INTO motivational_messages (message, language, is_active) VALUES
  ('Du schaffst das! Weiter so!', 'de', true),
  ('Jeder Tag ist eine neue Chance!', 'de', true),
  ('You are doing great! Keep it up!', 'en', true),
  ('Every day is a new opportunity!', 'en', true)
ON CONFLICT DO NOTHING;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_chat_messages_created ON chat_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fortune_wheel_spins_date ON fortune_wheel_spins(spin_date);
CREATE INDEX IF NOT EXISTS idx_how_to_documents_category ON how_to_documents(category);
