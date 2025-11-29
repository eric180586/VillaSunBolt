/*
  # Check-In System Integration mit Punktesystem

  ## Änderungen
  1. Check-In Funktion erweitert um:
     - Integration mit daily_point_goals
     - Automatisches Update der erreichbaren Punkte
     - Pünktlichkeits-Punkte als Teil der Tagesberechnung

  2. Approval-Funktionen angepasst um daily_goals zu updaten

  ## Logik
  - Check-In Punkte: +5 für pünktlich (bis 9:00:59 für Früh, bis 15:00:59 für Spät)
  - Bei Verspätung: -1 Punkt pro 5 Minuten
  - Punkte werden erst bei Admin-Approval tatsächlich vergeben
*/

-- Update Check-In Approval Funktion
CREATE OR REPLACE FUNCTION approve_check_in(
  p_check_in_id uuid,
  p_admin_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check_in record;
  v_reason text;
BEGIN
  -- Verify admin role
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = p_admin_id
    AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can approve check-ins';
  END IF;

  -- Get check-in details
  SELECT * INTO v_check_in
  FROM check_ins
  WHERE id = p_check_in_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Check-in not found';
  END IF;
  
  IF v_check_in.status != 'pending' THEN
    RAISE EXCEPTION 'Check-in already processed';
  END IF;
  
  -- Update check-in status
  UPDATE check_ins
  SET 
    status = 'approved',
    approved_by = p_admin_id,
    approved_at = now()
  WHERE id = p_check_in_id;
  
  -- Award points
  IF v_check_in.points_awarded > 0 THEN
    v_reason := 'Pünktliches Einchecken - ' || v_check_in.shift_type || 'schicht (bestätigt)';
    
    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (v_check_in.user_id, v_check_in.points_awarded, v_reason, 'punctuality', p_admin_id);
  ELSIF v_check_in.is_late THEN
    v_reason := 'Verspätetes Einchecken (' || v_check_in.minutes_late || ' Min.) - ' || v_check_in.shift_type || 'schicht';
    
    -- Deduct points for being late
    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (v_check_in.user_id, v_check_in.points_awarded - 5, v_reason, 'penalty', p_admin_id);
  END IF;
  
  -- Update daily point goals
  PERFORM update_daily_point_goals(v_check_in.user_id, DATE(v_check_in.check_in_time));
  
  -- Notify staff member
  INSERT INTO notifications (user_id, title, message, type)
  VALUES (
    v_check_in.user_id,
    'Check-In bestätigt ✓',
    'Dein Check-In wurde bestätigt. Du hast ' || v_check_in.points_awarded || ' Punkte erhalten!',
    'success'
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'points_awarded', v_check_in.points_awarded
  );
END;
$$;

-- Update Check-In Reject Funktion
CREATE OR REPLACE FUNCTION reject_check_in(
  p_check_in_id uuid,
  p_admin_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check_in record;
BEGIN
  -- Verify admin role
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = p_admin_id
    AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can reject check-ins';
  END IF;

  -- Get check-in details
  SELECT * INTO v_check_in
  FROM check_ins
  WHERE id = p_check_in_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Check-in not found';
  END IF;
  
  IF v_check_in.status != 'pending' THEN
    RAISE EXCEPTION 'Check-in already processed';
  END IF;
  
  -- Update check-in status
  UPDATE check_ins
  SET 
    status = 'rejected',
    approved_by = p_admin_id,
    approved_at = now()
  WHERE id = p_check_in_id;
  
  -- Update daily point goals (keine Punkte vergeben)
  PERFORM update_daily_point_goals(v_check_in.user_id, DATE(v_check_in.check_in_time));
  
  -- Notify staff member
  INSERT INTO notifications (user_id, title, message, type)
  VALUES (
    v_check_in.user_id,
    'Check-In abgelehnt',
    'Dein Check-In wurde abgelehnt. Grund: ' || COALESCE(p_reason, 'Keine Angabe'),
    'error'
  );
  
  RETURN jsonb_build_object(
    'success', true
  );
END;
$$;

-- Funktion zum initialen Berechnen aller daily_point_goals für heute
CREATE OR REPLACE FUNCTION initialize_daily_goals_for_today()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update für alle Staff-Mitglieder
  PERFORM update_daily_point_goals(NULL, CURRENT_DATE);
END;
$$;

-- Trigger für Tasks: Update daily_goals wenn Task zugewiesen wird
CREATE OR REPLACE FUNCTION trigger_task_assignment_update_goals()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Update für beide zugewiesenen Mitarbeiter
  IF NEW.assigned_to IS NOT NULL THEN
    PERFORM update_daily_point_goals(NEW.assigned_to, DATE(NEW.due_date));
  END IF;
  
  IF NEW.secondary_assigned_to IS NOT NULL THEN
    PERFORM update_daily_point_goals(NEW.secondary_assigned_to, DATE(NEW.due_date));
  END IF;
  
  -- Wenn jemand entfernt wurde, auch updaten
  IF OLD.assigned_to IS NOT NULL AND (NEW.assigned_to IS NULL OR NEW.assigned_to != OLD.assigned_to) THEN
    PERFORM update_daily_point_goals(OLD.assigned_to, DATE(OLD.due_date));
  END IF;
  
  IF OLD.secondary_assigned_to IS NOT NULL AND (NEW.secondary_assigned_to IS NULL OR NEW.secondary_assigned_to != OLD.secondary_assigned_to) THEN
    PERFORM update_daily_point_goals(OLD.secondary_assigned_to, DATE(OLD.due_date));
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS task_assignment_update_goals ON tasks;

CREATE TRIGGER task_assignment_update_goals
AFTER INSERT OR UPDATE OF assigned_to, secondary_assigned_to, status, due_date
ON tasks
FOR EACH ROW
EXECUTE FUNCTION trigger_task_assignment_update_goals();
