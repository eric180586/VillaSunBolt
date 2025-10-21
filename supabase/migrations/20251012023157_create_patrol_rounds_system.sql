/*
  # Create Patrol Rounds System
  
  1. New Tables
    - `patrol_locations`
      - `id` (uuid, primary key)
      - `name` (text) - Location name
      - `qr_code` (text) - Unique QR code identifier
      - `description` (text) - What to check
      - `order_index` (integer) - Display order
      - `created_at` (timestamptz)
    
    - `patrol_schedules`
      - `id` (uuid, primary key)
      - `date` (date) - The date
      - `shift` (text) - 'early' or 'late'
      - `assigned_to` (uuid) - Staff member assigned
      - `created_by` (uuid) - Admin who assigned
      - `created_at` (timestamptz)
    
    - `patrol_rounds`
      - `id` (uuid, primary key)
      - `date` (date) - The date of the round
      - `time_slot` (time) - Expected time (11:00, 12:15, 13:30, etc.)
      - `assigned_to` (uuid) - Staff member assigned for this day
      - `completed_at` (timestamptz) - When completed
      - `created_at` (timestamptz)
    
    - `patrol_scans`
      - `id` (uuid, primary key)
      - `patrol_round_id` (uuid) - Which round this belongs to
      - `location_id` (uuid) - Which location was scanned
      - `user_id` (uuid) - Who scanned
      - `scanned_at` (timestamptz) - When scanned
      - `photo_url` (text, optional) - Random photo request
      - `photo_requested` (boolean) - Was photo requested
      - `created_at` (timestamptz)
  
  2. Security
    - Enable RLS on all tables
    - All authenticated users can read
    - Staff can create scans
    - Admins can manage schedules
  
  3. Notes
    - Rounds start at 11:00 with 75-minute intervals (±15 min grace period)
    - Time slots: 11:00, 12:15, 13:30, 14:45, 16:00, 17:15, 18:30, 19:45, 21:00
    - +1 point per scan, -1 point per missed scan
    - Random photo requests (30% chance)
*/

CREATE TABLE IF NOT EXISTS patrol_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  qr_code text UNIQUE NOT NULL,
  description text NOT NULL,
  order_index integer NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS patrol_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  date date NOT NULL,
  shift text NOT NULL CHECK (shift IN ('early', 'late')),
  assigned_to uuid REFERENCES profiles(id) ON DELETE CASCADE,
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(date, shift)
);

CREATE TABLE IF NOT EXISTS patrol_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  date date NOT NULL,
  time_slot time NOT NULL,
  assigned_to uuid REFERENCES profiles(id) ON DELETE SET NULL,
  completed_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS patrol_scans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patrol_round_id uuid REFERENCES patrol_rounds(id) ON DELETE CASCADE,
  location_id uuid REFERENCES patrol_locations(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  scanned_at timestamptz DEFAULT now(),
  photo_url text,
  photo_requested boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE patrol_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE patrol_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE patrol_rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE patrol_scans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view patrol locations"
  ON patrol_locations
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can manage patrol locations"
  ON patrol_locations
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Anyone authenticated can view patrol schedules"
  ON patrol_schedules
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can manage patrol schedules"
  ON patrol_schedules
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can update patrol schedules"
  ON patrol_schedules
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

CREATE POLICY "Admins can delete patrol schedules"
  ON patrol_schedules
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Anyone authenticated can view patrol rounds"
  ON patrol_rounds
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "System can create patrol rounds"
  ON patrol_rounds
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "System can update patrol rounds"
  ON patrol_rounds
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Anyone authenticated can view patrol scans"
  ON patrol_scans
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Staff can create patrol scans"
  ON patrol_scans
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_patrol_schedules_date ON patrol_schedules(date);
CREATE INDEX IF NOT EXISTS idx_patrol_rounds_date ON patrol_rounds(date);
CREATE INDEX IF NOT EXISTS idx_patrol_rounds_assigned ON patrol_rounds(assigned_to);
CREATE INDEX IF NOT EXISTS idx_patrol_scans_round ON patrol_scans(patrol_round_id);
CREATE INDEX IF NOT EXISTS idx_patrol_scans_user ON patrol_scans(user_id);

INSERT INTO patrol_locations (name, qr_code, description, order_index) VALUES
  ('Entrance Area', 'PATROL_ENTRANCE_2024', 'Check: Clean and tidy, no trash, no leaves', 1),
  ('Pool Area', 'PATROL_POOL_2024', 'Check: Trash cans empty, no leaves, sun loungers dry and aligned', 2),
  ('Staircase', 'PATROL_STAIRS_2024', 'Check: No insects, no dishes, trash cans empty', 3)
ON CONFLICT (qr_code) DO NOTHING;
