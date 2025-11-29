/*
  # Add admin_photo field to checklist_instances
  
  ## Changes
  - Add `admin_photo` column to `checklist_instances` table
  - Stores URL to optional photo that admin can upload when reviewing checklist
*/

-- Add admin_photo column
ALTER TABLE checklist_instances 
ADD COLUMN IF NOT EXISTS admin_photo text;
