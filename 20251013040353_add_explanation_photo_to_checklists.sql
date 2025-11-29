/*
  # Add explanation_photo to checklists
  
  ## Changes
  - Add `explanation_photo` column to `checklists` table
  - Stores URL to optional photo that admin can upload to explain the checklist
*/

-- Add explanation_photo column
ALTER TABLE checklists 
ADD COLUMN IF NOT EXISTS explanation_photo text;
