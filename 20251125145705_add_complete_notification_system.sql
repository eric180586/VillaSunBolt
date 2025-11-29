/*
  # Complete Notification System with Push

  ## New Notifications Added
  
  1. Task System:
     - ✅ Task created → All staff (broadcast)
     - ✅ Task deadline approaching → Assigned user or all staff
     - ✅ Task deadline expired → Admin + all users
     - ✅ Fixed: Task assigned notification formatting
  
  2. Reception Notes:
     - ✅ Reception note → Admins too (was only staff)
  
  3. Schedule System:
     - ✅ Time-off request created → All admins
  
  4. Patrol Rounds:
     - ✅ Patrol deadline approaching → Assigned user or all staff
     - ✅ Patrol deadline expired → Admin + all users
  
  ## Changes
  - All notifications now properly formatted
  - All notifications have push integration
  - Multilingual support where applicable
*/

-- ============================================================================
-- 1. FIX: Task Assignment Notification - Better formatting
-- ============================================================================

CREATE OR REPLACE FUNCTION notify_task_assignment()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task_title text;
BEGIN
  -- Only send notification for non-template tasks with assigned user
  IF NEW.is_template = false AND NEW.assigned_to IS NOT NULL THEN
    v_task_title := NEW.title;

    -- Create in-app notification
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
      NEW.assigned_to,
      'task_assigned',
      'Neue Aufgabe',
      'New Task',
      'កិច្ចការថ្មី',
      'Dir wurde eine neue Aufgabe zugewiesen: "' || v_task_title || '"',
      'You have been assigned a new task: "' || v_task_title || '"',
      'អ្នកត្រូវបានចាត់តាំងកិច្ចការថ្មី: "' || v_task_title || '"'
    );

    -- Send push notification
    PERFORM send_push_via_edge_function(
      p_user_ids := ARRAY[NEW.assigned_to::text],
      p_title := 'New Task',
      p_body := 'You have been assigned: "' || v_task_title || '"',
      p_data := jsonb_build_object(
        'type', 'task_assigned',
        'task_id', NEW.id
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

-- ============================================================================
-- 2. NEW: Task Created Broadcast (to all staff)
-- ============================================================================

CREATE OR REPLACE FUNCTION notify_task_created_broadcast()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_staff_user record;
  v_staff_ids text[];
BEGIN
  -- Broadcast to all staff when a new task is created (not assigned yet)
  IF NEW.is_template = false AND NEW.assigned_to IS NULL THEN
    v_staff_ids := ARRAY[]::text[];

    FOR v_staff_user IN
      SELECT id FROM profiles WHERE role = 'staff'
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
        v_staff_user.id,
        'task_available',
        'Neue Aufgabe verfügbar',
        'New Task Available',
        'កិច្ចការថ្មីមាន',
        'Neue Aufgabe verfügbar: "' || NEW.title || '"',
        'New task available: "' || NEW.title || '"',
        'កិច្ចការថ្មីមាន: "' || NEW.title || '"'
      );

      v_staff_ids := array_append(v_staff_ids, v_staff_user.id::text);
    END LOOP;

    -- Send push to all staff
    IF array_length(v_staff_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_staff_ids,
        p_title := 'New Task Available',
        p_body := 'New task available: "' || NEW.title || '"',
        p_data := jsonb_build_object(
          'type', 'task_available',
          'task_id', NEW.id
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger for task broadcast
DROP TRIGGER IF EXISTS trigger_notify_task_created_broadcast ON tasks;
CREATE TRIGGER trigger_notify_task_created_broadcast
  AFTER INSERT ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION notify_task_created_broadcast();

-- ============================================================================
-- 3. NEW: Task Deadline Approaching (Cron Job)
-- ============================================================================

CREATE OR REPLACE FUNCTION check_task_deadlines_approaching()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task record;
  v_staff_ids text[];
  v_staff_user record;
  v_time_until_deadline interval;
BEGIN
  -- Find tasks where deadline is approaching
  -- Notification time = deadline - task duration
  FOR v_task IN
    SELECT 
      t.id,
      t.title,
      t.assigned_to,
      t.due_date,
      t.duration_minutes
    FROM tasks t
    WHERE t.status IN ('pending', 'in_progress')
      AND t.due_date IS NOT NULL
      AND t.duration_minutes IS NOT NULL
      AND t.due_date > NOW()
      AND t.due_date <= NOW() + (t.duration_minutes || ' minutes')::interval
      AND NOT EXISTS (
        SELECT 1 FROM notifications
        WHERE type = 'task_deadline_approaching'
        AND message_en LIKE '%' || t.title || '%'
        AND created_at > NOW() - interval '1 day'
      )
  LOOP
    v_time_until_deadline := v_task.due_date - NOW();

    IF v_task.assigned_to IS NOT NULL THEN
      -- Notify assigned user
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
        v_task.assigned_to,
        'task_deadline_approaching',
        'Deadline naht',
        'Deadline Approaching',
        'ថ្ងៃផុតកំណត់ខិតជិតមកដល់',
        'Deadline für "' || v_task.title || '" naht! Verbleibende Zeit: ' || EXTRACT(HOUR FROM v_time_until_deadline) || 'h',
        'Deadline for "' || v_task.title || '" is approaching! Time remaining: ' || EXTRACT(HOUR FROM v_time_until_deadline) || 'h',
        'ថ្ងៃផុតកំណត់សម្រាប់ "' || v_task.title || '" ខិតជិតមកដល់! ពេលវេលានៅសល់: ' || EXTRACT(HOUR FROM v_time_until_deadline) || 'ម៉ោង'
      );

      PERFORM send_push_via_edge_function(
        p_user_ids := ARRAY[v_task.assigned_to::text],
        p_title := 'Deadline Approaching',
        p_body := 'Deadline for "' || v_task.title || '" is approaching!',
        p_data := jsonb_build_object('type', 'task_deadline_approaching', 'task_id', v_task.id)
      );
    ELSE
      -- Notify all staff
      v_staff_ids := ARRAY[]::text[];

      FOR v_staff_user IN
        SELECT id FROM profiles WHERE role = 'staff'
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
          v_staff_user.id,
          'task_deadline_approaching',
          'Deadline naht',
          'Deadline Approaching',
          'ថ្ងៃផុតកំណត់ខិតជិតមកដល់',
          'Deadline für "' || v_task.title || '" naht! Wer übernimmt?',
          'Deadline for "' || v_task.title || '" is approaching! Who will take it?',
          'ថ្ងៃផុតកំណត់សម្រាប់ "' || v_task.title || '" ខិតជិតមកដល់! តើនរណាទទួលយក?'
        );

        v_staff_ids := array_append(v_staff_ids, v_staff_user.id::text);
      END LOOP;

      IF array_length(v_staff_ids, 1) > 0 THEN
        PERFORM send_push_via_edge_function(
          p_user_ids := v_staff_ids,
          p_title := 'Deadline Approaching',
          p_body := 'Deadline for "' || v_task.title || '" is approaching!',
          p_data := jsonb_build_object('type', 'task_deadline_approaching', 'task_id', v_task.id)
        );
      END IF;
    END IF;
  END LOOP;
END;
$$;

-- ============================================================================
-- 4. NEW: Task Deadline Expired (Cron Job)
-- ============================================================================

CREATE OR REPLACE FUNCTION check_task_deadlines_expired()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task record;
  v_admin_ids text[];
  v_staff_ids text[];
  v_admin record;
  v_staff record;
BEGIN
  -- Find overdue tasks
  FOR v_task IN
    SELECT 
      t.id,
      t.title,
      t.assigned_to,
      t.due_date
    FROM tasks t
    WHERE t.status IN ('pending', 'in_progress')
      AND t.due_date IS NOT NULL
      AND t.due_date < NOW()
      AND NOT EXISTS (
        SELECT 1 FROM notifications
        WHERE type = 'task_deadline_expired'
        AND message_en LIKE '%' || t.title || '%'
        AND created_at > NOW() - interval '1 day'
      )
  LOOP
    v_admin_ids := ARRAY[]::text[];
    v_staff_ids := ARRAY[]::text[];

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
        'task_deadline_expired',
        'Deadline abgelaufen!',
        'Deadline Expired!',
        'ថ្ងៃផុតកំណត់ផុតពេល!',
        'Deadline für "' || v_task.title || '" ist abgelaufen!',
        'Deadline for "' || v_task.title || '" has expired!',
        'ថ្ងៃផុតកំណត់សម្រាប់ "' || v_task.title || '" ផុតពេលហើយ!'
      );

      v_admin_ids := array_append(v_admin_ids, v_admin.id::text);
    END LOOP;

    -- Notify all users
    FOR v_staff IN
      SELECT id FROM profiles WHERE role IN ('staff', 'admin')
    LOOP
      IF v_staff.id != ANY(v_admin_ids::uuid[]) THEN
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
          v_staff.id,
          'task_deadline_expired',
          'Deadline überschritten',
          'Deadline Missed',
          'ថ្ងៃផុតកំណត់ខកខាន',
          'Deadline für "' || v_task.title || '" wurde überschritten',
          'Deadline for "' || v_task.title || '" has been missed',
          'ថ្ងៃផុតកំណត់សម្រាប់ "' || v_task.title || '" ត្រូវបានខកខាន'
        );

        v_staff_ids := array_append(v_staff_ids, v_staff.id::text);
      END IF;
    END LOOP;

    -- Send push to admins
    IF array_length(v_admin_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_admin_ids,
        p_title := 'Deadline Expired!',
        p_body := 'Task "' || v_task.title || '" deadline has expired!',
        p_data := jsonb_build_object('type', 'task_deadline_expired', 'task_id', v_task.id)
      );
    END IF;

    -- Send push to all staff
    IF array_length(v_staff_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_staff_ids,
        p_title := 'Deadline Missed',
        p_body := 'Task "' || v_task.title || '" deadline was missed',
        p_data := jsonb_build_object('type', 'task_deadline_expired', 'task_id', v_task.id)
      );
    END IF;
  END LOOP;
END;
$$;

-- ============================================================================
-- 5. FIX: Reception Note - Notify Admins Too
-- ============================================================================

CREATE OR REPLACE FUNCTION notify_reception_note()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user record;
  v_all_user_ids text[];
  v_note_preview text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Create note preview
    v_note_preview := substring(NEW.content, 1, 100);
    IF length(NEW.content) > 100 THEN
      v_note_preview := v_note_preview || '...';
    END IF;

    v_all_user_ids := ARRAY[]::text[];

    -- Notify ALL users (staff + admin)
    FOR v_user IN
      SELECT id FROM profiles WHERE role IN ('staff', 'admin')
    LOOP
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        v_user.id,
        -- Use a generic title for all notes instead of the old reception-specific title
        'New Note',
        v_note_preview,
        -- Store notes under the generic "info" type to match the allowed notification types
        'info'
      );

      v_all_user_ids := array_append(v_all_user_ids, v_user.id::text);
    END LOOP;

    IF array_length(v_all_user_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_all_user_ids,
        -- Push notifications will have a generic title for notes
        p_title := 'New Note',
        p_body := v_note_preview,
        -- Provide metadata indicating this is an info note
        p_data := jsonb_build_object(
          'type', 'info',
          'note_id', NEW.id
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- ============================================================================
-- 6. NEW: Time-Off Request (Freiwunsch)
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
    -- Get staff name
    SELECT full_name INTO v_staff_name
    FROM profiles
    WHERE id = NEW.user_id;

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

-- Create trigger for time-off requests
DROP TRIGGER IF EXISTS trigger_notify_time_off_request ON time_off_requests;
CREATE TRIGGER trigger_notify_time_off_request
  AFTER INSERT ON time_off_requests
  FOR EACH ROW
  EXECUTE FUNCTION notify_time_off_request();

-- ============================================================================
-- 7. NEW: Patrol Deadline Approaching
-- ============================================================================

CREATE OR REPLACE FUNCTION check_patrol_deadlines_approaching()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_patrol record;
  v_staff_ids text[];
  v_staff_user record;
  v_time_until_deadline interval;
  v_patrol_duration interval := interval '15 minutes'; -- Estimated patrol duration
BEGIN
  -- Find patrol rounds where deadline is approaching
  FOR v_patrol IN
    SELECT 
      pr.id,
      pr.assigned_to,
      pr.date,
      pr.time_slot,
      (pr.date + pr.time_slot) as deadline_time
    FROM patrol_rounds pr
    WHERE pr.completed_at IS NULL
      AND (pr.date + pr.time_slot) > NOW()
      AND (pr.date + pr.time_slot) <= NOW() + v_patrol_duration
      AND NOT EXISTS (
        SELECT 1 FROM notifications
        WHERE type = 'patrol_deadline_approaching'
        AND created_at > NOW() - interval '1 hour'
        AND (message_en LIKE '%' || to_char(pr.time_slot, 'HH24:MI') || '%')
      )
  LOOP
    v_time_until_deadline := v_patrol.deadline_time - NOW();

    IF v_patrol.assigned_to IS NOT NULL THEN
      -- Notify assigned user
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
        v_patrol.assigned_to,
        'patrol_deadline_approaching',
        'Patrouille fällig',
        'Patrol Due',
        'ការល៉មដែកដល់ពេល',
        'Patrouille um ' || to_char(v_patrol.time_slot, 'HH24:MI') || ' Uhr fällig!',
        'Patrol round at ' || to_char(v_patrol.time_slot, 'HH24:MI') || ' is due!',
        'ការល៉មដែកនៅ ' || to_char(v_patrol.time_slot, 'HH24:MI') || ' ដល់ពេលហើយ!'
      );

      PERFORM send_push_via_edge_function(
        p_user_ids := ARRAY[v_patrol.assigned_to::text],
        p_title := 'Patrol Due',
        p_body := 'Patrol round at ' || to_char(v_patrol.time_slot, 'HH24:MI') || ' is due!',
        p_data := jsonb_build_object('type', 'patrol_deadline_approaching', 'patrol_id', v_patrol.id)
      );
    ELSE
      -- Notify all staff
      v_staff_ids := ARRAY[]::text[];

      FOR v_staff_user IN
        SELECT id FROM profiles WHERE role = 'staff'
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
          v_staff_user.id,
          'patrol_deadline_approaching',
          'Patrouille fällig',
          'Patrol Due',
          'ការល៉មដែកដល់ពេល',
          'Patrouille um ' || to_char(v_patrol.time_slot, 'HH24:MI') || ' Uhr - Wer übernimmt?',
          'Patrol round at ' || to_char(v_patrol.time_slot, 'HH24:MI') || ' - Who will do it?',
          'ការល៉មដែកនៅ ' || to_char(v_patrol.time_slot, 'HH24:MI') || ' - តើនរណាធ្វើ?'
        );

        v_staff_ids := array_append(v_staff_ids, v_staff_user.id::text);
      END LOOP;

      IF array_length(v_staff_ids, 1) > 0 THEN
        PERFORM send_push_via_edge_function(
          p_user_ids := v_staff_ids,
          p_title := 'Patrol Due',
          p_body := 'Patrol round at ' || to_char(v_patrol.time_slot, 'HH24:MI') || ' needs to be done!',
          p_data := jsonb_build_object('type', 'patrol_deadline_approaching', 'patrol_id', v_patrol.id)
        );
      END IF;
    END IF;
  END LOOP;
END;
$$;

-- ============================================================================
-- 8. NEW: Patrol Deadline Expired
-- ============================================================================

CREATE OR REPLACE FUNCTION check_patrol_deadlines_expired()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_patrol record;
  v_admin_ids text[];
  v_staff_ids text[];
  v_admin record;
  v_staff record;
  v_assigned_name text;
BEGIN
  -- Find overdue patrol rounds
  FOR v_patrol IN
    SELECT 
      pr.id,
      pr.assigned_to,
      pr.date,
      pr.time_slot,
      (pr.date + pr.time_slot + interval '15 minutes') as grace_deadline
    FROM patrol_rounds pr
    WHERE pr.completed_at IS NULL
      AND (pr.date + pr.time_slot + interval '15 minutes') < NOW()
      AND NOT EXISTS (
        SELECT 1 FROM notifications
        WHERE type = 'patrol_deadline_expired'
        AND created_at > NOW() - interval '2 hours'
        AND (message_en LIKE '%' || to_char(pr.time_slot, 'HH24:MI') || '%')
      )
  LOOP
    v_admin_ids := ARRAY[]::text[];
    v_staff_ids := ARRAY[]::text[];

    -- Get assigned user name if exists
    IF v_patrol.assigned_to IS NOT NULL THEN
      SELECT full_name INTO v_assigned_name
      FROM profiles
      WHERE id = v_patrol.assigned_to;
    END IF;

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
        'patrol_deadline_expired',
        'Patrouille verpasst!',
        'Patrol Missed!',
        'ការល៉មដែកខកខាន!',
        'Patrouille um ' || to_char(v_patrol.time_slot, 'HH24:MI') || ' Uhr wurde verpasst!' ||
          CASE WHEN v_assigned_name IS NOT NULL THEN ' (Zugewiesen: ' || v_assigned_name || ')' ELSE '' END,
        'Patrol round at ' || to_char(v_patrol.time_slot, 'HH24:MI') || ' was missed!' ||
          CASE WHEN v_assigned_name IS NOT NULL THEN ' (Assigned: ' || v_assigned_name || ')' ELSE '' END,
        'ការល៉មដែកនៅ ' || to_char(v_patrol.time_slot, 'HH24:MI') || ' ខកខានហើយ!' ||
          CASE WHEN v_assigned_name IS NOT NULL THEN ' (ចាត់តាំង: ' || v_assigned_name || ')' ELSE '' END
      );

      v_admin_ids := array_append(v_admin_ids, v_admin.id::text);
    END LOOP;

    -- Notify all users
    FOR v_staff IN
      SELECT id FROM profiles WHERE role IN ('staff', 'admin')
    LOOP
      IF v_staff.id != ANY(v_admin_ids::uuid[]) THEN
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
          v_staff.id,
          'patrol_deadline_expired',
          'Patrouille überfällig',
          'Patrol Overdue',
          'ការល៉មដែកយឺតយ៉ាវ',
          'Patrouille um ' || to_char(v_patrol.time_slot, 'HH24:MI') || ' Uhr wurde nicht durchgeführt',
          'Patrol round at ' || to_char(v_patrol.time_slot, 'HH24:MI') || ' was not completed',
          'ការល៉មដែកនៅ ' || to_char(v_patrol.time_slot, 'HH24:MI') || ' មិនត្រូវបានបញ្ចប់'
        );

        v_staff_ids := array_append(v_staff_ids, v_staff.id::text);
      END IF;
    END LOOP;

    -- Send push to admins
    IF array_length(v_admin_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_admin_ids,
        p_title := 'Patrol Missed!',
        p_body := 'Patrol at ' || to_char(v_patrol.time_slot, 'HH24:MI') || ' was missed!',
        p_data := jsonb_build_object('type', 'patrol_deadline_expired', 'patrol_id', v_patrol.id)
      );
    END IF;

    -- Send push to all staff
    IF array_length(v_staff_ids, 1) > 0 THEN
      PERFORM send_push_via_edge_function(
        p_user_ids := v_staff_ids,
        p_title := 'Patrol Overdue',
        p_body := 'Patrol at ' || to_char(v_patrol.time_slot, 'HH24:MI') || ' was not completed',
        p_data := jsonb_build_object('type', 'patrol_deadline_expired', 'patrol_id', v_patrol.id)
      );
    END IF;
  END LOOP;
END;
$$;

-- ============================================================================
-- Add comments for documentation
-- ============================================================================

COMMENT ON FUNCTION notify_task_assignment IS 
'Sends notification when a task is assigned to a specific user. Improved formatting.';

COMMENT ON FUNCTION notify_task_created_broadcast IS 
'Broadcasts to all staff when a new unassigned task is created.';

COMMENT ON FUNCTION check_task_deadlines_approaching IS 
'Cron job: Checks for tasks approaching deadline. Notification time = deadline - task duration.';

COMMENT ON FUNCTION check_task_deadlines_expired IS 
'Cron job: Checks for expired task deadlines. Notifies admins and all users.';

COMMENT ON FUNCTION notify_reception_note IS 
'Sends reception note to all staff AND admins (was only staff before).';

COMMENT ON FUNCTION notify_time_off_request IS 
'Notifies all admins when a staff member requests time off.';

COMMENT ON FUNCTION check_patrol_deadlines_approaching IS 
'Cron job: Checks for patrol rounds approaching deadline (15min before).';

COMMENT ON FUNCTION check_patrol_deadlines_expired IS 
'Cron job: Checks for missed patrol rounds. Notifies admins and all users.';
