/*
  # Full Admin Permissions

  ## Changes:
  1. Add admin override policies for all tables
  2. Admins can edit, delete, and modify ANY record in:
     - tasks (including archived, completed, rejected)
     - checklists
     - checklist_instances
     - profiles (except auth.users)
     - notes
     - weekly_schedules
     - check_ins
     - departure_requests
     - shopping_items
     - patrol_rounds
     - patrol_schedules
     - daily_point_goals
  
  ## Security:
  - Only users with role='admin' in profiles table can perform these actions
  - All existing policies remain for non-admin users
*/

-- ==========================================
-- TASKS: Admin can do everything
-- ==========================================
DROP POLICY IF EXISTS "Admins can delete any task" ON tasks;
CREATE POLICY "Admins can delete any task"
  ON tasks FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can update any task" ON tasks;
CREATE POLICY "Admins can update any task"
  ON tasks FOR UPDATE
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

-- ==========================================
-- CHECKLISTS: Admin can do everything
-- ==========================================
DROP POLICY IF EXISTS "Admins can update any checklist" ON checklists;
CREATE POLICY "Admins can update any checklist"
  ON checklists FOR UPDATE
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

DROP POLICY IF EXISTS "Admins can delete any checklist" ON checklists;
CREATE POLICY "Admins can delete any checklist"
  ON checklists FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- ==========================================
-- CHECKLIST INSTANCES: Admin can do everything
-- ==========================================
DROP POLICY IF EXISTS "Admins can update any checklist instance" ON checklist_instances;
CREATE POLICY "Admins can update any checklist instance"
  ON checklist_instances FOR UPDATE
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

DROP POLICY IF EXISTS "Admins can delete any checklist instance" ON checklist_instances;
CREATE POLICY "Admins can delete any checklist instance"
  ON checklist_instances FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- ==========================================
-- NOTES: Admin can do everything
-- ==========================================
DROP POLICY IF EXISTS "Admins can update any note" ON notes;
CREATE POLICY "Admins can update any note"
  ON notes FOR UPDATE
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

DROP POLICY IF EXISTS "Admins can delete any note" ON notes;
CREATE POLICY "Admins can delete any note"
  ON notes FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- ==========================================
-- WEEKLY_SCHEDULES: Admin can do everything
-- ==========================================
DROP POLICY IF EXISTS "Admins can update any schedule" ON weekly_schedules;
CREATE POLICY "Admins can update any schedule"
  ON weekly_schedules FOR UPDATE
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

DROP POLICY IF EXISTS "Admins can delete any schedule" ON weekly_schedules;
CREATE POLICY "Admins can delete any schedule"
  ON weekly_schedules FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- ==========================================
-- CHECK_INS: Admin can do everything
-- ==========================================
DROP POLICY IF EXISTS "Admins can update any check-in" ON check_ins;
CREATE POLICY "Admins can update any check-in"
  ON check_ins FOR UPDATE
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

DROP POLICY IF EXISTS "Admins can delete any check-in" ON check_ins;
CREATE POLICY "Admins can delete any check-in"
  ON check_ins FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- ==========================================
-- DEPARTURE_REQUESTS: Admin can do everything
-- ==========================================
DROP POLICY IF EXISTS "Admins can update any departure request" ON departure_requests;
CREATE POLICY "Admins can update any departure request"
  ON departure_requests FOR UPDATE
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

DROP POLICY IF EXISTS "Admins can delete any departure request" ON departure_requests;
CREATE POLICY "Admins can delete any departure request"
  ON departure_requests FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- ==========================================
-- SHOPPING_ITEMS: Admin can do everything
-- ==========================================
DROP POLICY IF EXISTS "Admins can update any shopping item" ON shopping_items;
CREATE POLICY "Admins can update any shopping item"
  ON shopping_items FOR UPDATE
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

DROP POLICY IF EXISTS "Admins can delete any shopping item" ON shopping_items;
CREATE POLICY "Admins can delete any shopping item"
  ON shopping_items FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- ==========================================
-- PATROL_ROUNDS: Admin can do everything
-- ==========================================
DROP POLICY IF EXISTS "Admins can update any patrol round" ON patrol_rounds;
CREATE POLICY "Admins can update any patrol round"
  ON patrol_rounds FOR UPDATE
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

DROP POLICY IF EXISTS "Admins can delete any patrol round" ON patrol_rounds;
CREATE POLICY "Admins can delete any patrol round"
  ON patrol_rounds FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- ==========================================
-- PATROL_SCHEDULES: Admin can do everything
-- ==========================================
DROP POLICY IF EXISTS "Admins can update any patrol schedule" ON patrol_schedules;
CREATE POLICY "Admins can update any patrol schedule"
  ON patrol_schedules FOR UPDATE
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

DROP POLICY IF EXISTS "Admins can delete any patrol schedule" ON patrol_schedules;
CREATE POLICY "Admins can delete any patrol schedule"
  ON patrol_schedules FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- ==========================================
-- DAILY_POINT_GOALS: Admin can do everything
-- ==========================================
DROP POLICY IF EXISTS "Admins can update any daily goal" ON daily_point_goals;
CREATE POLICY "Admins can update any daily goal"
  ON daily_point_goals FOR UPDATE
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

DROP POLICY IF EXISTS "Admins can delete any daily goal" ON daily_point_goals;
CREATE POLICY "Admins can delete any daily goal"
  ON daily_point_goals FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- ==========================================
-- POINTS_HISTORY: Admin can do everything
-- ==========================================
DROP POLICY IF EXISTS "Admins can update any points history" ON points_history;
CREATE POLICY "Admins can update any points history"
  ON points_history FOR UPDATE
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

DROP POLICY IF EXISTS "Admins can delete any points history" ON points_history;
CREATE POLICY "Admins can delete any points history"
  ON points_history FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );
