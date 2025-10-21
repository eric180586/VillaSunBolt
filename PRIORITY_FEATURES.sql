-- ============================================================================
-- PRIORITY FEATURES - Villa Sun App
-- ============================================================================
-- Diese Datei enthält die 4 wichtigsten Features:
-- 1. Patrol Rounds System
-- 2. Shopping List System
-- 3. Notes Admin Permissions
-- 4. (How-To wird separat behandelt da sehr groß)
--
-- Anwendung: Kopiere diese Datei komplett in den Supabase SQL Editor
-- ============================================================================

-- ============================================================================
-- 1. PATROL ROUNDS SYSTEM
-- ============================================================================

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
  ON patrol_locations FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage patrol locations"
  ON patrol_locations FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE POLICY "Anyone authenticated can view patrol schedules"
  ON patrol_schedules FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage patrol schedules"
  ON patrol_schedules FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE POLICY "Admins can update patrol schedules"
  ON patrol_schedules FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE POLICY "Admins can delete patrol schedules"
  ON patrol_schedules FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE POLICY "Anyone authenticated can view patrol rounds"
  ON patrol_rounds FOR SELECT TO authenticated USING (true);

CREATE POLICY "System can create patrol rounds"
  ON patrol_rounds FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "System can update patrol rounds"
  ON patrol_rounds FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Anyone authenticated can view patrol scans"
  ON patrol_scans FOR SELECT TO authenticated USING (true);

CREATE POLICY "Staff can create patrol scans"
  ON patrol_scans FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_patrol_schedules_date ON patrol_schedules(date);
CREATE INDEX IF NOT EXISTS idx_patrol_rounds_date ON patrol_rounds(date);
CREATE INDEX IF NOT EXISTS idx_patrol_rounds_assigned ON patrol_rounds(assigned_to);
CREATE INDEX IF NOT EXISTS idx_patrol_scans_round ON patrol_scans(patrol_round_id);
CREATE INDEX IF NOT EXISTS idx_patrol_scans_user ON patrol_scans(user_id);

-- Standard Patrol Locations
INSERT INTO patrol_locations (name, qr_code, description, order_index) VALUES
  ('Entrance Area', 'PATROL_ENTRANCE_2024', 'Check: Clean and tidy, no trash, no leaves', 1),
  ('Pool Area', 'PATROL_POOL_2024', 'Check: Trash cans empty, no leaves, sun loungers dry and aligned', 2),
  ('Staircase', 'PATROL_STAIRS_2024', 'Check: No insects, no dishes, trash cans empty', 3)
ON CONFLICT (qr_code) DO NOTHING;

-- ============================================================================
-- 2. SHOPPING LIST SYSTEM
-- ============================================================================

CREATE TABLE IF NOT EXISTS shopping_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_name text NOT NULL,
  description text,
  photo_url text,
  is_purchased boolean DEFAULT false,
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  purchased_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  purchased_at timestamptz
);

ALTER TABLE shopping_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view shopping items"
  ON shopping_items FOR SELECT TO authenticated USING (true);

CREATE POLICY "Anyone authenticated can add shopping items"
  ON shopping_items FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Anyone authenticated can update shopping items"
  ON shopping_items FOR UPDATE TO authenticated
  USING (true) WITH CHECK (true);

CREATE POLICY "Admins can delete shopping items"
  ON shopping_items FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE INDEX IF NOT EXISTS idx_shopping_items_purchased ON shopping_items(is_purchased);
CREATE INDEX IF NOT EXISTS idx_shopping_items_created_at ON shopping_items(created_at DESC);

-- ============================================================================
-- 3. NOTES ADMIN PERMISSIONS
-- ============================================================================

DROP POLICY IF EXISTS "Users can delete their notes" ON notes;
DROP POLICY IF EXISTS "Users can update their notes" ON notes;

CREATE POLICY "Users and admins can delete notes"
  ON notes FOR DELETE TO authenticated
  USING (
    auth.uid() = created_by OR
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

CREATE POLICY "Users and admins can update notes"
  ON notes FOR UPDATE TO authenticated
  USING (
    auth.uid() = created_by OR
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  )
  WITH CHECK (
    auth.uid() = created_by OR
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
  );

-- ============================================================================
-- DONE! ✅
-- ============================================================================
-- Die folgenden Tabellen wurden erstellt:
-- - patrol_locations (mit 3 Standard-Locations)
-- - patrol_schedules
-- - patrol_rounds
-- - patrol_scans
-- - shopping_items
--
-- Die folgenden Permissions wurden aktualisiert:
-- - notes (Admins können jetzt alle Notizen bearbeiten)
-- ============================================================================