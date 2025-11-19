/*
  # Fix approve_task_with_items function to support reject/approve with items
  
  The function needs to support:
  - Approve/Reject toggle
  - Rejected items tracking
  - Bonus points
  - Admin photos and notes
  - Proper notification translations
*/

CREATE OR REPLACE FUNCTION approve_task_with_items(
  p_task_id uuid,
  p_admin_id uuid,
  p_approved boolean DEFAULT true,
  p_rejection_reason text DEFAULT NULL,
  p_rejected_items jsonb DEFAULT '[]'::jsonb,
  p_admin_photos jsonb DEFAULT NULL,
  p_admin_notes text DEFAULT NULL,
  p_bonus_points integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task record;
  v_points integer;
  v_assigned_name text;
  v_helper_name text;
  v_total_points integer;
BEGIN
  -- Get task data
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Task not found');
  END IF;
  
  v_points := COALESCE(v_task.points_value, 0);
  v_total_points := v_points + COALESCE(p_bonus_points, 0);
  
  IF p_approved THEN
    -- APPROVE PATH
    UPDATE tasks
    SET 
      status = 'completed',
      completed_at = COALESCE(completed_at, now()),
      admin_notes = p_admin_notes,
      admin_photos = p_admin_photos,
      admin_approved = true,
      admin_reviewed = true,
      reviewed_by = p_admin_id,
      reviewed_at = now(),
      quality_bonus_points = p_bonus_points
    WHERE id = p_task_id;
    
    -- Award points to assigned user
    IF v_task.assigned_to IS NOT NULL AND v_total_points > 0 THEN
      INSERT INTO points_history (
        user_id,
        points_change,
        reason,
        category,
        created_by
      ) VALUES (
        v_task.assigned_to,
        v_total_points,
        'Task completed: ' || v_task.title,
        'task_completed',
        p_admin_id
      );
      
      -- Send notification
      INSERT INTO notifications (
        user_id,
        type,
        title_de,
        title_en,
        title_km,
        message_de,
        message_en,
        message_km
      ) VALUES (
        v_task.assigned_to,
        'task_approved',
        'Aufgabe genehmigt',
        'Task Approved',
        'កិច្ចការត្រូវបានអនុម័ត',
        'Deine Aufgabe "' || v_task.title || '" wurde genehmigt! +' || v_total_points || ' Punkte',
        'Your task "' || v_task.title || '" has been approved! +' || v_total_points || ' points',
        'កិច្ចការ "' || v_task.title || '" ត្រូវបានអនុម័ត! +' || v_total_points || ' ពិន្ទុ'
      );
    END IF;
    
    -- Award points to helper if exists
    IF v_task.helper_id IS NOT NULL AND v_total_points > 0 THEN
      INSERT INTO points_history (
        user_id,
        points_change,
        reason,
        category,
        created_by
      ) VALUES (
        v_task.helper_id,
        v_total_points,
        'Task helper: ' || v_task.title,
        'task_completed',
        p_admin_id
      );
      
      INSERT INTO notifications (
        user_id,
        type,
        title_de,
        title_en,
        title_km,
        message_de,
        message_en,
        message_km
      ) VALUES (
        v_task.helper_id,
        'task_approved',
        'Aufgabe genehmigt (Helfer)',
        'Task Approved (Helper)',
        'កិច្ចការត្រូវបានអនុម័ត (ជំនួយការ)',
        'Aufgabe "' || v_task.title || '" genehmigt! +' || v_total_points || ' Punkte (Helfer)',
        'Task "' || v_task.title || '" approved! +' || v_total_points || ' points (Helper)',
        'កិច្ចការ "' || v_task.title || '" អនុម័ត! +' || v_total_points || ' ពិន្ទុ (ជំនួយការ)'
      );
    END IF;
    
  ELSE
    -- REJECT PATH
    UPDATE tasks
    SET 
      status = 'pending',
      admin_notes = p_rejection_reason,
      admin_photos = p_admin_photos,
      admin_approved = false,
      admin_reviewed = true,
      reviewed_by = p_admin_id,
      reviewed_at = now(),
      reopened_count = COALESCE(reopened_count, 0) + 1
    WHERE id = p_task_id;
    
    -- Update rejected items in JSONB
    IF p_rejected_items IS NOT NULL AND jsonb_array_length(p_rejected_items) > 0 THEN
      UPDATE tasks
      SET items = (
        SELECT jsonb_agg(
          CASE 
            WHEN item->>'id' = ANY(SELECT jsonb_array_elements_text(p_rejected_items))
            THEN jsonb_set(item, '{rejected}', 'true'::jsonb)
            ELSE item
          END
        )
        FROM jsonb_array_elements(items) AS item
      )
      WHERE id = p_task_id;
    END IF;
    
    -- Send rejection notification
    IF v_task.assigned_to IS NOT NULL THEN
      INSERT INTO notifications (
        user_id,
        type,
        title_de,
        title_en,
        title_km,
        message_de,
        message_en,
        message_km
      ) VALUES (
        v_task.assigned_to,
        'task_rejected',
        'Aufgabe zur Überarbeitung',
        'Task Needs Revision',
        'កិច្ចការត្រូវការកែតម្រូវ',
        'Aufgabe "' || v_task.title || '" muss überarbeitet werden: ' || COALESCE(p_rejection_reason, 'Bitte erneut prüfen'),
        'Task "' || v_task.title || '" needs revision: ' || COALESCE(p_rejection_reason, 'Please review again'),
        'កិច្ចការ "' || v_task.title || '" ត្រូវការកែតម្រូវ: ' || COALESCE(p_rejection_reason, 'សូមពិនិត្យម្តងទៀត')
      );
    END IF;
  END IF;
  
  RETURN jsonb_build_object('success', true, 'approved', p_approved);
END;
$$;