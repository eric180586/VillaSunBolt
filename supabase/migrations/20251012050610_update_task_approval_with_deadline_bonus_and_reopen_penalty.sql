/*
  # Task Approval mit Deadline-Bonus und Reopen-Penalty

  ## Änderungen
  1. Erweitere Task-Approval-Funktion um:
     - Deadline-Bonus von +2 Punkten wenn innerhalb der Deadline erledigt
     - Reopen-Penalty von -1 Punkt pro Reopen
     - Automatisches Update der daily_point_goals
     - Positive Feedback-Nachrichten

  2. Neue Funktion für Task-Reopen mit Punktabzug

  3. Trigger zum automatischen Update der Punkteziele

  ## Positive Feedback-Nachrichten
  - Bei Zielerreichung motivierende Nachrichten
  - Bei 90% Tages-/Monatsziel spezielle Belohnungsnachrichten
*/

-- Funktion für Task-Approval mit Deadline-Bonus
CREATE OR REPLACE FUNCTION approve_task_with_points(
  p_task_id uuid,
  p_admin_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_task record;
  v_base_points integer;
  v_deadline_bonus integer := 0;
  v_reopen_penalty integer := 0;
  v_total_points integer;
  v_reason text;
  v_is_within_deadline boolean := false;
  v_user_name text;
  v_feedback_messages text[] := ARRAY[
    'Fantastische Arbeit! Du bist ein Star!',
    'Hervorragend! Weiter so!',
    'Großartig gemacht! Das Team ist stolz auf dich!',
    'Perfekt! Deine Hingabe zahlt sich aus!',
    'Ausgezeichnet! Du machst den Unterschied!',
    'Wunderbar! Keep up the great work!',
    'Super Leistung! Du rockst!',
    'Brillant! Deine Arbeit ist inspirierend!'
  ];
  v_feedback_message text;
BEGIN
  -- Verify admin role
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = p_admin_id
    AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can approve tasks';
  END IF;

  -- Get task details
  SELECT * INTO v_task
  FROM tasks
  WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;
  
  IF v_task.status != 'pending_review' THEN
    RAISE EXCEPTION 'Task is not pending review';
  END IF;

  -- Basis-Punkte
  v_base_points := v_task.points_value;

  -- Prüfe ob innerhalb der Deadline erledigt
  IF v_task.due_date IS NOT NULL THEN
    v_is_within_deadline := v_task.completed_at <= v_task.due_date;
    IF v_is_within_deadline AND NOT v_task.deadline_bonus_awarded THEN
      v_deadline_bonus := 2;
    END IF;
  END IF;

  -- Reopen-Penalty: -1 Punkt pro Reopen
  IF v_task.reopened_count > 0 THEN
    v_reopen_penalty := v_task.reopened_count * (-1);
  END IF;

  -- Gesamtpunkte
  v_total_points := v_base_points + v_deadline_bonus + v_reopen_penalty;
  
  -- Mindestens 0 Punkte
  IF v_total_points < 0 THEN
    v_total_points := 0;
  END IF;

  -- Update task status
  UPDATE tasks
  SET 
    status = 'completed',
    completed_at = COALESCE(completed_at, now()),
    deadline_bonus_awarded = (v_deadline_bonus > 0),
    initial_points_value = COALESCE(initial_points_value, points_value),
    points_value = v_total_points,
    updated_at = now()
  WHERE id = p_task_id;

  -- Punkte vergeben an Hauptmitarbeiter
  IF v_task.assigned_to IS NOT NULL AND v_total_points > 0 THEN
    v_reason := 'Aufgabe erledigt: ' || v_task.title;
    
    IF v_deadline_bonus > 0 THEN
      v_reason := v_reason || ' (✓ Deadline-Bonus +2)';
    END IF;
    
    IF v_reopen_penalty < 0 THEN
      v_reason := v_reason || ' (' || v_reopen_penalty || ' wegen ' || v_task.reopened_count || 'x Reopen)';
    END IF;

    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (v_task.assigned_to, v_total_points, v_reason, 'task_completed', p_admin_id);

    -- Punkteziele updaten
    PERFORM update_daily_point_goals(v_task.assigned_to, CURRENT_DATE);
  END IF;

  -- Punkte vergeben an zweiten Mitarbeiter (halbe Punkte)
  IF v_task.secondary_assigned_to IS NOT NULL THEN
    v_total_points := GREATEST(v_total_points / 2, 0);
    v_reason := 'Aufgabe erledigt (Assistent): ' || v_task.title;

    IF v_deadline_bonus > 0 THEN
      v_reason := v_reason || ' (✓ Deadline-Bonus +1)';
    END IF;

    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (v_task.secondary_assigned_to, v_total_points, v_reason, 'task_completed', p_admin_id);

    -- Punkteziele updaten
    PERFORM update_daily_point_goals(v_task.secondary_assigned_to, CURRENT_DATE);
  END IF;

  -- Zufällige Feedback-Nachricht auswählen
  v_feedback_message := v_feedback_messages[1 + floor(random() * array_length(v_feedback_messages, 1))::int];

  -- Get user name
  SELECT full_name INTO v_user_name
  FROM profiles
  WHERE id = v_task.assigned_to;

  -- Notification an Mitarbeiter mit positivem Feedback
  IF v_task.assigned_to IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_task.assigned_to,
      'Sehr gut gemacht! 🌟',
      v_feedback_message || ' +' || (v_base_points + v_deadline_bonus + v_reopen_penalty) || ' Punkte für: ' || v_task.title,
      'success'
    );
  END IF;

  IF v_task.secondary_assigned_to IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_task.secondary_assigned_to,
      'Sehr gut gemacht! 🌟',
      v_feedback_message || ' +' || GREATEST((v_base_points + v_deadline_bonus + v_reopen_penalty) / 2, 0) || ' Punkte für: ' || v_task.title,
      'success'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'base_points', v_base_points,
    'deadline_bonus', v_deadline_bonus,
    'reopen_penalty', v_reopen_penalty,
    'total_points', v_total_points,
    'within_deadline', v_is_within_deadline
  );
END;
$$;

-- Funktion für Task-Reopen
CREATE OR REPLACE FUNCTION reopen_task_with_penalty(
  p_task_id uuid,
  p_admin_id uuid,
  p_admin_notes text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_task record;
BEGIN
  -- Verify admin role
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = p_admin_id
    AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can reopen tasks';
  END IF;

  -- Get task details
  SELECT * INTO v_task
  FROM tasks
  WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;

  -- Update task
  UPDATE tasks
  SET 
    status = 'in_progress',
    admin_notes = p_admin_notes,
    reopened_count = COALESCE(reopened_count, 0) + 1,
    updated_at = now()
  WHERE id = p_task_id;

  -- Notification an Mitarbeiter
  IF v_task.assigned_to IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_task.assigned_to,
      'Nicht ganz perfekt',
      'Bitte überarbeite die Aufgabe: ' || v_task.title || '. Hinweis: Jedes Reopen bedeutet -1 Punkt. ' || COALESCE(p_admin_notes, ''),
      'warning'
    );
  END IF;

  IF v_task.secondary_assigned_to IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_task.secondary_assigned_to,
      'Nicht ganz perfekt',
      'Bitte überarbeite die Aufgabe: ' || v_task.title || '. Hinweis: Jedes Reopen bedeutet -1 Punkt. ' || COALESCE(p_admin_notes, ''),
      'warning'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'reopened_count', COALESCE(v_task.reopened_count, 0) + 1
  );
END;
$$;

-- Trigger zum automatischen Update der daily_point_goals bei Punkteänderungen
CREATE OR REPLACE FUNCTION trigger_update_daily_goals()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Update für den betroffenen User
  PERFORM update_daily_point_goals(NEW.user_id, DATE(NEW.created_at));
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS points_history_update_daily_goals ON points_history;

CREATE TRIGGER points_history_update_daily_goals
AFTER INSERT ON points_history
FOR EACH ROW
EXECUTE FUNCTION trigger_update_daily_goals();

-- Funktion zum Senden von Erfolgs-Benachrichtigungen
CREATE OR REPLACE FUNCTION check_and_notify_achievements(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_daily_goal record;
  v_monthly_progress jsonb;
  v_user_name text;
  v_notification_exists boolean;
BEGIN
  -- Hole aktuelles Tagesziel
  SELECT * INTO v_daily_goal
  FROM daily_point_goals
  WHERE user_id = p_user_id
  AND goal_date = p_date;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Hole User-Name
  SELECT full_name INTO v_user_name
  FROM profiles
  WHERE id = p_user_id;

  -- Prüfe ob 90% Tagesziel erreicht
  IF v_daily_goal.percentage >= 90 AND v_daily_goal.color_status = 'green' THEN
    -- Prüfe ob bereits Benachrichtigung gesendet
    SELECT EXISTS (
      SELECT 1 FROM notifications
      WHERE user_id = p_user_id
      AND DATE(created_at) = p_date
      AND message LIKE '%90% deines Tagesziels%'
    ) INTO v_notification_exists;

    IF NOT v_notification_exists THEN
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        p_user_id,
        'Tagesziel erreicht! 🎉',
        'Fantastisch, ' || v_user_name || '! Du hast ' || ROUND(v_daily_goal.percentage, 1) || '% deines Tagesziels erreicht! (' || v_daily_goal.achieved_points || '/' || v_daily_goal.theoretically_achievable_points || ' Punkte)',
        'success'
      );
    END IF;
  END IF;

  -- Prüfe Monatsziel
  v_monthly_progress := calculate_monthly_progress(p_user_id);
  
  IF (v_monthly_progress->>'percentage')::numeric >= 90 THEN
    -- Prüfe ob bereits Benachrichtigung für diesen Monat gesendet
    SELECT EXISTS (
      SELECT 1 FROM notifications
      WHERE user_id = p_user_id
      AND EXTRACT(YEAR FROM created_at) = EXTRACT(YEAR FROM p_date)
      AND EXTRACT(MONTH FROM created_at) = EXTRACT(MONTH FROM p_date)
      AND message LIKE '%90% deines Monatsziels%'
    ) INTO v_notification_exists;

    IF NOT v_notification_exists THEN
      INSERT INTO notifications (user_id, title, message, type)
      VALUES (
        p_user_id,
        'Monatsziel erreicht! 🏆',
        'Unglaublich, ' || v_user_name || '! Du hast ' || ROUND((v_monthly_progress->>'percentage')::numeric, 1) || '% deines Monatsziels erreicht! Bonus kommt! 💰',
        'success'
      );
    END IF;
  END IF;
END;
$$;

-- Update Trigger für Erfolgsbenachrichtigungen
CREATE OR REPLACE FUNCTION trigger_check_achievements()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Prüfe Erfolge für den User
  PERFORM check_and_notify_achievements(NEW.user_id, NEW.goal_date);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS daily_goals_check_achievements ON daily_point_goals;

CREATE TRIGGER daily_goals_check_achievements
AFTER UPDATE ON daily_point_goals
FOR EACH ROW
WHEN (NEW.percentage >= 90 AND OLD.percentage < 90)
EXECUTE FUNCTION trigger_check_achievements();
