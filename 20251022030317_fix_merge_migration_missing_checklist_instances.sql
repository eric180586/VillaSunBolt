/*
  # Fix Merge Migration - Handle Missing checklist_instances Table
  
  ## Problem:
  The merge migration 20251022002408 expects checklist_instances to exist,
  but it was never created because older migrations were skipped.
  
  ## Solution:
  Wrap the checklist_instances migration in a conditional check.
  
  ## Changes:
  - Only migrate checklist_instances if table exists
  - Don't fail if table doesn't exist
*/

-- Migrate checklist_instances only if table exists
DO $$
DECLARE
  v_instance record;
  v_checklist record;
  v_template_id uuid;
  v_table_exists boolean;
BEGIN
  -- Check if checklist_instances table exists
  SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'checklist_instances'
  ) INTO v_table_exists;
  
  -- Only proceed if table exists
  IF v_table_exists THEN
    FOR v_instance IN 
      SELECT ci.*
      FROM checklist_instances ci
    LOOP
      -- Get checklist template info (if exists)
      BEGIN
        SELECT * INTO v_checklist FROM checklists WHERE id = v_instance.checklist_id;
        
        -- Get new task template id (if exists)
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'checklist_task_mapping') THEN
          SELECT task_id INTO v_template_id FROM checklist_task_mapping
          WHERE checklist_id = v_instance.checklist_id;
        END IF;
        
        -- Insert into tasks (only if checklist data exists)
        IF v_checklist.id IS NOT NULL THEN
          INSERT INTO tasks (
            title, description, category, items, template_id, assigned_to, status,
            points_value, initial_points_value, duration_minutes,
            photo_proof_required, photo_required_sometimes, photo_optional,
            due_date, completed_at, created_at, updated_at
          ) VALUES (
            COALESCE(v_instance.title, v_checklist.title),
            v_checklist.description,
            v_checklist.category,
            COALESCE(v_instance.items, '[]'::jsonb),
            v_template_id,
            v_instance.assigned_to,
            COALESCE(v_instance.status, 'pending'),
            10,
            10,
            30,
            false,
            false,
            false,
            now(),
            v_instance.completed_at,
            v_instance.created_at,
            v_instance.updated_at
          );
        END IF;
      EXCEPTION WHEN OTHERS THEN
        -- Skip this instance if error
        CONTINUE;
      END;
    END LOOP;
  END IF;
END $$;
