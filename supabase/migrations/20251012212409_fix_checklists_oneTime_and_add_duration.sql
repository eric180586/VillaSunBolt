/*
  # Fix Checklists: one_time Generation + Duration Field
  
  ## Änderungen:
  1. **one_time Checklisten**: Werden NUR am Tag der due_date generiert
  2. **Duration-Feld**: Arbeitszeit in Minuten hinzufügen
  3. **Falsche Instances löschen**: Remove stain Instance vom 13.10 löschen
  4. **Generierung korrigieren**: one_time checkt Datum korrekt
  
  ## Neue Logik:
  - one_time: Instance wird NUR erstellt wenn due_date = heute
  - Wenn Checklist VOR due_date fertig: Completion-Datum speichern, Punkte gibt's trotzdem
  - Duration für Arbeitszeitberechnung
*/

-- ==========================================
-- 1. Duration-Feld zu Checklisten hinzufügen
-- ==========================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'checklists' 
    AND column_name = 'duration_minutes'
  ) THEN
    ALTER TABLE checklists ADD COLUMN duration_minutes integer DEFAULT 30;
  END IF;
END $$;

-- ==========================================
-- 2. Lösche falsche Instance (Remove stain am 13.10)
-- ==========================================
DELETE FROM checklist_instances
WHERE instance_date = current_date_cambodia()
AND checklist_id IN (
  SELECT id FROM checklists
  WHERE recurrence = 'one_time'
  AND DATE(due_date) != current_date_cambodia()
);

-- ==========================================
-- 3. Korrigiere Generierungs-Funktion
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
        -- NUR wenn due_date HEUTE ist!
        IF DATE(v_checklist.due_date) = v_today THEN
          v_should_generate := true;
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
      PERFORM generate_checklist_instance(v_checklist.id, v_today);
      v_count := v_count + 1;
    END IF;
  END LOOP;
  
  RETURN v_count;
END;
$$;

-- ==========================================
-- 4. Punkte neu berechnen
-- ==========================================
SELECT initialize_daily_goals_for_today();

-- ==========================================
-- 5. Duration für existierende Checklisten setzen
-- ==========================================
UPDATE checklists
SET duration_minutes = CASE
  WHEN category = 'daily_morning' THEN 60
  WHEN category = 'room_cleaning' THEN 45
  WHEN category = 'small_cleaning' THEN 15
  WHEN category = 'housekeeping' THEN 120
  ELSE 30
END
WHERE duration_minutes IS NULL OR duration_minutes = 30;
