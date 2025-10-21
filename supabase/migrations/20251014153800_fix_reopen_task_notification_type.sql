/*
  # Fix reopen_task_with_penalty notification type

  ## Problem
  - Function uses 'task_rejected' notification type
  - But notifications_type_check only allows: 'task', 'warning', 'error', etc.
  
  ## Solution
  - Change 'task_rejected' to 'warning' (appropriate for rejection/reopen)
*/

CREATE OR REPLACE FUNCTION public.reopen_task_with_penalty(p_task_id uuid, p_admin_id uuid, p_admin_notes text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
v_task record;
BEGIN
IF NOT EXISTS (
SELECT 1 FROM profiles
WHERE id = p_admin_id
AND role = 'admin'
) THEN
RAISE EXCEPTION 'Only admins can reopen tasks';
END IF;

SELECT * INTO v_task
FROM tasks
WHERE id = p_task_id;

IF NOT FOUND THEN
RAISE EXCEPTION 'Task not found';
END IF;

UPDATE tasks
SET 
status = 'in_progress',
admin_notes = p_admin_notes,
reopened_count = COALESCE(reopened_count, 0) + 1,
updated_at = now()
WHERE id = p_task_id;

-- Fixed: Use 'warning' instead of 'task_rejected'
IF v_task.assigned_to IS NOT NULL THEN
INSERT INTO notifications (user_id, title, message, type)
VALUES (
v_task.assigned_to,
'nearly good',
'pls check notes and finish',
'warning'
);
END IF;

IF v_task.secondary_assigned_to IS NOT NULL THEN
INSERT INTO notifications (user_id, title, message, type)
VALUES (
v_task.secondary_assigned_to,
'nearly good',
'pls check notes and finish',
'warning'
);
END IF;

RETURN jsonb_build_object(
'success', true,
'reopened_count', COALESCE(v_task.reopened_count, 0) + 1
);
END;
$function$;
