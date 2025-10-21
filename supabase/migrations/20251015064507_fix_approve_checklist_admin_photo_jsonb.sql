/*
  # Fix approve_checklist_instance - Admin Photo JSONB Type + Multi-Person

  ## Problem
  - admin_photo column is JSONB (array) but function sends TEXT � Type mismatch error
  - Only one person gets points (completed_by) instead of all contributors

  ## Solution
  - Convert TEXT parameter to JSONB array: jsonb_build_array(p_admin_photo)
  - Parse items JSONB to find all unique completed_by_id
  - Award points equally to all contributors
  - Each contributor gets: total_points / number_of_contributors

  ## Example
  - Checklist: 12 points
  - Person A completes items 1,2,3
  - Person B completes items 4,5,6,7
  - Person C completes items 8,9
  - Result: Each person gets 12/3 = 4 points
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
  v_checklist record;
  v_contributor_id uuid;
  v_contributors uuid[];
  v_contributor_count integer := 0;
  v_points_per_person integer := 0;
  v_all_names text := '';
BEGIN
  -- Get instance details
  SELECT ci.*, c.title, c.points_value
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

  -- Extract all unique completed_by_id from items JSONB
  SELECT ARRAY_AGG(DISTINCT (item->>'completed_by_id')::uuid)
  INTO v_contributors
  FROM jsonb_array_elements(v_instance.items) AS item
  WHERE item->>'completed_by_id' IS NOT NULL
    AND item->>'completed_by_id' != 'null';

  -- Count contributors
  v_contributor_count := COALESCE(array_length(v_contributors, 1), 0);

  -- If no contributors found in items, fall back to completed_by
  IF v_contributor_count = 0 AND v_instance.completed_by IS NOT NULL THEN
    v_contributors := ARRAY[v_instance.completed_by];
    v_contributor_count := 1;
  END IF;

  -- Calculate points per person
  IF v_contributor_count > 0 AND v_instance.points_value > 0 THEN
    v_points_per_person := v_instance.points_value / v_contributor_count;
  END IF;

  -- Get all contributor names for notification
  SELECT string_agg(DISTINCT p.full_name, ', ')
  INTO v_all_names
  FROM jsonb_array_elements(v_instance.items) AS item
  JOIN profiles p ON p.id = (item->>'completed_by_id')::uuid
  WHERE item->>'completed_by_id' IS NOT NULL
    AND item->>'completed_by_id' != 'null';

  -- Update checklist instance (CONVERT TEXT TO JSONB ARRAY)
  UPDATE checklist_instances
  SET
    admin_reviewed = true,
    admin_approved = true,
    reviewed_by = p_admin_id,
    reviewed_at = now(),
    admin_photo = CASE
      WHEN p_admin_photo IS NOT NULL AND p_admin_photo != ''
      THEN jsonb_build_array(p_admin_photo)
      ELSE NULL
    END
  WHERE id = p_instance_id;

  -- Award points to each contributor
  IF v_contributor_count > 0 AND v_points_per_person > 0 THEN
    FOREACH v_contributor_id IN ARRAY v_contributors
    LOOP
      -- Add to points_history (triggers total_points update via trigger)
      INSERT INTO points_history (user_id, points_change, reason, category, created_by)
      VALUES (
        v_contributor_id,
        v_points_per_person,
        'Checklist genehmigt: ' || v_instance.title ||
        CASE
          WHEN v_contributor_count > 1
          THEN ' (geteilt mit ' || (v_contributor_count - 1) || ' anderen)'
          ELSE ''
        END,
        'task_completed',
        p_admin_id
      );

      -- Trigger point recalculation
      PERFORM update_daily_point_goals(v_contributor_id, v_instance.instance_date::date);

      -- Notify each contributor
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        v_contributor_id,
        'Checklist genehmigt',
        'Checklist "' || v_instance.title || '" wurde genehmigt! +' || v_points_per_person || ' Punkte' ||
        CASE
          WHEN v_contributor_count > 1
          THEN ' (Team: ' || COALESCE(v_all_names, 'Mehrere') || ')'
          ELSE ''
        END,
        'success'
      );
    END LOOP;
  END IF;

  RETURN json_build_object(
    'success', true,
    'points_per_person', v_points_per_person,
    'contributors', v_contributor_count
  );
END;
$$;
