/*
  # Korrektur: Punkteberechnung basierend auf tatsächlichen Check-Ins
  
  ## Änderungen
  1. Check-In Punkte nur für Mitarbeiter die tatsächlich eingestempelt haben
  2. Deadline-Bonus: +1 Punkt (nicht +2)
  3. Theoretisch erreichbare Punkte:
     - Pro eingestempeltem Mitarbeiter: 5 Punkte für Pünktlichkeit
     - Pro offener Task: 5 Punkte + 1 Punkt Deadline-Bonus (falls Deadline gesetzt)
     - Tasks werden gleichmäßig auf alle Staff verteilt (nicht nur eingestempelte)
*/

-- Funktion zur Berechnung der theoretisch erreichbaren Punkte - KORRIGIERT
CREATE OR REPLACE FUNCTION calculate_daily_achievable_points(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points integer := 0;
  v_checkin_points integer := 0;
  v_task_points integer := 0;
  v_has_checked_in boolean := false;
  v_staff_count integer := 0;
BEGIN
  -- Prüfen ob Mitarbeiter heute eingecheckt hat (approved check-in)
  SELECT EXISTS (
    SELECT 1 FROM check_ins
    WHERE user_id = p_user_id
    AND DATE(check_in_time) = p_date
    AND status = 'approved'
  ) INTO v_has_checked_in;

  -- Check-In Punkte nur wenn tatsächlich eingecheckt
  IF v_has_checked_in THEN
    v_checkin_points := 5;
  END IF;

  v_total_points := v_total_points + v_checkin_points;

  -- Anzahl Staff-Mitglieder (für Verteilung der Tasks)
  SELECT COUNT(DISTINCT id) INTO v_staff_count
  FROM profiles
  WHERE role = 'staff';

  -- Wenn keine Staff-Mitglieder, return
  IF v_staff_count = 0 THEN
    RETURN v_total_points;
  END IF;

  -- Punkte aus Tasks: 
  -- - Zugewiesene Tasks: volle Punkte
  -- - Nicht-zugewiesene Tasks: gleichmäßig auf alle Staff verteilt
  SELECT COALESCE(SUM(
    CASE 
      -- Task ist diesem User zugewiesen (hauptsächlich)
      WHEN assigned_to = p_user_id THEN
        CASE 
          WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
            -- Bei 2 Mitarbeitern: halbe Punkte + ggf. halber Deadline-Bonus
            (points_value / 2) + (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END)
          ELSE
            -- Vollständige Punkte + ggf. Deadline-Bonus
            points_value + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
        END
      
      -- Task ist zweitem User zugewiesen
      WHEN secondary_assigned_to = p_user_id THEN
        (points_value / 2) + (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END)
      
      -- Task ist NICHT zugewiesen - gleichmäßig auf alle Staff verteilt
      WHEN assigned_to IS NULL THEN
        (points_value::numeric / v_staff_count) + 
        (CASE WHEN due_date IS NOT NULL THEN (1.0 / v_staff_count) ELSE 0 END)
      
      ELSE 0
    END
  ), 0)::integer
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status NOT IN ('completed', 'cancelled');

  v_total_points := v_total_points + v_task_points;

  RETURN v_total_points;
END;
$$;

-- Aktualisiere approve_task_with_points mit korrigiertem Deadline-Bonus (+1 statt +2)
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

  -- Prüfe ob innerhalb der Deadline erledigt: +1 Punkt
  IF v_task.due_date IS NOT NULL THEN
    v_is_within_deadline := v_task.completed_at <= v_task.due_date;
    IF v_is_within_deadline AND NOT v_task.deadline_bonus_awarded THEN
      v_deadline_bonus := 1;
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
      v_reason := v_reason || ' (✓ Deadline-Bonus +1)';
    END IF;
    
    IF v_reopen_penalty < 0 THEN
      v_reason := v_reason || ' (' || v_reopen_penalty || ' wegen ' || v_task.reopened_count || 'x Reopen)';
    END IF;

    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (v_task.assigned_to, v_total_points, v_reason, 'task_completed', p_admin_id);

    -- Punkteziele updaten
    PERFORM update_daily_point_goals(v_task.assigned_to, CURRENT_DATE);
  END IF;

  -- Punkte vergeben an zweiten Mitarbeiter (halbe Punkte, aufgerundet)
  IF v_task.secondary_assigned_to IS NOT NULL THEN
    v_total_points := GREATEST(CEIL((v_base_points + v_deadline_bonus + v_reopen_penalty)::numeric / 2), 0)::integer;
    v_reason := 'Aufgabe erledigt (Assistent): ' || v_task.title;

    IF v_deadline_bonus > 0 THEN
      v_reason := v_reason || ' (✓ Deadline-Bonus +0.5)';
    END IF;

    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (v_task.secondary_assigned_to, v_total_points, v_reason, 'task_completed', p_admin_id);

    -- Punkteziele updaten
    PERFORM update_daily_point_goals(v_task.secondary_assigned_to, CURRENT_DATE);
  END IF;

  -- Hole zufällige motivierende Nachricht aus Datenbank
  v_feedback_message := get_random_motivational_message('very_good');

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
      v_feedback_message || ' +' || GREATEST(CEIL((v_base_points + v_deadline_bonus + v_reopen_penalty)::numeric / 2), 0) || ' Punkte für: ' || v_task.title,
      'success'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'base_points', v_base_points,
    'deadline_bonus', v_deadline_bonus,
    'reopen_penalty', v_reopen_penalty,
    'total_points', v_total_points,
    'within_deadline', v_is_within_deadline,
    'feedback_message', v_feedback_message
  );
END;
$$;
