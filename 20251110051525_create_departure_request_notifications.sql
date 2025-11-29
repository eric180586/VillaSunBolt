/*
  # Create Departure Request Notification System
  
  1. Function
    - `notify_admin_departure_request()` - Sends notification to all admins when staff requests departure
    - Includes both database notification and push notification
  
  2. Trigger
    - Fires on INSERT to departure_requests table
    - Notifies all admins immediately
  
  3. Notifications
    - Creates in-app notification for each admin
    - Sends push notification to all admin devices
*/

-- Create notification function for departure requests
CREATE OR REPLACE FUNCTION notify_admin_departure_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin record;
  v_staff_name text;
  v_admin_ids text[];
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Get staff member's name
    SELECT full_name INTO v_staff_name
    FROM profiles
    WHERE id = NEW.user_id;

    v_admin_ids := ARRAY[]::text[];

    -- Create notification for each admin
    FOR v_admin IN 
      SELECT id FROM profiles WHERE role = 'admin'
    LOOP
      INSERT INTO notifications (user_id, title, message, type, priority)
      VALUES (
        v_admin.id,
        'Departure Request',
        COALESCE(v_staff_name, 'Staff') || ' requests to leave early',
        'admin_departure_request',
        'high'
      );
      
      v_admin_ids := array_append(v_admin_ids, v_admin.id::text);
    END LOOP;

    -- Send push notification to all admins
    IF array_length(v_admin_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_admin_ids,
        p_title := 'Departure Request',
        p_body := COALESCE(v_staff_name, 'Staff') || ' requests to leave early',
        p_data := jsonb_build_object('type', 'admin_departure_request')
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Drop trigger if it exists
DROP TRIGGER IF EXISTS notify_admin_departure_request_trigger ON departure_requests;

-- Create trigger for departure requests
CREATE TRIGGER notify_admin_departure_request_trigger
AFTER INSERT ON departure_requests
FOR EACH ROW
EXECUTE FUNCTION notify_admin_departure_request();

-- Create notification function for approved departure
CREATE OR REPLACE FUNCTION notify_departure_approved()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status = 'pending') THEN
    -- Create in-app notification
    INSERT INTO notifications (user_id, title, message, type, priority)
    VALUES (
      NEW.user_id,
      'Go Go',
      'Dtow Dtow :)',
      'departure_approved',
      'high'
    );

    -- Send push notification
    PERFORM send_push_via_edge_function(
      p_user_ids := ARRAY[NEW.user_id::text],
      p_title := 'Go Go',
      p_body := 'Dtow Dtow :)',
      p_data := jsonb_build_object('type', 'departure_approved')
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Drop trigger if it exists
DROP TRIGGER IF EXISTS notify_departure_approved_trigger ON departure_requests;

-- Create trigger for approved departures
CREATE TRIGGER notify_departure_approved_trigger
AFTER UPDATE ON departure_requests
FOR EACH ROW
EXECUTE FUNCTION notify_departure_approved();