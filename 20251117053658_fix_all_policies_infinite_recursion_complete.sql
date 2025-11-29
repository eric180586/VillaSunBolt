/*
  # Fix ALL policies that cause infinite recursion
  
  1. Problem
    - Many policies were created with "FOR ALL" which applies to SELECT too
    - This causes infinite recursion when checking admin status
    
  2. Solution
    - Drop ALL policies with cmd='ALL' and profiles subquery
    - Keep simple SELECT policies that allow reading data
    - Create specific INSERT/UPDATE/DELETE policies for admins
  
  3. Strategy
    - For most tables: Everyone can SELECT, only admins can INSERT/UPDATE/DELETE
    - For user-specific tables: Users can manage their own, admins can manage all
*/

-- Drop all problematic ALL policies
DO $$
DECLARE
  policy_record RECORD;
BEGIN
  FOR policy_record IN 
    SELECT schemaname, tablename, policyname
    FROM pg_policies 
    WHERE cmd = 'ALL' 
      AND (qual LIKE '%FROM profiles%' OR with_check LIKE '%FROM profiles%')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', 
      policy_record.policyname, 
      policy_record.schemaname, 
      policy_record.tablename
    );
  END LOOP;
END $$;

-- Now create proper policies for each table that needs admin access

-- TASKS: Create specific policies
CREATE POLICY "Admin can insert tasks" ON tasks FOR INSERT TO authenticated 
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can update tasks" ON tasks FOR UPDATE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can delete tasks" ON tasks FOR DELETE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- CHECKLISTS: Create specific policies
CREATE POLICY "Admin can insert checklists" ON checklists FOR INSERT TO authenticated 
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can update checklists" ON checklists FOR UPDATE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- CHECKLIST_INSTANCES: Create specific policies
CREATE POLICY "Admin can update checklist_instances" ON checklist_instances FOR UPDATE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can delete checklist_instances" ON checklist_instances FOR DELETE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- CHECK_INS: Create specific policies  
CREATE POLICY "Admin can view check_ins" ON check_ins FOR SELECT TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can update check_ins" ON check_ins FOR UPDATE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- DAILY_POINT_GOALS: Create specific policies
CREATE POLICY "Admin can insert daily_point_goals" ON daily_point_goals FOR INSERT TO authenticated 
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can update daily_point_goals" ON daily_point_goals FOR UPDATE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- DEPARTURE_REQUESTS: Create specific policies
CREATE POLICY "Admin can view departure_requests" ON departure_requests FOR SELECT TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can update departure_requests" ON departure_requests FOR UPDATE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- WEEKLY_SCHEDULES: Create specific policies
CREATE POLICY "Admin can insert weekly_schedules" ON weekly_schedules FOR INSERT TO authenticated 
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can update weekly_schedules" ON weekly_schedules FOR UPDATE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can delete weekly_schedules" ON weekly_schedules FOR DELETE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- TIME_OFF_REQUESTS: Create specific policies
CREATE POLICY "Admin can view time_off_requests" ON time_off_requests FOR SELECT TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can update time_off_requests" ON time_off_requests FOR UPDATE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can delete time_off_requests" ON time_off_requests FOR DELETE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- POINT_TEMPLATES: Create specific policies
CREATE POLICY "Admin can insert point_templates" ON point_templates FOR INSERT TO authenticated 
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can update point_templates" ON point_templates FOR UPDATE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can delete point_templates" ON point_templates FOR DELETE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- SHOPPING_ITEMS: User or admin can manage
CREATE POLICY "User or admin can update shopping_items" ON shopping_items FOR UPDATE TO authenticated 
  USING (created_by = auth.uid() OR EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (created_by = auth.uid() OR EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "User or admin can delete shopping_items" ON shopping_items FOR DELETE TO authenticated 
  USING (created_by = auth.uid() OR EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- NOTES: User or admin can manage
CREATE POLICY "User or admin can update notes" ON notes FOR UPDATE TO authenticated 
  USING (created_by = auth.uid() OR EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (created_by = auth.uid() OR EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "User or admin can delete notes" ON notes FOR DELETE TO authenticated 
  USING (created_by = auth.uid() OR EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- PATROL_ROUNDS: User or admin can update
CREATE POLICY "User or admin can update patrol_rounds" ON patrol_rounds FOR UPDATE TO authenticated 
  USING (assigned_to = auth.uid() OR EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (assigned_to = auth.uid() OR EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can delete patrol_rounds" ON patrol_rounds FOR DELETE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- ADMIN_LOGS: Admin only
CREATE POLICY "Admin can view admin_logs" ON admin_logs FOR SELECT TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- NOTIFICATION_TRANSLATIONS: Admin manages
CREATE POLICY "Admin can manage notification_translations" ON notification_translations FOR ALL TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- SCHEDULES (old): Admin manages
CREATE POLICY "Admin can insert schedules" ON schedules FOR INSERT TO authenticated 
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can update schedules" ON schedules FOR UPDATE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can delete schedules" ON schedules FOR DELETE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- POINTS_HISTORY: Admin can insert
CREATE POLICY "Admin can insert points_history" ON points_history FOR INSERT TO authenticated 
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- MONTHLY_POINT_GOALS: Admin view
CREATE POLICY "Admin can view monthly_point_goals" ON monthly_point_goals FOR SELECT TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- HOW_TO_DOCUMENTS: Admin manages
CREATE POLICY "Admin can view how_to_documents" ON how_to_documents FOR SELECT TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can insert how_to_documents" ON how_to_documents FOR INSERT TO authenticated 
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can update how_to_documents" ON how_to_documents FOR UPDATE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can delete how_to_documents" ON how_to_documents FOR DELETE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- HOW_TO_STEPS: Admin manages
CREATE POLICY "Admin can view how_to_steps" ON how_to_steps FOR SELECT TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can insert how_to_steps" ON how_to_steps FOR INSERT TO authenticated 
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can update how_to_steps" ON how_to_steps FOR UPDATE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can delete how_to_steps" ON how_to_steps FOR DELETE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- HUMOR_MODULES: Admin manages
CREATE POLICY "Admin can view humor_modules" ON humor_modules FOR SELECT TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can insert humor_modules" ON humor_modules FOR INSERT TO authenticated 
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can update humor_modules" ON humor_modules FOR UPDATE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can delete humor_modules" ON humor_modules FOR DELETE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- PATROL_LOCATIONS: Admin manages
CREATE POLICY "Admin can view patrol_locations" ON patrol_locations FOR SELECT TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can insert patrol_locations" ON patrol_locations FOR INSERT TO authenticated 
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can update patrol_locations" ON patrol_locations FOR UPDATE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can delete patrol_locations" ON patrol_locations FOR DELETE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- PATROL_SCHEDULES: Admin manages
CREATE POLICY "Admin can view patrol_schedules" ON patrol_schedules FOR SELECT TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can insert patrol_schedules" ON patrol_schedules FOR INSERT TO authenticated 
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can update patrol_schedules" ON patrol_schedules FOR UPDATE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can delete patrol_schedules" ON patrol_schedules FOR DELETE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- TUTORIAL_SLIDES: Admin manages
CREATE POLICY "Admin can view tutorial_slides" ON tutorial_slides FOR SELECT TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can insert tutorial_slides" ON tutorial_slides FOR INSERT TO authenticated 
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can update tutorial_slides" ON tutorial_slides FOR UPDATE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

CREATE POLICY "Admin can delete tutorial_slides" ON tutorial_slides FOR DELETE TO authenticated 
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));
