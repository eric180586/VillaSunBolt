/*
  # Simple Task Generation System

  1. Purpose
    - Generate task instances from templates daily
    - Support daily, weekly, monthly recurrence

  2. Functions
    - generate_task_instance: Create single task from template
    - generate_due_tasks: Generate all due tasks (called by cron or manually)

  3. Schema Updates
    - Add template_id to tasks
    - Add last_generated_date to tasks
*/

-- Add columns if they don't exist
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS template_id uuid REFERENCES tasks(id),
ADD COLUMN IF NOT EXISTS last_generated_date timestamptz;

-- Generate task instance from template
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
  v_target_timestamp timestamptz;
BEGIN
  -- Get template
  SELECT * INTO v_template FROM tasks WHERE id = p_template_id AND is_template = true;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task template not found: %', p_template_id;
  END IF;
  
  -- Create timestamp with time from template due_date, date from p_target_date
  IF v_template.due_date IS NOT NULL THEN
    v_target_timestamp := p_target_date::date + (v_template.due_date::time);
  ELSE
    v_target_timestamp := p_target_date::date + '10:00:00'::time;
  END IF;
  
  -- Check if instance already exists for this date
  SELECT id INTO v_existing_id
  FROM tasks
  WHERE template_id = p_template_id
    AND due_date::date = p_target_date
    AND assigned_to = COALESCE(p_assigned_to, v_template.assigned_to)
    AND status NOT IN ('archived', 'completed');
    
  IF v_existing_id IS NOT NULL THEN
    RETURN v_existing_id;
  END IF;
  
  -- Create new instance
  INSERT INTO tasks (
    title, description, category, items, template_id,
    assigned_to, points_value, initial_points_value, duration_minutes,
    photo_proof_required, photo_required_sometimes, photo_optional,
    photo_explanation_text, description_photo, created_by,
    due_date, status, recurrence, is_template
  )
  VALUES (
    v_template.title, v_template.description, v_template.category,
    v_template.items, p_template_id,
    COALESCE(p_assigned_to, v_template.assigned_to),
    v_template.points_value, v_template.initial_points_value, v_template.duration_minutes,
    v_template.photo_proof_required, v_template.photo_required_sometimes, v_template.photo_optional,
    v_template.photo_explanation_text, v_template.description_photo, v_template.created_by,
    v_target_timestamp, 'pending', 'one_time', false
  )
  RETURNING id INTO v_instance_id;
  
  -- Update last_generated_date on template
  UPDATE tasks SET last_generated_date = now() WHERE id = p_template_id;
  
  RAISE NOTICE 'Generated task instance % from template %', v_instance_id, p_template_id;
  
  RETURN v_instance_id;
END;
$$;

-- Generate all due tasks
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
  v_today := (now() AT TIME ZONE 'Asia/Phnom_Penh')::date;
  
  RAISE NOTICE 'Generating tasks for date: %', v_today;
  
  FOR v_template IN 
    SELECT * FROM tasks 
    WHERE is_template = true 
    AND recurrence != 'one_time'
    ORDER BY category, title
  LOOP
    v_should_generate := false;
    v_last_gen := v_template.last_generated_date::date;
    
    RAISE NOTICE 'Checking template: % (%), recurrence: %, last_gen: %', 
      v_template.title, v_template.id, v_template.recurrence, v_last_gen;
    
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
      RAISE NOTICE 'Generating task from template %', v_template.id;
      PERFORM generate_task_instance(v_template.id, v_today);
      v_count := v_count + 1;
    ELSE
      RAISE NOTICE 'Skipping template % - already generated', v_template.id;
    END IF;
  END LOOP;
  
  RAISE NOTICE 'Generated % tasks', v_count;
  
  RETURN v_count;
END;
$$;