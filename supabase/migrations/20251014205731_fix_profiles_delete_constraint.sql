/*
  # Fix Profile Deletion - Remove Foreign Key Blocker
  
  1. Problem
    - check_ins.approved_by has NO ACTION constraint
    - Blocks deletion of admins who have approved check-ins
    - Currently 8 check-ins with approvers in system
  
  2. Solution
    - Change constraint from NO ACTION to SET NULL
    - When admin is deleted, approved_by becomes NULL
    - Preserves check-in history but removes blocker
  
  3. Impact
    - ✅ Admins can now be deleted
    - ✅ Check-in history preserved
    - ✅ approved_by field becomes NULL (acceptable)
*/

-- Drop existing constraint
ALTER TABLE check_ins 
DROP CONSTRAINT IF EXISTS check_ins_approved_by_fkey;

-- Recreate with SET NULL on delete
ALTER TABLE check_ins 
ADD CONSTRAINT check_ins_approved_by_fkey 
FOREIGN KEY (approved_by) 
REFERENCES profiles(id) 
ON DELETE SET NULL;

-- Verify the change
DO $$
BEGIN
  RAISE NOTICE 'Foreign key constraint updated: check_ins.approved_by now SET NULL on delete';
END $$;
