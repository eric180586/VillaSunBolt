import pg from 'pg';
const { Client } = pg;

// Extrahiere connection string aus .env
const connectionString = 'postgresql://postgres.vmfvvjzgzmmkigpxynii:JingGang123!@aws-0-eu-central-1.pooler.supabase.com:6543/postgres';

const sql = `
-- Task Approval Functions
CREATE OR REPLACE FUNCTION approve_task_with_points(p_task_id uuid, p_admin_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_task record; v_base_points integer; v_deadline_bonus integer := 0; v_reopen_penalty integer := 0; v_total_points integer; v_reason text; v_is_within_deadline boolean := false;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_admin_id AND role = 'admin') THEN RAISE EXCEPTION 'Only admins can approve tasks'; END IF;
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id; IF NOT FOUND THEN RAISE EXCEPTION 'Task not found'; END IF;
  v_base_points := v_task.points_value;
  IF v_task.due_date IS NOT NULL AND v_task.completed_at IS NOT NULL THEN v_is_within_deadline := v_task.completed_at <= v_task.due_date; IF v_is_within_deadline THEN v_deadline_bonus := 2; END IF; END IF;
  IF v_task.reopened_count > 0 THEN v_reopen_penalty := v_task.reopened_count * (-1); END IF;
  v_total_points := GREATEST(v_base_points + v_deadline_bonus + v_reopen_penalty, 0);
  UPDATE tasks SET status = 'completed', completed_at = COALESCE(completed_at, now()), deadline_bonus_awarded = (v_deadline_bonus > 0), initial_points_value = COALESCE(initial_points_value, points_value), points_value = v_total_points, updated_at = now() WHERE id = p_task_id;
  IF v_task.assigned_to IS NOT NULL AND v_total_points > 0 THEN
    v_reason := 'Aufgabe erledigt: ' || v_task.title; IF v_deadline_bonus > 0 THEN v_reason := v_reason || ' (+2 Deadline-Bonus)'; END IF; IF v_reopen_penalty < 0 THEN v_reason := v_reason || ' (' || v_reopen_penalty || ' Reopen-Penalty)'; END IF;
    INSERT INTO points_history (user_id, points_change, reason, category, created_by) VALUES (v_task.assigned_to, v_total_points, v_reason, 'task_completed', p_admin_id);
    INSERT INTO notifications (user_id, title, message, type) VALUES (v_task.assigned_to, 'Task genehmigt!', 'Sehr gut! +' || v_total_points || ' Punkte für: ' || v_task.title, 'success');
  END IF;
  RETURN jsonb_build_object('success', true, 'base_points', v_base_points, 'deadline_bonus', v_deadline_bonus, 'reopen_penalty', v_reopen_penalty, 'total_points', v_total_points);
END; $$;

CREATE OR REPLACE FUNCTION reopen_task_with_penalty(p_task_id uuid, p_admin_id uuid, p_admin_notes text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_task record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_admin_id AND role = 'admin') THEN RAISE EXCEPTION 'Only admins can reopen tasks'; END IF;
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id; IF NOT FOUND THEN RAISE EXCEPTION 'Task not found'; END IF;
  UPDATE tasks SET status = 'in_progress', admin_notes = p_admin_notes, reopened_count = COALESCE(reopened_count, 0) + 1, updated_at = now() WHERE id = p_task_id;
  IF v_task.assigned_to IS NOT NULL THEN INSERT INTO notifications (user_id, title, message, type) VALUES (v_task.assigned_to, 'Task zur Überarbeitung', 'Bitte überarbeite: ' || v_task.title || '. ' || COALESCE(p_admin_notes, ''), 'warning'); END IF;
  RETURN jsonb_build_object('success', true, 'reopened_count', COALESCE(v_task.reopened_count, 0) + 1);
END; $$;

CREATE OR REPLACE FUNCTION approve_checklist_instance(p_instance_id uuid, p_admin_id uuid, p_admin_photo text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_instance record; v_checklist record;
BEGIN
  SELECT * INTO v_instance FROM checklist_instances WHERE id = p_instance_id; IF NOT FOUND THEN RETURN json_build_object('success', false, 'error', 'Checklist instance not found'); END IF;
  IF v_instance.status != 'completed' THEN RETURN json_build_object('success', false, 'error', 'Only completed checklists can be approved'); END IF;
  UPDATE checklist_instances SET admin_reviewed = true, admin_approved = true, reviewed_by = p_admin_id, reviewed_at = now() WHERE id = p_instance_id;
  SELECT * INTO v_checklist FROM checklists WHERE id = v_instance.checklist_id;
  IF v_instance.assigned_to IS NOT NULL OR v_instance.completed_by IS NOT NULL THEN INSERT INTO notifications (user_id, title, message, type) VALUES (COALESCE(v_instance.assigned_to, v_instance.completed_by), 'Checklist genehmigt', 'Deine Checklist "' || COALESCE(v_instance.title, v_checklist.title, 'Checklist') || '" wurde genehmigt!', 'success'); END IF;
  RETURN json_build_object('success', true);
END; $$;

CREATE OR REPLACE FUNCTION reject_checklist_instance(p_instance_id uuid, p_admin_id uuid, p_rejection_reason text, p_admin_photo text DEFAULT NULL)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_instance record; v_checklist record; v_points_to_deduct integer; v_user_id uuid;
BEGIN
  SELECT * INTO v_instance FROM checklist_instances WHERE id = p_instance_id; IF NOT FOUND THEN RETURN json_build_object('success', false, 'error', 'Checklist instance not found'); END IF;
  IF v_instance.status != 'completed' THEN RETURN json_build_object('success', false, 'error', 'Only completed checklists can be rejected'); END IF;
  v_user_id := COALESCE(v_instance.assigned_to, v_instance.completed_by);
  IF v_instance.points_awarded IS NOT NULL AND ((v_instance.points_awarded::text = 'true') OR (v_instance.points_awarded::integer > 0)) THEN
    SELECT * INTO v_checklist FROM checklists WHERE id = v_instance.checklist_id; v_points_to_deduct := COALESCE(v_checklist.points_value, 0);
    IF v_points_to_deduct > 0 AND v_user_id IS NOT NULL THEN INSERT INTO points_history (user_id, points_change, reason, category, created_by) VALUES (v_user_id, -v_points_to_deduct, 'Checklist abgelehnt: ' || COALESCE(v_instance.title, v_checklist.title, 'Checklist'), 'deduction', p_admin_id); END IF;
  END IF;
  UPDATE checklist_instances SET status = 'pending', admin_reviewed = true, admin_approved = false, admin_rejection_reason = p_rejection_reason, reviewed_by = p_admin_id, reviewed_at = now(), completed_at = null, points_awarded = false WHERE id = p_instance_id;
  IF v_user_id IS NOT NULL THEN SELECT * INTO v_checklist FROM checklists WHERE id = v_instance.checklist_id; INSERT INTO notifications (user_id, title, message, type) VALUES (v_user_id, 'Checklist abgelehnt', 'Deine Checklist "' || COALESCE(v_instance.title, v_checklist.title, 'Checklist') || '" wurde abgelehnt: ' || p_rejection_reason, 'warning'); END IF;
  RETURN json_build_object('success', true);
END; $$;

CREATE OR REPLACE FUNCTION approve_check_in(p_check_in_id uuid, p_admin_id uuid, p_custom_points integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_check_in record; v_final_points integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_admin_id AND role = 'admin') THEN RAISE EXCEPTION 'Only admins can approve check-ins'; END IF;
  SELECT * INTO v_check_in FROM check_ins WHERE id = p_check_in_id; IF NOT FOUND THEN RAISE EXCEPTION 'Check-in not found'; END IF;
  v_final_points := COALESCE(p_custom_points, v_check_in.points_awarded);
  UPDATE check_ins SET status = 'approved', approved_by = p_admin_id, approved_at = now(), points_awarded = v_final_points WHERE id = p_check_in_id;
  IF v_final_points > 0 THEN INSERT INTO points_history (user_id, points_change, reason, category, created_by) VALUES (v_check_in.user_id, v_final_points, 'Check-in genehmigt', 'task_completed', p_admin_id); END IF;
  INSERT INTO notifications (user_id, title, message, type) VALUES (v_check_in.user_id, 'Check-in genehmigt', 'Dein Check-in wurde genehmigt. +' || v_final_points || ' Punkte', 'success');
  RETURN jsonb_build_object('success', true, 'points_awarded', v_final_points);
END; $$;

CREATE OR REPLACE FUNCTION reject_check_in(p_check_in_id uuid, p_admin_id uuid, p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_check_in record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_admin_id AND role = 'admin') THEN RAISE EXCEPTION 'Only admins can reject check-ins'; END IF;
  SELECT * INTO v_check_in FROM check_ins WHERE id = p_check_in_id; IF NOT FOUND THEN RAISE EXCEPTION 'Check-in not found'; END IF;
  UPDATE check_ins SET status = 'rejected', approved_by = p_admin_id, approved_at = now(), points_awarded = 0 WHERE id = p_check_in_id;
  INSERT INTO notifications (user_id, title, message, type) VALUES (v_check_in.user_id, 'Check-in abgelehnt', 'Dein Check-in wurde abgelehnt: ' || p_reason, 'warning');
  RETURN jsonb_build_object('success', true);
END; $$;

CREATE OR REPLACE FUNCTION reset_all_points()
RETURNS json LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_count integer := 0;
BEGIN
  UPDATE profiles SET total_points = 0 WHERE role = 'staff'; GET DIAGNOSTICS v_count = ROW_COUNT;
  DELETE FROM points_history WHERE TRUE; DELETE FROM daily_point_goals WHERE TRUE;
  PERFORM update_daily_point_goals(NULL, CURRENT_DATE);
  RETURN json_build_object('success', true, 'users_reset', v_count, 'message', 'All points have been reset successfully');
END; $$;

GRANT EXECUTE ON FUNCTION approve_task_with_points TO authenticated;
GRANT EXECUTE ON FUNCTION reopen_task_with_penalty TO authenticated;
GRANT EXECUTE ON FUNCTION approve_checklist_instance TO authenticated;
GRANT EXECUTE ON FUNCTION reject_checklist_instance TO authenticated;
GRANT EXECUTE ON FUNCTION approve_check_in TO authenticated;
GRANT EXECUTE ON FUNCTION reject_check_in TO authenticated;
GRANT EXECUTE ON FUNCTION reset_all_points TO authenticated;
`;

async function executeSQLDirect() {
  const client = new Client({ connectionString });

  try {
    console.log('🔌 Connecting to database...');
    await client.connect();
    console.log('✅ Connected!\n');

    console.log('🚀 Executing SQL to create missing functions...\n');
    await client.query(sql);

    console.log('✅ All 7 missing functions created successfully!\n');
    console.log('Functions added:');
    console.log('  ✅ approve_task_with_points');
    console.log('  ✅ reopen_task_with_penalty');
    console.log('  ✅ approve_checklist_instance');
    console.log('  ✅ reject_checklist_instance');
    console.log('  ✅ approve_check_in');
    console.log('  ✅ reject_check_in');
    console.log('  ✅ reset_all_points\n');

  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.detail) console.error('Detail:', error.detail);
  } finally {
    await client.end();
  }
}

executeSQLDirect();
