/*
  # Fix helper_id Column References
  
  ## Problem
  Multiple functions reference 'helper_id' column which doesn't exist.
  The correct column name is 'secondary_assigned_to'.
  
  ## Solution
  Replace all references to helper_id with secondary_assigned_to in:
  1. calculate_daily_achievable_points
  2. complete_task_with_helper
  
  ## Functions Fixed
  - calculate_daily_achievable_points: Calculate individual daily achievable points
  - complete_task_with_helper: Mark task complete with optional helper
*/

-- Fix calculate_daily_achievable_points function
CREATE OR REPLACE FUNCTION calculate_daily_achievable_points(p_user_id uuid, p_date date DEFAULT CURRENT_DATE)
RETURNS integer
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
v_total_points numeric := 0;
v_checkin_base numeric := 0;
v_task_points numeric := 0;
v_checklist_points numeric := 0;
v_patrol_points numeric := 0;
BEGIN
-- ==========================================
-- CHECK-IN BASE POINTS
-- ==========================================
SELECT COALESCE(base_points, 0)
INTO v_checkin_base
FROM point_templates
WHERE action_type = 'check_in'
LIMIT 1;

v_total_points := v_total_points + v_checkin_base;

-- ==========================================
-- TASKS: Nur Tasks die MIR zugewiesen sind
-- ==========================================
SELECT COALESCE(SUM(
CASE
WHEN t.assigned_to = p_user_id THEN t.points_value
WHEN t.secondary_assigned_to = p_user_id THEN (t.points_value * 0.5)
ELSE 0
END
), 0)
INTO v_task_points
FROM tasks t
WHERE DATE(t.due_date) = p_date
AND t.status NOT IN ('archived', 'cancelled')
AND (t.assigned_to = p_user_id OR t.secondary_assigned_to = p_user_id);

v_total_points := v_total_points + v_task_points;

-- ==========================================
-- CHECKLISTS: Now integrated into Tasks - no separate calculation needed
-- ==========================================
v_checklist_points := 0;

v_total_points := v_total_points + v_checklist_points;

-- ==========================================
-- PATROL ROUNDS: Nur zugewiesene Rounds
-- ==========================================
SELECT COALESCE(SUM(3), 0)
INTO v_patrol_points
FROM patrol_rounds
WHERE DATE(date) = p_date
AND assigned_to = p_user_id;

v_total_points := v_total_points + v_patrol_points;

RETURN ROUND(v_total_points)::integer;
END;
$function$;

-- Fix complete_task_with_helper function
CREATE OR REPLACE FUNCTION complete_task_with_helper(
  p_task_id uuid,
  p_helper_id uuid DEFAULT NULL,
  p_photo_urls jsonb DEFAULT '[]'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
v_task record;
v_points_per_person integer;
v_primary_name text;
v_helper_name text;
BEGIN
-- Get task
SELECT * INTO v_task FROM tasks WHERE id = p_task_id;

IF NOT FOUND THEN
RAISE EXCEPTION 'Task not found';
END IF;

-- Check if all items completed (if task has items)
IF v_task.items IS NOT NULL AND jsonb_array_length(v_task.items) > 0 THEN
IF NOT all_task_items_completed(v_task.items) THEN
RAISE EXCEPTION 'Not all items are completed';
END IF;
END IF;

-- Calculate points (split if helper)
IF p_helper_id IS NOT NULL THEN
v_points_per_person := FLOOR(v_task.points_value / 2.0);
ELSE
v_points_per_person := v_task.points_value;
END IF;

-- Update task to pending_review
UPDATE tasks SET 
status = 'pending_review',
secondary_assigned_to = p_helper_id,
photo_urls = COALESCE(p_photo_urls, '[]'::jsonb),
completed_at = now(),
points_value = v_points_per_person
WHERE id = p_task_id;

-- Get names for notification
SELECT full_name INTO v_primary_name FROM profiles WHERE id = v_task.assigned_to;

IF p_helper_id IS NOT NULL THEN
SELECT full_name INTO v_helper_name FROM profiles WHERE id = p_helper_id;
END IF;

-- Send notification to admin
INSERT INTO notifications (user_id, type, title, message, reference_id, priority)
SELECT 
id, 
'task_completed', 
'Task zur Review',
CASE 
WHEN p_helper_id IS NOT NULL THEN
v_primary_name || ' und ' || v_helper_name || ' haben Task "' || v_task.title || '" abgeschlossen'
ELSE
v_primary_name || ' hat Task "' || v_task.title || '" abgeschlossen'
END,
p_task_id, 
'high'
FROM profiles WHERE role = 'admin';
END;
$function$;
