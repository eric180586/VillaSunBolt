/*
  # Update Scheduled Notification Functions with Push
  
  1. Updates
    - notify_patrol_due (called by pg_cron)
    - notify_task_deadline_approaching (called by pg_cron)
  
  2. Behavior
    - These functions are called on schedule, not by triggers
    - Now also send push notifications via Edge Function
*/

-- Update notify_patrol_due to send push
CREATE OR REPLACE FUNCTION notify_patrol_due(p_patrol_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_assigned_user uuid;
  v_scheduled_time timestamptz;
BEGIN
  SELECT assigned_to, scheduled_time INTO v_assigned_user, v_scheduled_time
  FROM patrol_rounds
  WHERE id = p_patrol_id;

  IF v_assigned_user IS NOT NULL AND now() >= v_scheduled_time + interval '5 minutes' THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_assigned_user,
      'Time for checking',
      ':)',
      'patrol_due'
    );

    -- Send push notification
    PERFORM send_push_via_edge_function(
      p_user_ids := ARRAY[v_assigned_user::text],
      p_title := 'Time for checking',
      p_body := ':)',
      p_data := jsonb_build_object('type', 'patrol_due', 'patrol_id', p_patrol_id)
    );
  END IF;
END;
$$;

-- Update notify_task_deadline_approaching to send push
CREATE OR REPLACE FUNCTION notify_task_deadline_approaching()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task record;
  v_staff_user record;
  v_time_until_deadline interval;
  v_staff_ids text[];
BEGIN
  FOR v_task IN 
    SELECT t.id, t.title, t.assigned_to, t.due_date, t.estimated_duration
    FROM tasks t
    WHERE t.status NOT IN ('completed', 'cancelled', 'archived')
    AND t.due_date IS NOT NULL
    AND t.due_date > now()
  LOOP
    v_time_until_deadline := v_task.due_date - COALESCE(v_task.estimated_duration, interval '0 minutes') - now();

    IF v_time_until_deadline <= interval '5 minutes' AND v_time_until_deadline >= interval '0 minutes' THEN
      v_staff_ids := ARRAY[]::text[];

      IF v_task.assigned_to IS NOT NULL THEN
        IF NOT EXISTS (
          SELECT 1 FROM notifications 
          WHERE user_id = v_task.assigned_to 
          AND type = 'task_deadline'
          AND message LIKE '%' || v_task.id::text || '%'
          AND created_at > now() - interval '1 hour'
        ) THEN
          INSERT INTO notifications (user_id, title, message, type)
          VALUES (
            v_task.assigned_to,
            'Oh oh, time is running',
            'Don´t forget',
            'task_deadline'
          );
          
          v_staff_ids := ARRAY[v_task.assigned_to::text];
        END IF;
      ELSE
        FOR v_staff_user IN 
          SELECT DISTINCT s.staff_id
          FROM schedules s
          WHERE s.start_time <= now()
          AND s.end_time >= now()
          AND s.staff_id IS NOT NULL
        LOOP
          IF NOT EXISTS (
            SELECT 1 FROM notifications 
            WHERE user_id = v_staff_user.staff_id 
            AND type = 'task_deadline'
            AND message LIKE '%' || v_task.id::text || '%'
            AND created_at > now() - interval '1 hour'
          ) THEN
            INSERT INTO notifications (user_id, title, message, type)
            VALUES (
              v_staff_user.staff_id,
              'Oh oh, time is running',
              'Don´t forget',
              'task_deadline'
            );
            
            v_staff_ids := array_append(v_staff_ids, v_staff_user.staff_id::text);
          END IF;
        END LOOP;
      END IF;

      -- Send push notification
      IF array_length(v_staff_ids, 1) > 0 THEN
        PERFORM send_push_via_edge_function(
          p_user_ids := v_staff_ids,
          p_title := 'Oh oh, time is running',
          p_body := 'Don´t forget',
          p_data := jsonb_build_object('type', 'task_deadline', 'task_id', v_task.id)
        );
      END IF;
    END IF;
  END LOOP;
END;
$$;
