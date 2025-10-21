/*
  # Fix notify_new_task function to use correct notification type

  ## Problem
  - notify_new_task() function uses type 'new_task'
  - But notifications_type_check constraint only allows: 'info', 'success', 'warning', 'error', 'task', etc.
  - This causes INSERT failures when creating tasks

  ## Solution
  - Change 'new_task' to 'task' in the function
*/

CREATE OR REPLACE FUNCTION notify_new_task()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_staff_user record;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.assigned_to IS NOT NULL THEN
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        NEW.assigned_to,
        'Busy?',
        'Next To Do :)',
        'task'
      );
    ELSE
      FOR v_staff_user IN 
        SELECT DISTINCT s.staff_id
        FROM schedules s
        WHERE s.start_time <= now()
        AND s.end_time >= now()
        AND s.staff_id IS NOT NULL
      LOOP
        INSERT INTO notifications (user_id, title, message, type)
        VALUES (
          v_staff_user.staff_id,
          'Busy?',
          'Next To Do :)',
          'task'
        );
      END LOOP;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
