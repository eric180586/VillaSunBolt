/*
  # Cleanup Old process_check_in Functions

  ## Problem
  - Multiple versions of process_check_in exist
  - Old versions without p_late_reason parameter may cause conflicts
  - CheckInPopup calls with (p_user_id, p_shift_type, p_late_reason)
  
  ## Solution
  - Drop all old function signatures
  - Keep only the latest version with (p_user_id, p_shift_type, p_late_reason)
*/

-- Drop old versions if they exist
DROP FUNCTION IF EXISTS process_check_in(uuid);
DROP FUNCTION IF EXISTS process_check_in(uuid, text);

-- The current version with all 3 parameters should remain:
-- process_check_in(uuid, text, text)
