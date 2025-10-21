/*
  # Fix Check-In System - Remove Duplicate Notifications

  ## Problem
  - notify_admin_checkin Trigger sendet 'admin_checkin' Notifications
  - process_check_in sendet bereits 'checkin_pending' Notifications
  - Resultat: Doppelte Notifications mit falschen Typen

  ## Solution
  - Entferne notify_admin_checkin Trigger
  - Nur process_check_in sendet Notifications (Type: checkin_pending)

  ## Changes
  1. DROP TRIGGER notify_admin_checkin_trigger
  2. DROP FUNCTION notify_admin_checkin
*/

-- Drop the duplicate notification trigger
DROP TRIGGER IF EXISTS notify_admin_checkin_trigger ON check_ins;

-- Drop the duplicate notification function
DROP FUNCTION IF EXISTS notify_admin_checkin();
