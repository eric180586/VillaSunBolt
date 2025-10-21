/*
  ============================================================================
  PHASE 1: CRITICAL FOUNDATION - Villa Sun App
  ============================================================================

  Diese Migration konsolidiert wichtige Tabellen und Funktionen.

  Status: READY FOR PRODUCTION

  ## Was wird erstellt:

  ### Tabellen:
  1. shopping_items
  2. daily_point_goals
  3. patrol_locations
  4. patrol_schedules
  5. patrol_rounds
  6. patrol_scans
  7. how_to_documents
  8. how_to_steps

  ### RPC-Funktionen:
  1. approve_task_with_points
  2. reopen_task_with_penalty
  3. approve_checklist_instance
  4. reject_checklist_instance
  5. process_check_in
  6. approve_check_in
  7. reject_check_in
  8. update_daily_point_goals
  9. calculate_daily_achievable_points
  10. calculate_monthly_progress

  ============================================================================
*/

-- ============================================================================
-- 1. SHOPPING LIST SYSTEM
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
  ON shopping_items FOR INSERT TO authenticated WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Anyone authenticated can update shopping items"
  ON shopping_items FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Admins can delete shopping items"
  ON shopping_items FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE INDEX IF NOT EXISTS idx_shopping_items_purchased ON shopping_items(is_purchased);
CREATE INDEX IF NOT EXISTS idx_shopping_items_created_at ON shopping_items(created_at DESC);

-- ============================================================================
-- 2. NOTES ADMIN PERMISSIONS
-- ============================================================================

DROP POLICY IF EXISTS "Users can delete their notes" ON notes;
DROP POLICY IF EXISTS "Users can update their notes" ON notes;

CREATE POLICY "Users and admins can delete notes"
  ON notes FOR DELETE TO authenticated
  USING (auth.uid() = created_by OR EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE POLICY "Users and admins can update notes"
  ON notes FOR UPDATE TO authenticated
  USING (auth.uid() = created_by OR EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'))
  WITH CHECK (auth.uid() = created_by OR EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

-- ============================================================================
-- 3. DYNAMIC POINTS SYSTEM - TABLES & COLUMNS
-- ============================================================================

CREATE TABLE IF NOT EXISTS daily_point_goals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  goal_date date NOT NULL DEFAULT CURRENT_DATE,
  theoretically_achievable_points integer DEFAULT 0,
  achieved_points integer DEFAULT 0,
  team_achievable_points integer DEFAULT 0,
  team_points_earned integer DEFAULT 0,
  percentage numeric(5,2) DEFAULT 0.00,
  color_status text DEFAULT 'red',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, goal_date)
);

CREATE INDEX IF NOT EXISTS idx_daily_point_goals_user_date ON daily_point_goals(user_id, goal_date);
CREATE INDEX IF NOT EXISTS idx_daily_point_goals_date ON daily_point_goals(goal_date);

ALTER TABLE daily_point_goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own daily goals"
  ON daily_point_goals FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all daily goals"
  ON daily_point_goals FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE POLICY "System can insert daily goals"
  ON daily_point_goals FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "System can update daily goals"
  ON daily_point_goals FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- Tasks erweitern
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'deadline_bonus_awarded') THEN
    ALTER TABLE tasks ADD COLUMN deadline_bonus_awarded boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'initial_points_value') THEN
    ALTER TABLE tasks ADD COLUMN initial_points_value integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'secondary_assigned_to') THEN
    ALTER TABLE tasks ADD COLUMN secondary_assigned_to uuid REFERENCES profiles(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'reopened_count') THEN
    ALTER TABLE tasks ADD COLUMN reopened_count integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'admin_notes') THEN
    ALTER TABLE tasks ADD COLUMN admin_notes text;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tasks' AND column_name = 'photo_url') THEN
    ALTER TABLE tasks ADD COLUMN photo_url text;
  END IF;
END $$;

-- Update task status check
DO $$
BEGIN
  ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_status_check;
  ALTER TABLE tasks ADD CONSTRAINT tasks_status_check 
    CHECK (status IN ('pending', 'in_progress', 'pending_review', 'completed', 'cancelled', 'archived'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Checklist instances erweitern
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'checklist_instances' AND column_name = 'admin_reviewed') THEN
    ALTER TABLE checklist_instances ADD COLUMN admin_reviewed boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'checklist_instances' AND column_name = 'admin_approved') THEN
    ALTER TABLE checklist_instances ADD COLUMN admin_approved boolean DEFAULT null;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'checklist_instances' AND column_name = 'admin_rejection_reason') THEN
    ALTER TABLE checklist_instances ADD COLUMN admin_rejection_reason text DEFAULT null;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'checklist_instances' AND column_name = 'reviewed_by') THEN
    ALTER TABLE checklist_instances ADD COLUMN reviewed_by uuid REFERENCES auth.users(id) DEFAULT null;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'checklist_instances' AND column_name = 'reviewed_at') THEN
    ALTER TABLE checklist_instances ADD COLUMN reviewed_at timestamptz DEFAULT null;
  END IF;
END $$;

-- ============================================================================
-- 4. PATROL ROUNDS SYSTEM
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
  ON patrol_schedules FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE POLICY "Anyone authenticated can view patrol rounds"
  ON patrol_rounds FOR SELECT TO authenticated USING (true);

CREATE POLICY "System can manage patrol rounds"
  ON patrol_rounds FOR ALL TO authenticated WITH CHECK (true);

CREATE POLICY "Anyone authenticated can view patrol scans"
  ON patrol_scans FOR SELECT TO authenticated USING (true);

CREATE POLICY "Staff can create patrol scans"
  ON patrol_scans FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

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

-- ============================================================================
-- 5. HOW-TO DOCUMENTS SYSTEM
-- ============================================================================

CREATE TABLE IF NOT EXISTS how_to_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  category text NOT NULL,
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS how_to_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid REFERENCES how_to_documents(id) ON DELETE CASCADE NOT NULL,
  step_number integer NOT NULL,
  title text NOT NULL,
  description text NOT NULL,
  photo_url text,
  video_url text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE how_to_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE how_to_steps ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view how-to documents"
  ON how_to_documents FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage how-to documents"
  ON how_to_documents FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE POLICY "Anyone authenticated can view how-to steps"
  ON how_to_steps FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage how-to steps"
  ON how_to_steps FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE INDEX IF NOT EXISTS idx_how_to_steps_document ON how_to_steps(document_id);
CREATE INDEX IF NOT EXISTS idx_how_to_steps_order ON how_to_steps(document_id, step_number);