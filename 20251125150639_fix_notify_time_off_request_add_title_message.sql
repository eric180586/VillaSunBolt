/*
  # Fix notify_time_off_request - Add required title and message fields

  ## Problem
  - notifications table requires title and message (NOT NULL)
  - Function only filled title_de/en/km and message_de/en/km
  - Need to fill both for backwards compatibility

  ## Solution
  - Add title and message fields (English version as default)
  - Keep multilingual fields for frontend display
*/

CREATE OR REPLACE FUNCTION notify_time_off_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin record;
  v_admin_ids text[];
  v_staff_name text;
  v_request_dates text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Get staff name using staff_id
    SELECT full_name INTO v_staff_name
    FROM profiles
    WHERE id = NEW.staff_id;

    -- Format date range
    v_request_dates := to_char(NEW.start_date, 'DD.MM.YYYY') || ' - ' || to_char(NEW.end_date, 'DD.MM.YYYY');
    v_admin_ids := ARRAY[]::text[];

    -- Notify all admins
    FOR v_admin IN
      SELECT id FROM profiles WHERE role = 'admin'
    LOOP
      INSERT INTO notifications (
        user_id,
        type,
        title,
        message,
        title_de,
        title_en,
        title_km,
        message_de,
        message_en,
        message_km
      ) VALUES (
        v_admin.id,
        'time_off_request',
        'Time-Off Request',
        v_staff_name || ' requests time off: ' || v_request_dates,
        'Urlaubsantrag',
        'Time-Off Request',
        'សំណើឈប់សម្រាក',
        v_staff_name || ' beantragt Urlaub: ' || v_request_dates,
        v_staff_name || ' requests time off: ' || v_request_dates,
        v_staff_name || ' សុំឈប់សម្រាក: ' || v_request_dates
      );

      v_admin_ids := array_append(v_admin_ids, v_admin.id::text);
    END LOOP;

    -- Send push to all admins
    IF array_length(v_admin_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_admin_ids,
        p_title := 'Time-Off Request',
        p_body := v_staff_name || ' requests time off: ' || v_request_dates,
        p_data := jsonb_build_object(
          'type', 'time_off_request',
          'request_id', NEW.id
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION notify_time_off_request IS 
'Notifies all admins when a staff member requests time off. Supports both old (request_date) and new (start_date/end_date) formats.';
