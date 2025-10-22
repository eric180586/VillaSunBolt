/*
  # Add sort_order to humor_modules

  ## Problem:
  - Frontend expects sort_order column
  - Column doesn't exist, causing 400 error
  
  ## Solution:
  - Add sort_order column with default values
*/

-- Add sort_order column
ALTER TABLE humor_modules 
ADD COLUMN IF NOT EXISTS sort_order integer DEFAULT 0;

-- Update existing rows with sequential sort_order
WITH numbered_rows AS (
  SELECT id, ROW_NUMBER() OVER (ORDER BY created_at) as rn
  FROM humor_modules
)
UPDATE humor_modules h
SET sort_order = n.rn
FROM numbered_rows n
WHERE h.id = n.id;

COMMENT ON COLUMN humor_modules.sort_order IS 
'Display order for humor modules';
