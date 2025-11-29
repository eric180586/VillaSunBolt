/*
  # Tasks & Checklists Zusammenführung - Complete Migration

  ## Änderungen:
  
  1. Tasks Table erweitern mit Items, Recurrence, Template-Support
  2. Checklists zu Tasks migrieren
  3. Helper Functions für Item-Management
  4. Points-Splitting bei Helper-Support
  
  ## Features:
  - Tasks können optional Items haben
  - Tasks können wiederkehrend sein (Templates)
  - Points werden 50/50 gesplittet bei Helper
  - Admin kann Items einzeln reviewen
*/

-- ==========================================
-- 1. TASKS TABLE ERWEITERN
-- ==========================================

ALTER TABLE tasks 
  ADD COLUMN IF NOT EXISTS items JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS recurrence TEXT DEFAULT 'one_time',
  ADD COLUMN IF NOT EXISTS is_template BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS last_generated_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS template_id UUID REFERENCES tasks(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_tasks_template_id ON tasks(template_id);
CREATE INDEX IF NOT EXISTS idx_tasks_is_template ON tasks(is_template) WHERE is_template = true;
CREATE INDEX IF NOT EXISTS idx_tasks_recurrence ON tasks(recurrence) WHERE is_template = true;

-- ==========================================
-- 2. MIGRATE CHECKLIST TEMPLATES
-- ==========================================

DO $$
DECLARE
  v_checklist record;
  v_new_task_id uuid;
  v_mapping jsonb := '{}';
BEGIN
  FOR v_checklist IN 
    SELECT * FROM checklists 
    WHERE is_template = true
  LOOP
    INSERT INTO tasks (
      title, description, category, items, is_template, recurrence,
      points_value, initial_points_value, duration_minutes,
      photo_proof_required, photo_required_sometimes, photo_optional,
      photo_explanation_text, description_photo, created_by, created_at, status
    ) VALUES (
      v_checklist.title, v_checklist.description, v_checklist.category,
      v_checklist.items, true, COALESCE(v_checklist.recurrence, 'one_time'),
      v_checklist.points_value, v_checklist.points_value, v_checklist.duration_minutes,
      v_checklist.photo_required, v_checklist.photo_required_sometimes, v_checklist.photo_optional,
      v_checklist.photo_explanation_text,
      CASE WHEN v_checklist.photo_explanation IS NOT NULL 
        THEN jsonb_build_array(v_checklist.photo_explanation) ELSE '[]'::jsonb END,
      v_checklist.created_by, v_checklist.created_at, 'pending'
    ) RETURNING id INTO v_new_task_id;
    
    v_mapping := v_mapping || jsonb_build_object(v_checklist.id::text, v_new_task_id::text);
  END LOOP;
  
  CREATE TEMP TABLE checklist_task_mapping (checklist_id uuid, task_id uuid);
  INSERT INTO checklist_task_mapping (checklist_id, task_id)
  SELECT (key)::uuid, (value)::uuid FROM jsonb_each_text(v_mapping);
END $$;

-- ==========================================
-- 3. MIGRATE CHECKLIST INSTANCES
-- ==========================================

DO $$
DECLARE
  v_instance record;
  v_checklist record;
  v_template_id uuid;
BEGIN
  FOR v_instance IN 
    SELECT ci.*
    FROM checklist_instances ci
  LOOP
    -- Get checklist template info
    SELECT * INTO v_checklist FROM checklists WHERE id = v_instance.checklist_id;
    
    -- Get new task template id
    SELECT task_id INTO v_template_id FROM checklist_task_mapping
    WHERE checklist_id = v_instance.checklist_id;
    
    INSERT INTO tasks (
      title, description, category, items, template_id, assigned_to, status,
      points_value, initial_points_value, duration_minutes,
      photo_proof_required, photo_required_sometimes, photo_optional,
      photo_explanation_text, photo_urls, admin_photos, admin_notes,
      due_date, completed_at, created_at, updated_at
    ) VALUES (
      COALESCE(v_instance.title, v_checklist.title),
      v_checklist.description,
      v_checklist.category,
      COALESCE(v_instance.items, '[]'::jsonb),
      v_template_id,
      v_instance.assigned_to,
      v_instance.status,
      COALESCE(v_instance.points_awarded, v_checklist.points_value),
      v_checklist.points_value,
      v_checklist.duration_minutes,
      v_checklist.photo_required,
      v_checklist.photo_required_sometimes,
      v_checklist.photo_optional,
      COALESCE(v_instance.photo_explanation_text, v_checklist.photo_explanation_text),
      COALESCE(v_instance.photo_urls, '[]'::jsonb),
      COALESCE(v_instance.admin_photos, '[]'::jsonb),
      v_instance.admin_rejection_reason,
      v_instance.instance_date::timestamptz,
      v_instance.completed_at,
      v_instance.created_at,
      v_instance.updated_at
    );
  END LOOP;
END $$;

DROP TABLE IF EXISTS checklist_task_mapping;

-- ==========================================
-- 4. RLS POLICIES
-- ==========================================

DROP POLICY IF EXISTS "Everyone can view task templates" ON tasks;
CREATE POLICY "Everyone can view task templates"
  ON tasks FOR SELECT TO authenticated USING (is_template = true);

-- ==========================================
-- 5. HELPER FUNCTIONS
-- ==========================================

CREATE OR REPLACE FUNCTION all_task_items_completed(task_items jsonb)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  IF task_items = '[]'::jsonb OR task_items IS NULL THEN RETURN true; END IF;
  RETURN NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(task_items) as item
    WHERE (item->>'is_completed')::boolean = false
  );
END; $$;

CREATE OR REPLACE FUNCTION count_completed_items(task_items jsonb)
RETURNS integer LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  IF task_items = '[]'::jsonb OR task_items IS NULL THEN RETURN 0; END IF;
  RETURN (
    SELECT COUNT(*)::integer FROM jsonb_array_elements(task_items) as item
    WHERE (item->>'is_completed')::boolean = true
  );
END; $$;

CREATE OR REPLACE FUNCTION complete_task_with_helper(
  p_task_id uuid, p_helper_id uuid DEFAULT NULL,
  p_photo_urls jsonb DEFAULT '[]', p_notes text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_task record;
  v_points_per_person integer;
  v_primary_name text;
BEGIN
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Task not found'; END IF;
  IF NOT all_task_items_completed(v_task.items) THEN
    RAISE EXCEPTION 'Not all items are completed';
  END IF;
  
  IF p_helper_id IS NOT NULL THEN
    v_points_per_person := FLOOR(v_task.points_value / 2.0);
  ELSE
    v_points_per_person := v_task.points_value;
  END IF;
  
  UPDATE tasks SET 
    status = 'pending_review', secondary_assigned_to = p_helper_id,
    photo_urls = COALESCE(p_photo_urls, '[]'::jsonb),
    completed_at = now(), points_value = v_points_per_person
  WHERE id = p_task_id;
  
  SELECT full_name INTO v_primary_name FROM profiles WHERE id = v_task.assigned_to;
  
  INSERT INTO notifications (user_id, type, title, message, reference_id, priority)
  SELECT id, 'task_completed', 'Task zur Review',
    v_primary_name || ' hat Task "' || v_task.title || '" abgeschlossen',
    p_task_id, 'high'
  FROM profiles WHERE role = 'admin';
END; $$;

COMMENT ON FUNCTION complete_task_with_helper IS 'Completes task with optional helper. Points split 50/50 if helper provided.';
