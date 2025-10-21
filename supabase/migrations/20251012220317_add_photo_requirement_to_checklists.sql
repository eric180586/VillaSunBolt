/*
  # Foto-Anforderung für Tasks und Checklisten
  
  ## Änderungen:
  1. **Checklisten**: photo_required boolean + photo_proof text Felder hinzufügen
  2. **Checklist Instances**: photo_proof Feld für abgeschlossene Checklisten
  3. **Random Foto-Anforderung**: 20% Chance bei Task/Checklist Completion
  
  ## Konzept:
  - Admin kann bei Task/Checklist Erstellung festlegen: "Foto manchmal erforderlich"
  - Bei Completion: 20% Chance dass Foto verlangt wird
  - Ohne Foto kann Task/Checklist nicht abgeschlossen werden
*/

-- ==========================================
-- 1. Checklisten: Foto-Felder hinzufügen
-- ==========================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'checklists' 
    AND column_name = 'photo_required'
  ) THEN
    ALTER TABLE checklists ADD COLUMN photo_required boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'checklists' 
    AND column_name = 'photo_explanation'
  ) THEN
    ALTER TABLE checklists ADD COLUMN photo_explanation text;
  END IF;
END $$;

-- ==========================================
-- 2. Checklist Instances: Foto-Proof
-- ==========================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'checklist_instances' 
    AND column_name = 'photo_proof'
  ) THEN
    ALTER TABLE checklist_instances ADD COLUMN photo_proof text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'checklist_instances' 
    AND column_name = 'photo_required_for_completion'
  ) THEN
    ALTER TABLE checklist_instances ADD COLUMN photo_required_for_completion boolean DEFAULT false;
  END IF;
END $$;

-- ==========================================
-- 3. Kommentar für Verständnis
-- ==========================================
COMMENT ON COLUMN checklists.photo_required IS 'Wenn true, wird bei 20% der Completions ein Foto verlangt';
COMMENT ON COLUMN checklists.photo_explanation IS 'Erklärt dem User WARUM ein Foto gemacht werden soll (z.B. "Zeige dass alles sauber ist")';
COMMENT ON COLUMN checklist_instances.photo_required_for_completion IS 'Wurde für DIESE Instance ein Foto verlangt? (Random 20% wenn photo_required=true)';
COMMENT ON COLUMN checklist_instances.photo_proof IS 'Upload URL oder Base64 des Beweisfotos';
