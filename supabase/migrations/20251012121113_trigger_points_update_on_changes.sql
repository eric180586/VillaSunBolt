/*
  # Trigger für automatische Punkteziel-Updates
  
  ## Änderungen:
  - Trigger bei points_history Insert/Update/Delete
  - Trigger bei tasks Status-Änderung
  - Trigger bei check_ins Approval
  
  ## Sicherstellung:
  - Punkteziele werden IMMER aktualisiert bei relevanten Änderungen
  - Keine manuellen Refresh-Aufrufe mehr nötig
*/

-- Trigger für points_history Änderungen
CREATE OR REPLACE FUNCTION trigger_update_daily_goals_on_points()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM update_daily_point_goals(OLD.user_id, DATE(OLD.created_at));
    RETURN OLD;
  ELSE
    PERFORM update_daily_point_goals(NEW.user_id, DATE(NEW.created_at));
    RETURN NEW;
  END IF;
END;
$$;

DROP TRIGGER IF EXISTS points_history_update_goals ON points_history;

CREATE TRIGGER points_history_update_goals
AFTER INSERT OR UPDATE OR DELETE ON points_history
FOR EACH ROW
EXECUTE FUNCTION trigger_update_daily_goals_on_points();

-- Trigger für Task Status-Änderungen
CREATE OR REPLACE FUNCTION trigger_update_goals_on_task_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Update für alle betroffenen User bei Task-Änderungen
  IF NEW.assigned_to IS NOT NULL AND NEW.due_date IS NOT NULL THEN
    PERFORM update_daily_point_goals(NEW.assigned_to, DATE(NEW.due_date));
  END IF;
  
  IF NEW.secondary_assigned_to IS NOT NULL AND NEW.due_date IS NOT NULL THEN
    PERFORM update_daily_point_goals(NEW.secondary_assigned_to, DATE(NEW.due_date));
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tasks_update_goals ON tasks;

CREATE TRIGGER tasks_update_goals
AFTER INSERT OR UPDATE ON tasks
FOR EACH ROW
WHEN (NEW.due_date IS NOT NULL)
EXECUTE FUNCTION trigger_update_goals_on_task_change();

-- Trigger für Check-in Approval
CREATE OR REPLACE FUNCTION trigger_update_goals_on_checkin()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status = 'approved' THEN
    PERFORM update_daily_point_goals(NEW.user_id, DATE(NEW.check_in_time));
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS checkins_update_goals ON check_ins;

CREATE TRIGGER checkins_update_goals
AFTER INSERT OR UPDATE ON check_ins
FOR EACH ROW
WHEN (NEW.status = 'approved')
EXECUTE FUNCTION trigger_update_goals_on_checkin();

-- Initialisiere alle Punkteziele für heute neu
SELECT initialize_daily_goals_for_today();
