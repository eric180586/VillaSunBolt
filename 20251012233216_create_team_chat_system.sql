/*
  # Create Team Chat System

  1. New Tables
    - `chat_messages`
      - `id` (uuid, primary key)
      - `user_id` (uuid, FK to auth.users) - Message sender
      - `message` (text) - Original message text
      - `message_de` (text) - German translation
      - `message_km` (text) - Khmer translation
      - `photo_url` (text) - Optional photo URL
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Storage
    - Create storage bucket for chat photos
    - All authenticated users can upload/read

  3. Security
    - Enable RLS on chat_messages
    - All authenticated users can read all messages
    - All authenticated users can insert messages
    - Users can only update/delete their own messages

  4. Real-time
    - Enable real-time updates for chat_messages table
*/

-- Create chat_messages table
CREATE TABLE IF NOT EXISTS chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) NOT NULL,
  message text NOT NULL,
  message_de text DEFAULT '',
  message_km text DEFAULT '',
  photo_url text DEFAULT null,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read all messages
CREATE POLICY "Authenticated users can read all chat messages"
  ON chat_messages
  FOR SELECT
  TO authenticated
  USING (true);

-- All authenticated users can send messages
CREATE POLICY "Authenticated users can send chat messages"
  ON chat_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can update only their own messages (for edits)
CREATE POLICY "Users can update own chat messages"
  ON chat_messages
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete only their own messages
CREATE POLICY "Users can delete own chat messages"
  ON chat_messages
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Create storage bucket for chat photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-photos', 'chat-photos', false)
ON CONFLICT (id) DO NOTHING;

-- All authenticated users can read chat photos
CREATE POLICY "Authenticated users can view chat photos"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (bucket_id = 'chat-photos');

-- All authenticated users can upload chat photos
CREATE POLICY "Authenticated users can upload chat photos"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'chat-photos');

-- Users can delete their own chat photos
CREATE POLICY "Users can delete own chat photos"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (bucket_id = 'chat-photos' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Index for efficient message retrieval
CREATE INDEX IF NOT EXISTS chat_messages_created_at_idx ON chat_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS chat_messages_user_id_idx ON chat_messages(user_id);

-- Enable real-time for chat_messages
ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;