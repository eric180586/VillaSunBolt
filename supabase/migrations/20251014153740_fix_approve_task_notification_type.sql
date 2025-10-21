/*
  # Fix approve_task_with_points notification type

  ## Problem
  - Function uses 'task_approved' notification type
  - But notifications_type_check only allows: 'task', 'admin_task_review', etc.
  
  ## Solution
  - Change 'task_approved' to 'success' (generic success notification)
*/

CREATE OR REPLACE FUNCTION public.approve_task_with_points(p_task_id uuid, p_admin_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
v_task record;
v_base_points integer := 0;
v_deadline_bonus integer := 0;
v_reopen_penalty integer := 0;
v_total_points integer := 0;
v_is_within_deadline boolean := false;
v_reason text;
v_user_name text;
BEGIN
IF NOT EXISTS (
SELECT 1 FROM profiles
WHERE id = p_admin_id
AND role = 'admin'
) THEN
RAISE EXCEPTION 'Only admins can approve tasks';
END IF;

SELECT * INTO v_task
FROM tasks
WHERE id = p_task_id;

IF NOT FOUND THEN
RAISE EXCEPTION 'Task not found';
END IF;

IF v_task.status != 'pending_review' THEN
RAISE EXCEPTION 'Task is not pending review';
END IF;

v_base_points := v_task.points_value;

IF v_task.due_date IS NOT NULL THEN
v_is_within_deadline := v_task.completed_at <= v_task.due_date;
IF v_is_within_deadline AND NOT v_task.deadline_bonus_awarded THEN
v_deadline_bonus := 2;
END IF;
END IF;

IF v_task.reopened_count > 0 THEN
v_reopen_penalty := v_task.reopened_count * (-1);
END IF;

v_total_points := v_base_points + v_deadline_bonus + v_reopen_penalty;

IF v_total_points < 0 THEN
v_total_points := 0;
END IF;

UPDATE tasks
SET 
status = 'completed',
completed_at = COALESCE(completed_at, now()),
deadline_bonus_awarded = (v_deadline_bonus > 0),
initial_points_value = COALESCE(initial_points_value, points_value),
points_value = v_total_points,
updated_at = now()
WHERE id = p_task_id;

IF v_task.assigned_to IS NOT NULL AND v_total_points > 0 THEN
v_reason := 'Aufgabe erledigt: ' || v_task.title;

IF v_deadline_bonus > 0 THEN
v_reason := v_reason || ' (✓ Deadline-Bonus +2)';
END IF;

IF v_reopen_penalty < 0 THEN
v_reason := v_reason || ' (' || v_reopen_penalty || ' wegen ' || v_task.reopened_count || 'x Reopen)';
END IF;

INSERT INTO points_history (user_id, points_change, reason, category, created_by)
VALUES (v_task.assigned_to, v_total_points, v_reason, 'task_completed', p_admin_id);

PERFORM update_daily_point_goals(v_task.assigned_to, CURRENT_DATE);
END IF;

IF v_task.secondary_assigned_to IS NOT NULL THEN
v_total_points := GREATEST(v_total_points / 2, 0);
v_reason := 'Aufgabe erledigt (Assistent): ' || v_task.title;

IF v_deadline_bonus > 0 THEN
v_reason := v_reason || ' (✓ Deadline-Bonus +1)';
END IF;

INSERT INTO points_history (user_id, points_change, reason, category, created_by)
VALUES (v_task.secondary_assigned_to, v_total_points, v_reason, 'task_completed', p_admin_id);

PERFORM update_daily_point_goals(v_task.secondary_assigned_to, CURRENT_DATE);
END IF;

-- Fixed: Use 'success' instead of 'task_approved'
SELECT full_name INTO v_user_name FROM profiles WHERE id = v_task.assigned_to;

IF v_task.assigned_to IS NOT NULL THEN
INSERT INTO notifications (user_id, title, message, type)
VALUES (
v_task.assigned_to,
'Very good',
COALESCE(v_user_name, 'Team member'),
'success'
);
END IF;

IF v_task.secondary_assigned_to IS NOT NULL THEN
SELECT full_name INTO v_user_name FROM profiles WHERE id = v_task.secondary_assigned_to;
INSERT INTO notifications (user_id, title, message, type)
VALUES (
v_task.secondary_assigned_to,
'Very good',
COALESCE(v_user_name, 'Team member'),
'success'
);
END IF;

RETURN jsonb_build_object(
'success', true,
'base_points', v_base_points,
'deadline_bonus', v_deadline_bonus,
'reopen_penalty', v_reopen_penalty,
'total_points', v_total_points,
'within_deadline', v_is_within_deadline
);
END;
$function$;
