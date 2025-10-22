/*
  # Fix approve_task_with_items Function
  
  ## Problem
  The approve_task_with_items function is using incorrect column names for points_history:
  - Uses `points` but should be `points_change`
  - Uses `task_id` but column doesn't exist
  - Missing `category` and `created_by` columns
  
  ## Solution
  Update the function to use correct points_history schema:
  - points_change (integer) - the points amount
  - category (text) - 'task_approval'
  - created_by (uuid) - admin who approved
  - Remove task_id reference (doesn't exist)
  
  ## Changes
  - Replace INSERT INTO points_history statements with correct columns
  - Add proper category and created_by values
*/

CREATE OR REPLACE FUNCTION approve_task_with_items(
  p_task_id uuid,
  p_admin_id uuid,
  p_approved boolean,
  p_rejection_reason text DEFAULT NULL,
  p_rejected_items jsonb DEFAULT '[]'::jsonb,
  p_admin_photos jsonb DEFAULT '[]'::jsonb,
  p_admin_notes text DEFAULT NULL,
  p_bonus_points integer DEFAULT 0
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task record;
  v_points_per_person integer;
  v_new_items jsonb;
  v_item jsonb;
  v_item_id text;
  v_is_rejected boolean;
BEGIN
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Task not found'; END IF;

  IF p_approved THEN
    -- Calculate points with bonus
    v_points_per_person := v_task.points_value + p_bonus_points;
    
    -- If there's a helper, split points
    IF v_task.secondary_assigned_to IS NOT NULL THEN
      v_points_per_person := FLOOR(v_points_per_person / 2.0);
    END IF;

    -- Award points to primary user (FIXED: use points_change, category, created_by)
    INSERT INTO points_history (user_id, points_change, reason, category, created_by, created_at)
    VALUES (
      v_task.assigned_to,
      v_points_per_person,
      'Task approved: ' || v_task.title,
      'task_approval',
      p_admin_id,
      now()
    );

    -- Award points to helper if exists (FIXED: use points_change, category, created_by)
    IF v_task.secondary_assigned_to IS NOT NULL THEN
      INSERT INTO points_history (user_id, points_change, reason, category, created_by, created_at)
      VALUES (
        v_task.secondary_assigned_to,
        v_points_per_person,
        'Helped with task: ' || v_task.title,
        'task_approval',
        p_admin_id,
        now()
      );
    END IF;

    -- Update task
    UPDATE tasks SET
      status = 'completed',
      admin_photos = p_admin_photos,
      admin_notes = p_admin_notes,
      points_value = v_points_per_person
    WHERE id = p_task_id;

    -- Send notification
    INSERT INTO notifications (user_id, type, title, message, reference_id)
    VALUES (
      v_task.assigned_to,
      'task_approved',
      'Task Genehmigt',
      'Dein Task "' || v_task.title || '" wurde genehmigt! +' || v_points_per_person || ' Punkte',
      p_task_id
    );

  ELSE
    -- Rejection: Mark specific items as rejected
    IF jsonb_array_length(p_rejected_items) > 0 THEN
      v_new_items := '[]'::jsonb;

      -- Loop through items and mark rejected ones
      FOR v_item IN SELECT * FROM jsonb_array_elements(v_task.items)
      LOOP
        v_item_id := v_item->>'id';
        v_is_rejected := false;

        -- Check if this item is in rejected list
        IF EXISTS (
          SELECT 1 FROM jsonb_array_elements_text(p_rejected_items) AS rejected_id
          WHERE rejected_id = v_item_id
        ) THEN
          v_item := jsonb_set(v_item, '{is_completed}', 'false');
          v_item := jsonb_set(v_item, '{admin_rejected}', 'true');
          v_is_rejected := true;
        END IF;

        v_new_items := v_new_items || jsonb_build_array(v_item);
      END LOOP;

      -- Update task with rejected items
      UPDATE tasks SET
        items = v_new_items,
        status = 'pending',
        admin_photos = p_admin_photos,
        admin_notes = p_rejection_reason,
        reopened_count = COALESCE(reopened_count, 0) + 1
      WHERE id = p_task_id;

    ELSE
      -- Full rejection
      UPDATE tasks SET
        status = 'pending',
        admin_photos = p_admin_photos,
        admin_notes = p_rejection_reason,
        reopened_count = COALESCE(reopened_count, 0) + 1,
        completed_at = NULL
      WHERE id = p_task_id;
    END IF;

    -- Send notification
    INSERT INTO notifications (user_id, type, title, message, reference_id, priority)
    VALUES (
      v_task.assigned_to,
      'task_reopened',
      'Task Abgelehnt',
      'Task "' || v_task.title || '" wurde abgelehnt: ' || p_rejection_reason,
      p_task_id,
      'high'
    );
  END IF;
END;
$$;
