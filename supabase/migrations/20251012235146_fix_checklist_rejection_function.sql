/*
  # Fix Checklist Rejection Function

  1. Problem
    - `reject_checklist_instance` references non-existent fields `assigned_to` and `name`
    - Should use `completed_by` instead of `assigned_to`
    - Should get checklist title from related `checklists` table

  2. Changes
    - Fix function to use correct fields
    - Get checklist title from checklists table via JOIN
    - Use completed_by for point deductions and notifications
*/

-- Fixed function to handle checklist rejection
CREATE OR REPLACE FUNCTION reject_checklist_instance(
  p_instance_id uuid,
  p_admin_id uuid,
  p_rejection_reason text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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

  -- Create notification
  IF v_completed_by IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_completed_by,
      'Checklist abgelehnt',
      'Deine Checklist "' || v_checklist_title || '" wurde abgelehnt: ' || p_rejection_reason,
      'checklist_rejected'
    );
  END IF;

  -- Trigger point recalculation
  PERFORM update_daily_point_goals(v_completed_by, v_instance.instance_date::text);

  RETURN json_build_object('success', true);
END;
$$;

-- Fixed function to approve checklist
CREATE OR REPLACE FUNCTION approve_checklist_instance(
  p_instance_id uuid,
  p_admin_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_instance record;
  v_checklist_title text;
BEGIN
  -- Get instance details with checklist title
  SELECT 
    ci.*,
    c.title as checklist_title
  INTO v_instance
  FROM checklist_instances ci
  JOIN checklists c ON ci.checklist_id = c.id
  WHERE ci.id = p_instance_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Checklist instance not found');
  END IF;

  -- Only completed checklists can be approved
  IF v_instance.status != 'completed' THEN
    RETURN json_build_object('success', false, 'error', 'Only completed checklists can be approved');
  END IF;

  v_checklist_title := v_instance.checklist_title;

  -- Update checklist instance
  UPDATE checklist_instances
  SET
    admin_reviewed = true,
    admin_approved = true,
    reviewed_by = p_admin_id,
    reviewed_at = now()
  WHERE id = p_instance_id;

  -- Create notification
  IF v_instance.completed_by IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_instance.completed_by,
      'Checklist genehmigt',
      'Deine Checklist "' || v_checklist_title || '" wurde genehmigt!',
      'checklist_approved'
    );
  END IF;

  RETURN json_build_object('success', true);
END;
$$;
