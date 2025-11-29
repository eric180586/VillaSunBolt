/*
  # Create Humor Modules System

  1. New Tables
    - `humor_modules`
      - `id` (uuid, primary key)
      - `name` (text) - Name of the humor module (e.g., "gossip", "cleaning", "tiktok")
      - `label` (text) - Display label for the module
      - `percentage` (integer) - Percentage of daily todo time (e.g., 17 for gossip)
      - `is_active` (boolean) - Whether the module is currently enabled
      - `sort_order` (integer) - Display order
      - `icon_name` (text) - Name of the icon to display
      - `color_class` (text) - Tailwind color class for the module
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on `humor_modules` table
    - Add policy for all authenticated users to read modules
    - Add policy for admin users to manage modules
*/

CREATE TABLE IF NOT EXISTS humor_modules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  label text NOT NULL,
  percentage integer NOT NULL DEFAULT 0,
  is_active boolean DEFAULT false,
  sort_order integer DEFAULT 0,
  icon_name text DEFAULT 'Clock',
  color_class text DEFAULT 'pink',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE humor_modules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read humor modules"
  ON humor_modules
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can insert humor modules"
  ON humor_modules
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can update humor modules"
  ON humor_modules
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

CREATE POLICY "Admins can delete humor modules"
  ON humor_modules
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Insert default humor modules
INSERT INTO humor_modules (name, label, percentage, is_active, sort_order, icon_name, color_class) VALUES
  ('gossip', 'Estimated time for the newest gossip', 17, false, 1, 'MessageCircle', 'pink'),
  ('cleaning', 'Estimated time for "Me clean again"', 13, false, 2, 'Sparkles', 'blue'),
  ('tiktok', 'Estimated time for TikTok', 50, false, 3, 'Smartphone', 'purple')
ON CONFLICT (name) DO NOTHING;
