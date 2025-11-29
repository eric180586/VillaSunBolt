/*
  # Update Departure Approved Message to Khmer
  
  Changes the departure approved notification message to use Khmer script:
  "Go Go - ទៅ ទៅ" instead of "Dtow Dtow :)"
*/

-- Update notification function for approved departure with Khmer text
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
      'ទៅ ទៅ',
      'departure_approved',
      'high'
    );

    -- Send push notification
    PERFORM send_push_via_edge_function(
      p_user_ids := ARRAY[NEW.user_id::text],
      p_title := 'Go Go',
      p_body := 'ទៅ ទៅ',
      p_data := jsonb_build_object('type', 'departure_approved')
    );
  END IF;

  RETURN NEW;
END;
$$;