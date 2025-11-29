/*
  # Patrol Rounds Automatic Penalties (Corrected)

  1. Table Structure
    - patrol_rounds: assigned patrols (no status column)
    - patrol_scans: actual scans performed
    - Completion = patrol_rounds.completed_at is set
  
  2. Points Logic
    - When scan is recorded in patrol_scans: +1 point immediately
    - When patrol is missed (past scheduled_time + grace): -1 point automatically
  
  3. Scheduled Job
    - Checks every 15 minutes for missed patrols
    - Applies -1 penalty automatically
*/

-- Function to award point when patrol scan is performed
CREATE OR REPLACE FUNCTION award_patrol_scan_point()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id uuid;
  v_location_name text;
  v_patrol_date date;
BEGIN
  -- When a new scan is inserted
  v_user_id := NEW.user_id;

  -- Get location name
  SELECT name INTO v_location_name
  FROM patrol_locations
  WHERE id = NEW.location_id;

  -- Get patrol date from patrol_round
  SELECT date INTO v_patrol_date
  FROM patrol_rounds
  WHERE id = NEW.patrol_round_id;

  -- Award +1 point for completing patrol scan
  IF v_user_id IS NOT NULL THEN
    INSERT INTO points_history (
      user_id,
      points_change,
      reason,
      category,
      created_by
    ) VALUES (
      v_user_id,
      1,
      'Patrol scan completed: ' || COALESCE(v_location_name, 'Location'),
      'patrol_completed',
      v_user_id
    );

    -- Update daily point goals
    PERFORM update_daily_point_goals_for_user(v_user_id, v_patrol_date);
  END IF;

  -- Mark patrol_round as completed
  UPDATE patrol_rounds
  SET completed_at = NEW.scanned_at
  WHERE id = NEW.patrol_round_id
    AND completed_at IS NULL;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for patrol scan points
DROP TRIGGER IF EXISTS trigger_patrol_scan_point ON patrol_scans;
CREATE TRIGGER trigger_patrol_scan_point
  AFTER INSERT ON patrol_scans
  FOR EACH ROW
  EXECUTE FUNCTION award_patrol_scan_point();

-- Function to check for missed patrol rounds and apply penalties
CREATE OR REPLACE FUNCTION check_missed_patrol_rounds()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_patrol_record RECORD;
  v_current_time timestamptz;
  v_grace_period interval := interval '15 minutes';
  v_location_names text;
BEGIN
  v_current_time := now() AT TIME ZONE 'Asia/Phnom_Penh';

  -- Find all patrol rounds that are overdue and not completed
  FOR v_patrol_record IN
    SELECT 
      pr.id,
      pr.assigned_to,
      pr.scheduled_time,
      pr.date,
      ps.id as schedule_id
    FROM patrol_rounds pr
    JOIN patrol_schedules ps ON ps.id = pr.id
    WHERE pr.completed_at IS NULL
      AND (pr.scheduled_time + v_grace_period) < v_current_time
      AND pr.date <= CURRENT_DATE
  LOOP
    
    -- Get location names for this patrol round
    SELECT string_agg(pl.name, ', ') INTO v_location_names
    FROM patrol_locations pl
    WHERE pl.id IN (
      SELECT unnest(location_ids) 
      FROM patrol_schedules 
      WHERE id = v_patrol_record.schedule_id
    );

    -- Apply -1 penalty
    IF v_patrol_record.assigned_to IS NOT NULL THEN
      INSERT INTO points_history (
        user_id,
        points_change,
        reason,
        category,
        created_by
      ) VALUES (
        v_patrol_record.assigned_to,
        -1,
        'Missed patrol round: ' || COALESCE(v_location_names, 'Patrol locations'),
        'patrol_missed',
        v_patrol_record.assigned_to
      );

      -- Update daily point goals
      PERFORM update_daily_point_goals_for_user(
        v_patrol_record.assigned_to,
        v_patrol_record.date
      );

      -- Send notification
      INSERT INTO notifications (
        user_id,
        type,
        message,
        priority
      ) VALUES (
        v_patrol_record.assigned_to,
        'patrol_missed',
        'You missed patrol round at ' || COALESCE(v_location_names, 'patrol locations') || '. -1 point penalty applied.',
        'high'
      );
    END IF;

    -- Mark as completed with note (so we don't penalize again)
    UPDATE patrol_rounds
    SET completed_at = v_current_time
    WHERE id = v_patrol_record.id;

  END LOOP;
END;
$$;

-- Update achievable points when patrol rounds are created/assigned
CREATE OR REPLACE FUNCTION update_points_after_patrol_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Update achievable points for the assigned user
  IF NEW.assigned_to IS NOT NULL THEN
    PERFORM update_daily_point_goals_for_user(
      NEW.assigned_to,
      NEW.date
    );
  END IF;

  -- Also update if assignment changes
  IF TG_OP = 'UPDATE' AND OLD.assigned_to IS DISTINCT FROM NEW.assigned_to THEN
    IF OLD.assigned_to IS NOT NULL THEN
      PERFORM update_daily_point_goals_for_user(OLD.assigned_to, OLD.date);
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update achievable points when patrol assignment changes
DROP TRIGGER IF EXISTS trigger_update_achievable_on_patrol_change ON patrol_rounds;
CREATE TRIGGER trigger_update_achievable_on_patrol_change
  AFTER INSERT OR UPDATE OF assigned_to ON patrol_rounds
  FOR EACH ROW
  EXECUTE FUNCTION update_points_after_patrol_change();