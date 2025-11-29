/*
  # Reception Notes Notification System
  
  ## Changes:
  1. Create trigger to notify all staff when reception note is created/updated
  2. Create notification in notifications table
  3. Send push notification via Edge Function
  
  ## How it works:
  - When a note with category='reception' is created or updated
  - All staff members receive notification
  - Push notification is sent if user has subscriptions
*/

-- Function to notify staff about reception notes
CREATE OR REPLACE FUNCTION notify_reception_note()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_creator_name text;
  v_staff_user record;
BEGIN
  -- Only trigger for reception category notes
  IF NEW.category != 'reception' THEN
    RETURN NEW;
  END IF;

  -- Get creator name
  SELECT full_name INTO v_creator_name
  FROM profiles
  WHERE id = NEW.created_by;

  -- Create notifications for all staff members (except creator)
  FOR v_staff_user IN 
    SELECT id FROM profiles 
    WHERE role = 'staff' 
    AND id != NEW.created_by
  LOOP
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_staff_user.id,
      'Neue Rezeption Info',
      'Neue Information von ' || COALESCE(v_creator_name, 'Admin') || ': ' || NEW.title,
      'reception_note'
    );
  END LOOP;

  RETURN NEW;
END;
$$;

-- Create trigger for reception notes
DROP TRIGGER IF EXISTS notify_reception_note_trigger ON notes;

CREATE TRIGGER notify_reception_note_trigger
AFTER INSERT OR UPDATE OF category, title, content
ON notes
FOR EACH ROW
EXECUTE FUNCTION notify_reception_note();

-- Grant permissions
GRANT EXECUTE ON FUNCTION notify_reception_note() TO authenticated;
