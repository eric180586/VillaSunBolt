/*
  # Fix Duplicate one_time Checklist Instances
  
  ## Problem:
  - CRON job generates checklist instances JEDEN TAG für one_time checklists
  - Prüft nicht ob Instance bereits existiert
  - Führt zu Duplikaten
  
  ## Solution:
  1. DROP und neu erstellen generate_checklist_instance()
  2. Lösche die doppelte Instance (2cf21a2a)
  3. Update CRON function generate_due_checklists()
*/

-- ==========================================
-- 1. DROP und neu erstellen generate_checklist_instance()
-- ==========================================
DROP FUNCTION IF EXISTS generate_checklist_instance(uuid, date);

CREATE FUNCTION generate_checklist_instance(
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
  v_existing_count integer;
BEGIN
  -- Hole Checklist Template
  SELECT * INTO v_checklist
  FROM checklists
  WHERE id = p_checklist_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Checklist not found: %', p_checklist_id;
  END IF;

  -- ==========================================
  -- WICHTIG: Für one_time - prüfe ob bereits eine Instance existiert!
  -- ==========================================
  IF v_checklist.recurrence = 'one_time' THEN
    SELECT COUNT(*) INTO v_existing_count
    FROM checklist_instances
    WHERE checklist_id = p_checklist_id
    AND instance_date = p_target_date;
    
    -- Wenn bereits existiert: NICHT neu generieren!
    IF v_existing_count > 0 THEN
      RAISE NOTICE 'one_time checklist instance already exists for date %. Skipping.', p_target_date;
      RETURN NULL;
    END IF;
  END IF;

  -- Generiere neue Instance
  INSERT INTO checklist_instances (
    checklist_id,
    instance_date,
    items,
    status
  )
  VALUES (
    p_checklist_id,
    p_target_date,
    v_checklist.items,
    'pending'
  )
  RETURNING id INTO v_instance_id;

  -- Update last_generated_date
  UPDATE checklists
  SET last_generated_date = NOW()
  WHERE id = p_checklist_id;

  RETURN v_instance_id;
END;
$$;

-- ==========================================
-- 2. Lösche die doppelte Instance (ID: 2cf21a2a)
-- ==========================================
DELETE FROM checklist_instances
WHERE id = '2cf21a2a-975e-456b-87b1-c5dd942280df'
AND status = 'pending'
AND NOT EXISTS (
  SELECT 1 FROM jsonb_array_elements(items) item 
  WHERE item->>'completed_by_id' IS NOT NULL 
  AND item->>'completed_by_id' != ''
);

-- ==========================================
-- 3. UPDATE: generate_due_checklists() - Extra Safeguard
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
  v_existing_count integer;
  v_result uuid;
BEGIN
  v_today := current_date_cambodia();
  
  FOR v_checklist IN 
    SELECT * FROM checklists 
    WHERE is_template = true
  LOOP
    v_should_generate := false;
    
    CASE v_checklist.recurrence
      WHEN 'daily' THEN
        v_should_generate := true;
        
      WHEN 'one_time' THEN
        -- NUR wenn due_date HEUTE ist UND noch keine Instance existiert!
        IF DATE(v_checklist.due_date) = v_today THEN
          SELECT COUNT(*) INTO v_existing_count
          FROM checklist_instances
          WHERE checklist_id = v_checklist.id
          AND instance_date = v_today;
          
          IF v_existing_count = 0 THEN
            v_should_generate := true;
          END IF;
        END IF;
        
      WHEN 'weekly' THEN
        -- Generiere wenn due_date's Wochentag = heute's Wochentag
        IF EXTRACT(DOW FROM v_checklist.due_date) = EXTRACT(DOW FROM v_today) THEN
          v_should_generate := true;
        END IF;
        
      WHEN 'bi_weekly' THEN
        -- Generiere jede 2. Woche
        IF EXTRACT(DOW FROM v_checklist.due_date) = EXTRACT(DOW FROM v_today) AND
           MOD(EXTRACT(WEEK FROM v_today)::integer, 2) = 0 THEN
          v_should_generate := true;
        END IF;
        
      WHEN 'monthly' THEN
        -- Generiere am gleichen Tag des Monats
        IF EXTRACT(DAY FROM v_checklist.due_date) = EXTRACT(DAY FROM v_today) THEN
          v_should_generate := true;
        END IF;
    END CASE;
    
    IF v_should_generate THEN
      v_result := generate_checklist_instance(v_checklist.id, v_today);
      IF v_result IS NOT NULL THEN
        v_count := v_count + 1;
      END IF;
    END IF;
  END LOOP;
  
  RETURN v_count;
END;
$$;

-- ==========================================
-- 4. Punkte neu berechnen nach Duplikat-Löschung
-- ==========================================
DO $$
DECLARE
  v_user record;
BEGIN
  FOR v_user IN SELECT id FROM profiles WHERE role IN ('staff', 'admin')
  LOOP
    UPDATE daily_point_goals
    SET 
      theoretically_achievable_points = calculate_individual_achievable_points(v_user.id, CURRENT_DATE),
      updated_at = NOW()
    WHERE user_id = v_user.id
    AND goal_date = CURRENT_DATE;
  END LOOP;
END $$;
