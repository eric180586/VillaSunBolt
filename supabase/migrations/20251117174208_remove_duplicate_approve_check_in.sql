/*
  # Remove Duplicate approve_check_in Function
  
  1. Changes
    - Keep version with p_admin_id for audit trail
    - Remove version without p_admin_id
    - Frontend uses: approve_check_in(p_check_in_id, p_admin_id, p_custom_points)
*/

-- Remove the version without p_admin_id
DROP FUNCTION IF EXISTS approve_check_in(uuid, integer);
