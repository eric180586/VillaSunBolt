/*
  # Fix all invalid notification types in database functions

  ## Problem
  Multiple functions use invalid notification types:
  - 'checklist_approved' -> not allowed
  - 'checklist_rejected' -> not allowed
  
  ## Solution
  - Change 'checklist_approved' to 'success'
  - Change 'checklist_rejected' to 'warning'
  
  ## Functions Fixed
  1. approve_checklist_with_points
  2. reject_checklist_instance (both overloads)
*/

-- Fix approve_checklist_with_points
CREATE OR REPLACE FUNCTION public.approve_checklist_with_points(p_instance_id uuid, p_admin_id uuid, p_admin_photo_url text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
v_instance record;
v_contributor record;
v_all_names text;
v_total_points integer := 0;
v_contributor_count integer := 0;
v_points_per_contributor integer := 0;
BEGIN
IF NOT EXISTS (
SELECT 1 FROM profiles WHERE id = p_admin_id AND role = 'admin'
) THEN
RAISE EXCEPTION 'Only admins can approve checklists';
END IF;

SELECT * INTO v_instance FROM checklist_instances WHERE id = p_instance_id;

IF NOT FOUND THEN
RAISE EXCEPTION 'Checklist instance not found';
END IF;

UPDATE checklist_instances
SET 
admin_approved = true,
admin_reviewed_at = now(),
admin_photo = p_admin_photo_url,
updated_at = now()
WHERE id = p_instance_id;

v_total_points := v_instance.points_value;

SELECT COUNT(DISTINCT completed_by) INTO v_contributor_count
FROM checklist_instance_items
WHERE instance_id = p_instance_id AND completed_by IS NOT NULL;

IF v_contributor_count > 0 THEN
v_points_per_contributor := v_total_points / v_contributor_count;
END IF;

-- Get all contributor names
SELECT string_agg(DISTINCT p.full_name, ', ')
INTO v_all_names
FROM checklist_instance_items cii
JOIN profiles p ON p.id = cii.completed_by
WHERE cii.instance_id = p_instance_id
AND cii.completed_by IS NOT NULL;

-- Award points and notify all contributors
FOR v_contributor IN 
SELECT DISTINCT completed_by 
FROM checklist_instance_items 
WHERE instance_id = p_instance_id 
AND completed_by IS NOT NULL
LOOP
IF v_points_per_contributor > 0 THEN
INSERT INTO points_history (user_id, points_change, reason, category, created_by)
VALUES (
v_contributor.completed_by,
v_points_per_contributor,
'Checklist genehmigt: ' || v_instance.title,
'checklist_completed',
p_admin_id
);

PERFORM update_daily_point_goals(v_contributor.completed_by, CURRENT_DATE);
END IF;

-- Fixed: Use 'success' instead of 'checklist_approved'
INSERT INTO notifications (user_id, title, message, type)
VALUES (
v_contributor.completed_by,
'very good',
COALESCE(v_all_names, 'Team'),
'success'
);
END LOOP;

RETURN jsonb_build_object(
'success', true,
'points_awarded', v_total_points,
'contributors', v_contributor_count
);
END;
$function$;

-- Fix reject_checklist_instance (3-parameter version)
CREATE OR REPLACE FUNCTION public.reject_checklist_instance(p_instance_id uuid, p_admin_id uuid, p_rejection_reason text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
v_instance record;
v_checklist_title text;
v_completed_by uuid;
v_points_value integer;
BEGIN
-- Get instance details with checklist title
SELECT 
ci.*,
c.title as checklist_title,
c.points_value
INTO v_instance
FROM checklist_instances ci
JOIN checklists c ON ci.checklist_id = c.id
WHERE ci.id = p_instance_id;

IF NOT FOUND THEN
RETURN json_build_object('success', false, 'error', 'Checklist instance not found');
END IF;

-- Only completed checklists can be rejected
IF v_instance.status != 'completed' THEN
RETURN json_build_object('success', false, 'error', 'Only completed checklists can be rejected');
END IF;

-- Get completed_by user and points
v_completed_by := v_instance.completed_by;
v_checklist_title := v_instance.checklist_title;
v_points_value := v_instance.points_value;

-- Update checklist instance - reset to pending
UPDATE checklist_instances
SET
status = 'pending',
admin_reviewed = true,
admin_approved = false,
admin_rejection_reason = p_rejection_reason,
reviewed_by = p_admin_id,
reviewed_at = now(),
completed_at = null,
completed_by = null,
items = (
SELECT jsonb_agg(
jsonb_set(item, '{completed}', 'false'::jsonb)
)
FROM jsonb_array_elements(items) AS item
)
WHERE id = p_instance_id;

-- Deduct points from user if they completed it
IF v_completed_by IS NOT NULL AND v_points_value > 0 THEN
UPDATE profiles
SET points = GREATEST(0, points - v_points_value)
WHERE id = v_completed_by;
END IF;

-- Fixed: Use 'warning' instead of 'checklist_rejected'
IF v_completed_by IS NOT NULL THEN
INSERT INTO notifications (user_id, title, message, type)
VALUES (
v_completed_by,
'Checklist abgelehnt',
'Deine Checklist "' || v_checklist_title || '" wurde abgelehnt: ' || p_rejection_reason,
'warning'
);
END IF;

-- Trigger point recalculation
PERFORM update_daily_point_goals(v_completed_by, v_instance.instance_date::text);

RETURN json_build_object('success', true);
END;
$function$;

-- Fix reject_checklist_instance (4-parameter version with admin_photo)
CREATE OR REPLACE FUNCTION public.reject_checklist_instance(p_instance_id uuid, p_admin_id uuid, p_rejection_reason text, p_admin_photo text DEFAULT NULL::text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
v_instance record;
v_checklist_title text;
v_completed_by uuid;
v_points_value integer;
BEGIN
-- Get instance details with checklist title
SELECT 
ci.*,
c.title as checklist_title,
c.points_value
INTO v_instance
FROM checklist_instances ci
JOIN checklists c ON ci.checklist_id = c.id
WHERE ci.id = p_instance_id;

IF NOT FOUND THEN
RETURN json_build_object('success', false, 'error', 'Checklist instance not found');
END IF;

-- Only completed checklists can be rejected
IF v_instance.status != 'completed' THEN
RETURN json_build_object('success', false, 'error', 'Only completed checklists can be rejected');
END IF;

-- Get completed_by user and points
v_completed_by := v_instance.completed_by;
v_checklist_title := v_instance.checklist_title;
v_points_value := v_instance.points_value;

-- Update checklist instance - reset to pending
UPDATE checklist_instances
SET
status = 'pending',
admin_reviewed = true,
admin_approved = false,
admin_rejection_reason = p_rejection_reason,
reviewed_by = p_admin_id,
reviewed_at = now(),
completed_at = null,
completed_by = null,
admin_photo = p_admin_photo,
items = (
SELECT jsonb_agg(
jsonb_set(item, '{completed}', 'false'::jsonb)
)
FROM jsonb_array_elements(items) AS item
)
WHERE id = p_instance_id;

-- Deduct points from user if they completed it
IF v_completed_by IS NOT NULL AND v_points_value > 0 THEN
UPDATE profiles
SET points = GREATEST(0, points - v_points_value)
WHERE id = v_completed_by;
END IF;

-- Fixed: Use 'warning' instead of 'checklist_rejected'
IF v_completed_by IS NOT NULL THEN
INSERT INTO notifications (user_id, title, message, type)
VALUES (
v_completed_by,
'Checklist abgelehnt',
'Deine Checklist "' || v_checklist_title || '" wurde abgelehnt: ' || p_rejection_reason,
'warning'
);
END IF;

-- Trigger point recalculation
PERFORM update_daily_point_goals(v_completed_by, v_instance.instance_date::text);

RETURN json_build_object('success', true);
END;
$function$;
