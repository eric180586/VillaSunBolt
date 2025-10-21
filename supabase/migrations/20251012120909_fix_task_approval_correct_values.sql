/*
  # Task Approval mit korrekten Punktewerten
  
  ## Änderungen:
  - Deadline Bonus: +1 Punkt (nicht +2)
  - Reopen Penalty: -1 Punkt pro Reopen
  - Sekundärer Mitarbeiter: 50% von ALLEM
  - Initial points value wird gespeichert für erreichbare Punkte Berechnung
*/

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
  v_secondary_points integer;
  v_reason text;
  v_is_within_deadline boolean := false;
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
      v_deadline_bonus := 1; -- KORREKTUR: +1 Punkt statt +2
    END IF;
  END IF;

  -- Reopen-Penalty: -1 Punkt pro Reopen
  IF v_task.reopened_count > 0 THEN
    v_reopen_penalty := v_task.reopened_count * (-1);
  END IF;

  -- Gesamtpunkte für Primary User
  v_total_points := v_base_points + v_deadline_bonus + v_reopen_penalty;
  
  -- Mindestens 0 Punkte
  IF v_total_points < 0 THEN
    v_total_points := 0;
  END IF;

  -- Sekundärer Mitarbeiter: 50% von ALLEM (nicht nur von Basis)
  v_secondary_points := GREATEST((v_base_points + v_deadline_bonus + v_reopen_penalty) / 2, 0);

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

  -- Zufällige Feedback-Nachricht
  v_feedback_message := v_feedback_messages[1 + floor(random() * array_length(v_feedback_messages, 1))::int];

  -- Punkte vergeben an Hauptmitarbeiter
  IF v_task.assigned_to IS NOT NULL AND v_total_points > 0 THEN
    v_reason := 'Aufgabe erledigt: ' || v_task.title;
    
    IF v_deadline_bonus > 0 THEN
      v_reason := v_reason || ' (✓ Deadline-Bonus +1)';
    END IF;
    
    IF v_reopen_penalty < 0 THEN
      v_reason := v_reason || ' (' || v_reopen_penalty || ' wegen ' || v_task.reopened_count || 'x Reopen)';
    END IF;

    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (v_task.assigned_to, v_total_points, v_reason, 'task_completed', p_admin_id);

    -- Punkteziele updaten
    PERFORM update_daily_point_goals(v_task.assigned_to, CURRENT_DATE);

    -- Notification
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_task.assigned_to,
      'Sehr gut gemacht! 🌟',
      v_feedback_message || ' +' || v_total_points || ' Punkte für: ' || v_task.title,
      'success'
    );
  END IF;

  -- Punkte vergeben an zweiten Mitarbeiter (50% von allem)
  IF v_task.secondary_assigned_to IS NOT NULL AND v_secondary_points > 0 THEN
    v_reason := 'Aufgabe erledigt (Assistent): ' || v_task.title;

    IF v_deadline_bonus > 0 THEN
      v_reason := v_reason || ' (✓ Deadline-Bonus +0.5)';
    END IF;

    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (v_task.secondary_assigned_to, v_secondary_points, v_reason, 'task_completed', p_admin_id);

    -- Punkteziele updaten
    PERFORM update_daily_point_goals(v_task.secondary_assigned_to, CURRENT_DATE);

    -- Notification
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_task.secondary_assigned_to,
      'Sehr gut gemacht! 🌟',
      v_feedback_message || ' +' || v_secondary_points || ' Punkte für: ' || v_task.title,
      'success'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'base_points', v_base_points,
    'deadline_bonus', v_deadline_bonus,
    'reopen_penalty', v_reopen_penalty,
    'total_points', v_total_points,
    'secondary_points', v_secondary_points,
    'within_deadline', v_is_within_deadline
  );
END;
$$;
