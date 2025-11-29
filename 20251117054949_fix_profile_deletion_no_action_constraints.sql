/*
  # Fix profile deletion blocked by NO ACTION constraints
  
  1. Problem
    - Some foreign keys use NO ACTION which prevents profile deletion
    - Specifically: departure_requests.admin_id, tasks.helper_id, tasks.reviewed_by
  
  2. Solution
    - Change NO ACTION to SET NULL for these columns
    - This allows profiles to be deleted while preserving the records
  
  3. Security
    - Data is preserved but references are nullified
    - This is safer than CASCADE which would delete the records
*/

-- Fix departure_requests.admin_id
ALTER TABLE departure_requests 
  DROP CONSTRAINT IF EXISTS departure_requests_admin_id_fkey;

ALTER TABLE departure_requests
  ADD CONSTRAINT departure_requests_admin_id_fkey
  FOREIGN KEY (admin_id) 
  REFERENCES profiles(id) 
  ON DELETE SET NULL;

-- Fix tasks.helper_id
ALTER TABLE tasks 
  DROP CONSTRAINT IF EXISTS tasks_helper_id_fkey;

ALTER TABLE tasks
  ADD CONSTRAINT tasks_helper_id_fkey
  FOREIGN KEY (helper_id) 
  REFERENCES profiles(id) 
  ON DELETE SET NULL;

-- Fix tasks.reviewed_by
ALTER TABLE tasks 
  DROP CONSTRAINT IF EXISTS tasks_reviewed_by_fkey;

ALTER TABLE tasks
  ADD CONSTRAINT tasks_reviewed_by_fkey
  FOREIGN KEY (reviewed_by) 
  REFERENCES profiles(id) 
  ON DELETE SET NULL;
