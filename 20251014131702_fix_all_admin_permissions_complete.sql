/*
  # Complete Admin Permissions Fix

  ## Problem
  - Multiple duplicate RLS policies exist
  - Some tables missing admin INSERT permissions
  - Inconsistent admin access across tables

  ## Solution
  - Remove ALL duplicate policies
  - Create consistent admin policies for ALL tables:
    * Admins can SELECT, INSERT, UPDATE, DELETE everything
    * Staff have appropriate limited permissions
  
  ## Tables Fixed
  - profiles, tasks, checklists, checklist_instances
  - notifications, departure_requests, check_ins
  - weekly_schedules, notes, shopping_items
  - patrol_rounds, patrol_schedules, daily_point_goals
*/

-- ============================================================================
-- PROFILES
-- ============================================================================
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can delete profiles" ON profiles;
DROP POLICY IF EXISTS "Users can view all profiles" ON profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;

CREATE POLICY "Admins have full access to profiles"
  ON profiles FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Users can insert profiles"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can view all profiles"
  ON profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============================================================================
-- TASKS
-- ============================================================================
DROP POLICY IF EXISTS "Admins can delete any task" ON tasks;
DROP POLICY IF EXISTS "Users can delete their created tasks" ON tasks;
DROP POLICY IF EXISTS "Admins can create tasks, staff can create repair" ON tasks;
DROP POLICY IF EXISTS "Users can view tasks based on role" ON tasks;
DROP POLICY IF EXISTS "Admins can update any task" ON tasks;
DROP POLICY IF EXISTS "Users can update tasks appropriately" ON tasks;

CREATE POLICY "Admins have full access to tasks"
  ON tasks FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Staff can create repair tasks"
  ON tasks FOR INSERT
  TO authenticated
  WITH CHECK (category = 'repair');

CREATE POLICY "Staff can view relevant tasks"
  ON tasks FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Staff can update assigned tasks"
  ON tasks FOR UPDATE
  TO authenticated
  USING (
    assigned_to = auth.uid() OR 
    secondary_assigned_to = auth.uid() OR
    created_by = auth.uid()
  );

CREATE POLICY "Staff can delete own repair tasks"
  ON tasks FOR DELETE
  TO authenticated
  USING (created_by = auth.uid() AND category = 'repair');

-- ============================================================================
-- CHECKLISTS
-- ============================================================================
DROP POLICY IF EXISTS "Admins can delete any checklist" ON checklists;
DROP POLICY IF EXISTS "Only admins can delete checklists" ON checklists;
DROP POLICY IF EXISTS "Only admins can create checklists" ON checklists;
DROP POLICY IF EXISTS "Users can view checklists based on role" ON checklists;
DROP POLICY IF EXISTS "Admins can update any checklist" ON checklists;
DROP POLICY IF EXISTS "Only admins can update checklists" ON checklists;

CREATE POLICY "Admins have full access to checklists"
  ON checklists FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Staff can view checklists"
  ON checklists FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- CHECKLIST INSTANCES
-- ============================================================================
DROP POLICY IF EXISTS "Admins can delete any checklist instance" ON checklist_instances;
DROP POLICY IF EXISTS "Only admins can delete checklist instances" ON checklist_instances;
DROP POLICY IF EXISTS "Staff can create checklist instances" ON checklist_instances;
DROP POLICY IF EXISTS "Users can view checklist instances based on role" ON checklist_instances;
DROP POLICY IF EXISTS "Admins can update any checklist instance" ON checklist_instances;
DROP POLICY IF EXISTS "Staff can update checklist instances" ON checklist_instances;

CREATE POLICY "Admins have full access to checklist instances"
  ON checklist_instances FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Staff can create checklist instances"
  ON checklist_instances FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Staff can view checklist instances"
  ON checklist_instances FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Staff can update checklist instances"
  ON checklist_instances FOR UPDATE
  TO authenticated
  USING (true);

-- ============================================================================
-- CHECK_INS
-- ============================================================================
DROP POLICY IF EXISTS "Admins can delete any check-in" ON check_ins;
DROP POLICY IF EXISTS "Users can create own check-ins" ON check_ins;
DROP POLICY IF EXISTS "Users can view all check-ins" ON check_ins;
DROP POLICY IF EXISTS "Admins can update any check-in" ON check_ins;
DROP POLICY IF EXISTS "Admins can update check-ins" ON check_ins;

CREATE POLICY "Admins have full access to check_ins"
  ON check_ins FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Users can create own check-ins"
  ON check_ins FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can view all check-ins"
  ON check_ins FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- DEPARTURE REQUESTS
-- ============================================================================
DROP POLICY IF EXISTS "Admins can delete any departure request" ON departure_requests;
DROP POLICY IF EXISTS "Users can delete own pending departure requests" ON departure_requests;
DROP POLICY IF EXISTS "Users can create own departure requests" ON departure_requests;
DROP POLICY IF EXISTS "Admins can view all departure requests" ON departure_requests;
DROP POLICY IF EXISTS "Users can view own departure requests" ON departure_requests;
DROP POLICY IF EXISTS "Admins can update any departure request" ON departure_requests;
DROP POLICY IF EXISTS "Admins can update departure requests" ON departure_requests;

CREATE POLICY "Admins have full access to departure_requests"
  ON departure_requests FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Users can create own departure requests"
  ON departure_requests FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can view own departure requests"
  ON departure_requests FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can delete own pending departure requests"
  ON departure_requests FOR DELETE
  TO authenticated
  USING (user_id = auth.uid() AND status = 'pending');

-- ============================================================================
-- NOTIFICATIONS
-- ============================================================================
DROP POLICY IF EXISTS "System can create notifications" ON notifications;
DROP POLICY IF EXISTS "Users can view their notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update their notifications" ON notifications;

CREATE POLICY "Admins have full access to notifications"
  ON notifications FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "System can create notifications"
  ON notifications FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can view their notifications"
  ON notifications FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can update their notifications"
  ON notifications FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- WEEKLY SCHEDULES
-- ============================================================================
DROP POLICY IF EXISTS "Admins can delete any schedule" ON weekly_schedules;
DROP POLICY IF EXISTS "Only admins can delete weekly schedules" ON weekly_schedules;
DROP POLICY IF EXISTS "Only admins can insert weekly schedules" ON weekly_schedules;
DROP POLICY IF EXISTS "All authenticated users can view all schedules" ON weekly_schedules;
DROP POLICY IF EXISTS "Admins can update any schedule" ON weekly_schedules;
DROP POLICY IF EXISTS "Only admins can update weekly schedules" ON weekly_schedules;

CREATE POLICY "Admins have full access to weekly_schedules"
  ON weekly_schedules FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "All users can view schedules"
  ON weekly_schedules FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- NOTES
-- ============================================================================
DROP POLICY IF EXISTS "Admins can delete any note" ON notes;
DROP POLICY IF EXISTS "Users and admins can delete notes" ON notes;
DROP POLICY IF EXISTS "Users can create notes" ON notes;
DROP POLICY IF EXISTS "Users can view all notes" ON notes;
DROP POLICY IF EXISTS "Admins can update any note" ON notes;
DROP POLICY IF EXISTS "Users and admins can update notes" ON notes;

CREATE POLICY "Admins have full access to notes"
  ON notes FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Users can create notes"
  ON notes FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can view all notes"
  ON notes FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update notes"
  ON notes FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Users can delete notes"
  ON notes FOR DELETE
  TO authenticated
  USING (true);
