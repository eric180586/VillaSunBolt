/*
  # Fix approve_checklist_instance Function Conflict
  
  1. Problem
    - Two versions of approve_checklist_instance exist causing a 300 error (multiple choices)
    - One with 2 parameters, one with 3 parameters
  
  2. Solution
    - Drop the old 2-parameter version
    - Keep only the 3-parameter version with admin_photo support
*/

-- Drop the old 2-parameter version
DROP FUNCTION IF EXISTS approve_checklist_instance(uuid, uuid);

-- The 3-parameter version should already exist and will remain
