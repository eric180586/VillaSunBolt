/*
  # Fix Checklist Reject and Reopen Functionality

  ## Problem
  - Admin can't properly reject and reopen checklists
  - Items need to be reset completely (not just completed flag)
  - Need to reset all completed_by fields in items

  ## Solution
  - Update reject_checklist_instance to properly reset all item fields
  - Reset completed, is_completed, completed_by, completed_by_id
  - Keep points deduction logic
  - Ensure checklist can be completed again by staff
*/

CREATE OR REPLACE FUNCTION reject_checklist_instance(
  p_instance_id uuid,
  p_admin_id uuid,
  p_rejection_reason text,
  p_admin_photo jsonb DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_instance record;
  v_checklist_title text;
  v_points_value integer;
  v_contributors uuid[];
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

  v_checklist_title := v_instance.checklist_title;
  v_points_value := v_instance.points_value;

  -- Get all unique contributors from items
  SELECT ARRAY_AGG(DISTINCT (item->>'completed_by_id')::uuid)
  INTO v_contributors
  FROM jsonb_array_elements(v_instance.items) AS item
  WHERE item->>'completed_by_id' IS NOT NULL
    AND item->>'completed_by_id' != 'null';

  -- Update checklist instance - COMPLETELY reset to pending
  UPDATE checklist_instances
  SET
    status = 'pending',
    admin_reviewed = true,
    admin_approved = false,
    admin_rejection_reason = p_rejection_reason,
    admin_photo = p_admin_photo,
    reviewed_by = p_admin_id,
    reviewed_at = now(),
    completed_at = null,
    completed_by = null,
    photo_proof = null,
    items = (
      SELECT jsonb_agg(
        item
        - 'completed'
        - 'is_completed'
        - 'completed_by'
        - 'completed_by_id'
        || jsonb_build_object('completed', false)
      )
      FROM jsonb_array_elements(items) AS item
    )
  WHERE id = p_instance_id;

  -- Deduct points from ALL contributors based on their share
  IF v_contributors IS NOT NULL AND ARRAY_LENGTH(v_contributors, 1) > 0 AND v_points_value > 0 THEN
    DECLARE
      contributor_count integer := ARRAY_LENGTH(v_contributors, 1);
      points_per_contributor numeric := v_points_value::numeric / contributor_count;
      contributor uuid;
    BEGIN
      FOREACH contributor IN ARRAY v_contributors
      LOOP
        -- Deduct points and log in history
        INSERT INTO points_history (user_id, points_change, reason)
        VALUES (
          contributor,
          -ROUND(points_per_contributor)::integer,
          'Checklist rejected: ' || v_checklist_title
        );

        -- Update profile points
        UPDATE profiles
        SET points = GREATEST(0, points - ROUND(points_per_contributor)::integer)
        WHERE id = contributor;

        -- Trigger point recalculation for contributor
        PERFORM update_daily_point_goals(contributor, v_instance.instance_date::date);

        -- Create notification
        INSERT INTO notifications (user_id, title, message, type, priority)
        VALUES (
          contributor,
          'Checklist abgelehnt',
          'Deine Checklist "' || v_checklist_title || '" wurde abgelehnt: ' || p_rejection_reason,
          'checklist_rejected',
          'high'
        );
      END LOOP;
    END;
  END IF;

  RETURN json_build_object('success', true);
END;
$$;
