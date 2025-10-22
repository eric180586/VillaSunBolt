/*
  # Fix approve_task_with_items Notifications Schema
  
  ## Problem
  Function tries to insert reference_id and priority columns that don't exist
  Actual notifications schema has: id, user_id, title, message, type, is_read, link, created_at
  
  ## Solution
  Remove reference_id and priority from INSERT statements
  Use 'link' column instead (optional)
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

    -- Award points to primary user
    INSERT INTO points_history (user_id, points_change, reason, category, created_by, created_at)
    VALUES (
      v_task.assigned_to,
      v_points_per_person,
      'Task approved: ' || v_task.title,
      'task_completed',
      p_admin_id,
      now()
    );

    -- Award points to helper if exists
    IF v_task.secondary_assigned_to IS NOT NULL THEN
      INSERT INTO points_history (user_id, points_change, reason, category, created_by, created_at)
      VALUES (
        v_task.secondary_assigned_to,
        v_points_per_person,
        'Helped with task: ' || v_task.title,
        'task_completed',
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

    -- Send notification (FIXED: removed reference_id, added link)
    INSERT INTO notifications (user_id, type, title, message, link)
    VALUES (
      v_task.assigned_to,
      'task_approved',
      'Task Genehmigt',
      'Dein Task "' || v_task.title || '" wurde genehmigt! +' || v_points_per_person || ' Punkte',
      '/tasks'
    );

    -- Send notification to helper if exists
    IF v_task.secondary_assigned_to IS NOT NULL THEN
      INSERT INTO notifications (user_id, type, title, message, link)
      VALUES (
        v_task.secondary_assigned_to,
        'task_approved',
        'Task Genehmigt',
        'Du hast bei Task "' || v_task.title || '" geholfen! +' || v_points_per_person || ' Punkte',
        '/tasks'
      );
    END IF;

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

    -- Send notification (FIXED: removed reference_id and priority, added link)
    INSERT INTO notifications (user_id, type, title, message, link)
    VALUES (
      v_task.assigned_to,
      'task_reopened',
      'Task Abgelehnt',
      'Task "' || v_task.title || '" wurde abgelehnt: ' || p_rejection_reason,
      '/tasks'
    );
  END IF;
END;
$$;
