/*
  # Task Generation & Review System

  ## Features:
  1. Generate task instances from templates (wie generate_checklist_instance)
  2. Admin can review individual items
  3. Admin can reject specific items
  4. Points awarded correctly with helper support
  
  ## Functions:
  - generate_task_instance() - Create task from template
  - generate_due_tasks() - Auto-generate recurring tasks
  - approve_task_with_items() - Admin approval with item-level review
  - reject_task_items() - Reject specific items
*/

-- ==========================================
-- 1. GENERATE TASK INSTANCE FROM TEMPLATE
-- ==========================================

CREATE OR REPLACE FUNCTION generate_task_instance(
  p_template_id uuid,
  p_target_date date,
  p_assigned_to uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_template record;
  v_instance_id uuid;
  v_existing_id uuid;
BEGIN
  -- Get template
  SELECT * INTO v_template FROM tasks WHERE id = p_template_id AND is_template = true;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task template not found';
  END IF;
  
  -- Check if instance already exists for this date
  SELECT id INTO v_existing_id
  FROM tasks
  WHERE template_id = p_template_id
    AND due_date::date = p_target_date
    AND assigned_to = COALESCE(p_assigned_to, v_template.assigned_to);
    
  IF v_existing_id IS NOT NULL THEN
    RETURN v_existing_id;
  END IF;
  
  -- Create new instance
  INSERT INTO tasks (
    title, description, category, items, template_id,
    assigned_to, points_value, initial_points_value, duration_minutes,
    photo_proof_required, photo_required_sometimes, photo_optional,
    photo_explanation_text, description_photo, created_by,
    due_date, status, recurrence
  )
  VALUES (
    v_template.title, v_template.description, v_template.category,
    v_template.items, p_template_id,
    COALESCE(p_assigned_to, v_template.assigned_to),
    v_template.points_value, v_template.initial_points_value, v_template.duration_minutes,
    v_template.photo_proof_required, v_template.photo_required_sometimes, v_template.photo_optional,
    v_template.photo_explanation_text, v_template.description_photo, v_template.created_by,
    p_target_date::timestamptz, 'pending', 'one_time'
  )
  RETURNING id INTO v_instance_id;
  
  -- Update last_generated_date on template
  UPDATE tasks SET last_generated_date = now() WHERE id = p_template_id;
  
  RETURN v_instance_id;
END;
$$;

-- ==========================================
-- 2. GENERATE ALL DUE TASKS (CRON)
-- ==========================================

CREATE OR REPLACE FUNCTION generate_due_tasks()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_template record;
  v_today date;
  v_count integer := 0;
  v_should_generate boolean;
  v_last_gen date;
BEGIN
  v_today := current_date_cambodia();
  
  FOR v_template IN 
    SELECT * FROM tasks 
    WHERE is_template = true AND recurrence != 'one_time'
  LOOP
    v_should_generate := false;
    v_last_gen := v_template.last_generated_date::date;
    
    CASE v_template.recurrence
      WHEN 'daily' THEN
        v_should_generate := (v_last_gen IS NULL OR v_last_gen < v_today);
      WHEN 'weekly' THEN
        v_should_generate := (v_last_gen IS NULL OR v_last_gen < v_today - INTERVAL '6 days');
      WHEN 'bi_weekly' THEN
        v_should_generate := (v_last_gen IS NULL OR v_last_gen < v_today - INTERVAL '13 days');
      WHEN 'monthly' THEN
        v_should_generate := (v_last_gen IS NULL OR v_last_gen < v_today - INTERVAL '27 days');
    END CASE;
    
    IF v_should_generate THEN
      PERFORM generate_task_instance(v_template.id, v_today);
      v_count := v_count + 1;
    END IF;
  END LOOP;
  
  RETURN v_count;
END;
$$;

-- ==========================================
-- 3. ADMIN APPROVAL WITH ITEM REVIEW
-- ==========================================

CREATE OR REPLACE FUNCTION approve_task_with_items(
  p_task_id uuid,
  p_admin_id uuid,
  p_approved boolean,
  p_rejection_reason text DEFAULT NULL,
  p_rejected_items jsonb DEFAULT '[]',
  p_admin_photos jsonb DEFAULT '[]',
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
    INSERT INTO points_history (user_id, points, reason, task_id, created_at)
    VALUES (
      v_task.assigned_to,
      v_points_per_person,
      'Task approved: ' || v_task.title,
      p_task_id,
      now()
    );
    
    -- Award points to helper if exists
    IF v_task.secondary_assigned_to IS NOT NULL THEN
      INSERT INTO points_history (user_id, points, reason, task_id, created_at)
      VALUES (
        v_task.secondary_assigned_to,
        v_points_per_person,
        'Helped with task: ' || v_task.title,
        p_task_id,
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

COMMENT ON FUNCTION approve_task_with_items IS 'Admin approves or rejects task. Can reject specific items only. Points split if helper involved.';

-- ==========================================
-- 4. UPDATE POINTS CALCULATION TRIGGERS
-- ==========================================

-- Update achievable points to include task items
CREATE OR REPLACE FUNCTION calculate_achievable_points_for_date(p_date date, p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_total integer := 0;
BEGIN
  -- Tasks assigned to user for this date
  SELECT COALESCE(SUM(initial_points_value), 0) INTO v_total
  FROM tasks
  WHERE assigned_to = p_user_id
    AND due_date::date = p_date
    AND status != 'archived'
    AND is_template = false;
  
  RETURN v_total;
END;
$$;
