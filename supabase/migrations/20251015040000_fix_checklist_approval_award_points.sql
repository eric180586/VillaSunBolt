/*
  # Fix Checklist Approval to Award Points

  ## Problem
  - approve_checklist_instance does not award points to the user
  - Only rejection deducts points, but approval never awards them

  ## Solution
  - Add points to the user when approving a checklist
  - Trigger point recalculation after approval

  ## Points Logic
  - Staff gets checklist points_value when admin approves
  - Points are added to user's profile
  - Daily point goals are recalculated
*/

CREATE OR REPLACE FUNCTION approve_checklist_instance(
  p_instance_id uuid,
  p_admin_id uuid,
  p_admin_photo text DEFAULT NULL
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
  -- Get instance details with checklist title and points
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

  -- Only completed checklists can be approved
  IF v_instance.status != 'completed' THEN
    RETURN json_build_object('success', false, 'error', 'Only completed checklists can be approved');
  END IF;

  v_checklist_title := v_instance.checklist_title;
  v_completed_by := v_instance.completed_by;
  v_points_value := v_instance.points_value;

  -- Update checklist instance
  UPDATE checklist_instances
  SET
    admin_reviewed = true,
    admin_approved = true,
    reviewed_by = p_admin_id,
    reviewed_at = now(),
    admin_photo = p_admin_photo
  WHERE id = p_instance_id;

  -- Award points to the user who completed it
  IF v_completed_by IS NOT NULL AND v_points_value > 0 THEN
    UPDATE profiles
    SET total_points = total_points + v_points_value
    WHERE id = v_completed_by;

    -- Trigger point recalculation
    PERFORM update_daily_point_goals(v_completed_by, v_instance.instance_date::text);
  END IF;

  -- Create notification
  IF v_completed_by IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_completed_by,
      'Checklist genehmigt',
      'Deine Checklist "' || v_checklist_title || '" wurde genehmigt! +' || v_points_value || ' Punkte',
      'checklist_approved'
    );
  END IF;

  RETURN json_build_object('success', true);
END;
$$;
