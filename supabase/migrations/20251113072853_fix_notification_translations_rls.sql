/*
  # Fix notification_translations RLS

  ## Security Issue
  - notification_translations table has RLS disabled (security vulnerability)

  ## Changes
  - Enable RLS on notification_translations
  - Add read-only policy for authenticated users
*/

-- Enable RLS
ALTER TABLE notification_translations ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read translations (read-only data)
CREATE POLICY "Anyone can read notification translations"
  ON notification_translations
  FOR SELECT
  TO authenticated
  USING (true);

-- Only admins can modify translations
CREATE POLICY "Admins can manage notification translations"
  ON notification_translations
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );
