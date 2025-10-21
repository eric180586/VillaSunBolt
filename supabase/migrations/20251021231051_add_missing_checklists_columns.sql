/*
  # Add Missing Columns to Checklists Table

  1. Changes
    - Add `items` (jsonb) - Array of checklist items with their details
    - Add `due_date` (timestamp) - When the checklist is due
    - Add `recurrence` (text) - Type of recurrence (one_time, daily, weekly, bi_weekly, monthly)
    - Add `is_template` (boolean) - Whether this is a template for generating instances
    
  2. Notes
    - These fields are used by Checklists.tsx component
    - items stores JSON array of checklist items
    - recurrence determines how often checklist instances are created
    - is_template identifies template checklists vs one-off checklists
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklists' AND column_name = 'items'
  ) THEN
    ALTER TABLE checklists ADD COLUMN items jsonb DEFAULT '[]'::jsonb;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklists' AND column_name = 'due_date'
  ) THEN
    ALTER TABLE checklists ADD COLUMN due_date timestamp with time zone;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklists' AND column_name = 'recurrence'
  ) THEN
    ALTER TABLE checklists ADD COLUMN recurrence text DEFAULT 'one_time';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklists' AND column_name = 'is_template'
  ) THEN
    ALTER TABLE checklists ADD COLUMN is_template boolean DEFAULT true;
  END IF;
END $$;
