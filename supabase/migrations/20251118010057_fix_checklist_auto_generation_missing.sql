/*
  # Fix: Checklist Auto-Generation Missing
  
  Problem: generate_due_checklists() Function fehlt komplett
  Das führt dazu dass Staff die tägliche Checklist "again and again" nicht sieht
  
  Solution: Erstelle die Function neu mit korrekter Logik
*/

-- Helper: Get current date in Cambodia timezone
CREATE OR REPLACE FUNCTION current_date_cambodia()
RETURNS date
LANGUAGE sql
STABLE
AS $$
  SELECT (now() AT TIME ZONE 'Asia/Phnom_Penh')::date;
$$;

-- ==========================================
-- FUNCTION: Generate Checklist Instance
-- ==========================================
CREATE OR REPLACE FUNCTION generate_checklist_instance(
  p_checklist_id uuid,
  p_target_date date
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_checklist record;
  v_instance_id uuid;
  v_existing_id uuid;
BEGIN
  -- Get checklist template
  SELECT * INTO v_checklist
  FROM checklists
  WHERE id = p_checklist_id AND is_template = true;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Checklist template not found: %', p_checklist_id;
  END IF;
  
  -- Check if instance already exists for this date
  SELECT id INTO v_existing_id
  FROM checklist_instances
  WHERE checklist_id = p_checklist_id
  AND instance_date = p_target_date;
  
  IF v_existing_id IS NOT NULL THEN
    RAISE NOTICE 'Instance already exists: %', v_existing_id;
    RETURN v_existing_id;
  END IF;
  
  -- Create new instance
  INSERT INTO checklist_instances (
    checklist_id,
    title,
    instance_date,
    items,
    status,
    assigned_to
  )
  VALUES (
    p_checklist_id,
    v_checklist.title,
    p_target_date,
    v_checklist.items,
    'pending',
    NULL -- Will be assigned by staff when they claim it
  )
  RETURNING id INTO v_instance_id;
  
  RAISE NOTICE 'Created checklist instance: % for date: %', v_instance_id, p_target_date;
  
  -- Update last_generated_date
  UPDATE checklists
  SET last_generated_date = now()
  WHERE id = p_checklist_id;
  
  RETURN v_instance_id;
END;
$$;

-- ==========================================
-- FUNCTION: Generate All Due Checklists
-- ==========================================
CREATE OR REPLACE FUNCTION generate_due_checklists()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_checklist record;
  v_today date;
  v_count integer := 0;
  v_should_generate boolean;
  v_instance_id uuid;
BEGIN
  v_today := current_date_cambodia();
  
  RAISE NOTICE 'Generating checklists for date: %', v_today;
  
  FOR v_checklist IN 
    SELECT * FROM checklists 
    WHERE is_template = true
    ORDER BY id
  LOOP
    v_should_generate := false;
    
    RAISE NOTICE 'Checking checklist: % (%) - recurrence: %, one_time: %', 
      v_checklist.title, v_checklist.id, v_checklist.recurrence, v_checklist.one_time;
    
    -- Check if should generate based on recurrence
    IF v_checklist.one_time = true THEN
      -- One-time checklist: only generate once
      IF v_checklist.last_generated_date IS NULL THEN
        v_should_generate := true;
        RAISE NOTICE 'One-time checklist never generated before';
      END IF;
    ELSIF v_checklist.recurrence = 'daily' THEN
      -- Daily checklist: generate every day
      v_should_generate := true;
      RAISE NOTICE 'Daily checklist - will generate';
    ELSIF v_checklist.recurrence = 'weekly' THEN
      -- Weekly checklist: generate on specific weekday
      -- For now, generate on Mondays (1 = Monday)
      IF EXTRACT(DOW FROM v_today) = 1 THEN
        v_should_generate := true;
      END IF;
    ELSIF v_checklist.recurrence = 'monthly' THEN
      -- Monthly checklist: generate on first day of month
      IF EXTRACT(DAY FROM v_today) = 1 THEN
        v_should_generate := true;
      END IF;
    END IF;
    
    IF v_should_generate THEN
      BEGIN
        v_instance_id := generate_checklist_instance(v_checklist.id, v_today);
        v_count := v_count + 1;
        RAISE NOTICE 'Generated instance: %', v_instance_id;
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error generating checklist %: %', v_checklist.id, SQLERRM;
      END;
    ELSE
      RAISE NOTICE 'Skipping checklist % - should not generate today', v_checklist.title;
    END IF;
  END LOOP;
  
  RAISE NOTICE 'Total checklists generated: %', v_count;
  RETURN v_count;
END;
$$;

-- Test: Generate checklists for today
SELECT generate_due_checklists() as generated_count;