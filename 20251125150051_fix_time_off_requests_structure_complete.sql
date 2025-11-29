/*
  # Fix Time-Off Requests Table and Notification

  ## Problem
  1. Table has staff_id but notification expects user_id
  2. Table has request_date but notification expects start_date/end_date
  3. Need to add proper columns for date range

  ## Solution
  1. Add user_id as alias/computed column OR rename staff_id
  2. Add start_date and end_date columns
  3. Update notification function to use correct column names
  4. Ensure RLS policies work
*/

-- ============================================================================
-- 1. Add missing columns to time_off_requests
-- ============================================================================

-- Add start_date and end_date if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'time_off_requests' AND column_name = 'start_date'
  ) THEN
    ALTER TABLE time_off_requests ADD COLUMN start_date date NOT NULL DEFAULT CURRENT_DATE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'time_off_requests' AND column_name = 'end_date'
  ) THEN
    ALTER TABLE time_off_requests ADD COLUMN end_date date NOT NULL DEFAULT CURRENT_DATE;
  END IF;
END $$;

-- Remove default after adding columns
ALTER TABLE time_off_requests 
  ALTER COLUMN start_date DROP DEFAULT,
  ALTER COLUMN end_date DROP DEFAULT;

-- ============================================================================
-- 2. Update notify_time_off_request to use staff_id
-- ============================================================================

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

    v_request_dates := to_char(NEW.start_date, 'DD.MM.YYYY') || ' - ' || to_char(NEW.end_date, 'DD.MM.YYYY');
    v_admin_ids := ARRAY[]::text[];

    -- Notify all admins
    FOR v_admin IN
      SELECT id FROM profiles WHERE role = 'admin'
    LOOP
      INSERT INTO notifications (
        user_id,
        type,
        title_de,
        title_en,
        title_km,
        message_de,
        message_en,
        message_km
      ) VALUES (
        v_admin.id,
        'time_off_request',
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

-- ============================================================================
-- 3. Ensure RLS policies exist for time_off_requests
-- ============================================================================

-- Enable RLS
ALTER TABLE time_off_requests ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Staff can view own requests" ON time_off_requests;
DROP POLICY IF EXISTS "Staff can create own requests" ON time_off_requests;
DROP POLICY IF EXISTS "Admins can view all requests" ON time_off_requests;
DROP POLICY IF EXISTS "Admins can update all requests" ON time_off_requests;

-- Staff can view their own requests
CREATE POLICY "Staff can view own requests"
  ON time_off_requests
  FOR SELECT
  TO authenticated
  USING (auth.uid() = staff_id);

-- Staff can create their own requests
CREATE POLICY "Staff can create own requests"
  ON time_off_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = staff_id);

-- Admins can view all requests
CREATE POLICY "Admins can view all requests"
  ON time_off_requests
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Admins can update all requests
CREATE POLICY "Admins can update all requests"
  ON time_off_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- 4. Add request_type column for better categorization
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'time_off_requests' AND column_name = 'request_type'
  ) THEN
    ALTER TABLE time_off_requests 
    ADD COLUMN request_type text DEFAULT 'vacation' CHECK (request_type IN ('vacation', 'sick_leave', 'personal', 'other'));
  END IF;
END $$;

COMMENT ON TABLE time_off_requests IS 
'Staff time-off and vacation requests. Notifies all admins when created.';

COMMENT ON COLUMN time_off_requests.staff_id IS 
'ID of the staff member requesting time off';

COMMENT ON COLUMN time_off_requests.start_date IS 
'First day of time off';

COMMENT ON COLUMN time_off_requests.end_date IS 
'Last day of time off';

COMMENT ON COLUMN time_off_requests.request_type IS 
'Type of request: vacation, sick_leave, personal, other';
