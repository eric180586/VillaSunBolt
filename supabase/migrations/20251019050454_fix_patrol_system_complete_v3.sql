/*
  # Fix Patrol System - Complete Solution
  
  ## Summary
  This migration fixes all identified issues in the patrol rounds system to ensure:
  - Proper push notifications are sent
  - No duplicate scans are allowed
  - Points are correctly awarded (+1 per scan, -1 per missed location)
  - Rounds are automatically created when schedules are assigned
  - Staff can consistently access their patrol overview
  
  ## Changes Made
  
  ### 1. Clean Duplicate Scans and Add UNIQUE Constraint
  - Removes duplicate scans (keeps earliest scan per location per round)
  - Adds UNIQUE constraint to prevent future duplicates
  - Ensures accurate "X of Y" progress tracking
  
  ### 2. Create Penalty Function for Incomplete Patrols
  - Awards -1 point per missed location after grace period (15 minutes)
  - Only penalizes if not already calculated
  - Updates daily_point_goals accordingly
  
  ### 3. Proactive Round Creation Trigger
  - Automatically creates patrol_rounds when patrol_schedules are assigned
  - Sets scheduled_time properly for push notifications
  - Ensures staff always see their rounds immediately
  
  ### 4. Update Cron Job for Penalty Enforcement
  - Extends run_scheduled_notification_checks() to apply penalties
  - Runs every 5 minutes to check for rounds past grace period
  - Marks rounds as calculated to prevent duplicate penalties
  
  ## Point System
  - +1 point immediately when scanning each location
  - -1 point per missed location (applied after 15 min grace period)
  - Example: 2 of 3 scanned = +2 points (scans) -1 point (missed) = +1 total
  
  ## Security
  - All functions use SECURITY DEFINER for system operations
  - RLS policies remain unchanged and secure
*/

-- ============================================================================
-- 1. CLEAN DUPLICATE SCANS AND ADD UNIQUE CONSTRAINT
-- ============================================================================

-- First, delete duplicate scans (keep the earliest scan per location per round)
DELETE FROM patrol_scans
WHERE id IN (
  SELECT id
  FROM (
    SELECT id,
           ROW_NUMBER() OVER (
             PARTITION BY patrol_round_id, location_id 
             ORDER BY scanned_at ASC
           ) as rn
    FROM patrol_scans
  ) t
  WHERE t.rn > 1
);

-- Now add the UNIQUE constraint
DO $$ 
BEGIN
  -- Check if constraint already exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'unique_patrol_scan_per_location'
  ) THEN
    ALTER TABLE patrol_scans 
    ADD CONSTRAINT unique_patrol_scan_per_location 
    UNIQUE (patrol_round_id, location_id);
  END IF;
END $$;

-- ============================================================================
-- 2. CREATE PENALTY FUNCTION FOR INCOMPLETE PATROLS
-- ============================================================================

CREATE OR REPLACE FUNCTION penalize_incomplete_patrol_round(p_round_id uuid)
RETURNS json AS $$
DECLARE
  v_round record;
  v_location_count int;
  v_unique_scan_count int;
  v_missed_count int;
  v_penalty int;
  v_date date;
BEGIN
  -- Get round info
  SELECT * INTO v_round
  FROM patrol_rounds
  WHERE id = p_round_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Round not found');
  END IF;
  
  -- Check if already calculated
  IF v_round.points_calculated THEN
    RETURN json_build_object('success', false, 'message', 'Points already calculated');
  END IF;
  
  -- Count total locations
  SELECT COUNT(*) INTO v_location_count
  FROM patrol_locations;
  
  -- Count UNIQUE scans for this round
  SELECT COUNT(DISTINCT location_id) INTO v_unique_scan_count
  FROM patrol_scans
  WHERE patrol_round_id = p_round_id;
  
  -- Calculate missed locations
  v_missed_count := v_location_count - v_unique_scan_count;
  
  -- Penalty: -1 per missed location
  v_penalty := -1 * v_missed_count;
  
  -- Update round
  UPDATE patrol_rounds
  SET 
    points_awarded = v_penalty,
    points_calculated = true,
    completed_at = CASE WHEN completed_at IS NULL THEN NOW() ELSE completed_at END
  WHERE id = p_round_id;
  
  -- Add penalty to daily goals (only if penalty exists)
  IF v_penalty < 0 THEN
    v_date := v_round.date;
    
    INSERT INTO daily_point_goals (user_id, date, points_earned)
    VALUES (v_round.assigned_to, v_date, v_penalty)
    ON CONFLICT (user_id, date)
    DO UPDATE SET 
      points_earned = daily_point_goals.points_earned + v_penalty,
      updated_at = NOW();
  END IF;
  
  RETURN json_build_object(
    'success', true,
    'penalty', v_penalty,
    'missed_locations', v_missed_count,
    'scanned_locations', v_unique_scan_count,
    'total_locations', v_location_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION penalize_incomplete_patrol_round(uuid) TO authenticated;

-- ============================================================================
-- 3. PROACTIVE ROUND CREATION TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION create_patrol_rounds_for_schedule()
RETURNS trigger AS $$
BEGIN
  -- Create rounds for early shift (11:00 - 14:45)
  IF NEW.shift = 'early' THEN
    INSERT INTO patrol_rounds (date, time_slot, assigned_to, scheduled_time)
    VALUES 
      (NEW.date, '11:00', NEW.assigned_to, (NEW.date::text || ' 11:00:00+07')::timestamptz),
      (NEW.date, '12:15', NEW.assigned_to, (NEW.date::text || ' 12:15:00+07')::timestamptz),
      (NEW.date, '13:30', NEW.assigned_to, (NEW.date::text || ' 13:30:00+07')::timestamptz),
      (NEW.date, '14:45', NEW.assigned_to, (NEW.date::text || ' 14:45:00+07')::timestamptz)
    ON CONFLICT DO NOTHING;
  END IF;
  
  -- Create rounds for late shift (16:00 - 21:00)
  IF NEW.shift = 'late' THEN
    INSERT INTO patrol_rounds (date, time_slot, assigned_to, scheduled_time)
    VALUES 
      (NEW.date, '16:00', NEW.assigned_to, (NEW.date::text || ' 16:00:00+07')::timestamptz),
      (NEW.date, '17:15', NEW.assigned_to, (NEW.date::text || ' 17:15:00+07')::timestamptz),
      (NEW.date, '18:30', NEW.assigned_to, (NEW.date::text || ' 18:30:00+07')::timestamptz),
      (NEW.date, '19:45', NEW.assigned_to, (NEW.date::text || ' 19:45:00+07')::timestamptz),
      (NEW.date, '21:00', NEW.assigned_to, (NEW.date::text || ' 21:00:00+07')::timestamptz)
    ON CONFLICT DO NOTHING;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS create_rounds_on_schedule ON patrol_schedules;

CREATE TRIGGER create_rounds_on_schedule
  AFTER INSERT ON patrol_schedules
  FOR EACH ROW
  EXECUTE FUNCTION create_patrol_rounds_for_schedule();

-- ============================================================================
-- 4. UPDATE CRON JOB FOR PENALTY ENFORCEMENT
-- ============================================================================

CREATE OR REPLACE FUNCTION run_scheduled_notification_checks()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check for overdue patrols (5+ minutes late) - Send notification
  DECLARE
    v_patrol record;
  BEGIN
    FOR v_patrol IN 
      SELECT id, assigned_to, date, time_slot
      FROM patrol_rounds
      WHERE completed_at IS NULL
      AND notification_sent = false
      AND scheduled_time IS NOT NULL
      AND scheduled_time <= now() - interval '5 minutes'
    LOOP
      -- Call notify function
      PERFORM notify_patrol_due(v_patrol.id);
      
      -- Mark as notified
      UPDATE patrol_rounds
      SET notification_sent = true
      WHERE id = v_patrol.id;
    END LOOP;
  END;
  
  -- NEW: Check for rounds past grace period (15+ minutes late) - Apply penalty
  DECLARE
    v_overdue_patrol record;
  BEGIN
    FOR v_overdue_patrol IN 
      SELECT id, assigned_to, date, time_slot
      FROM patrol_rounds
      WHERE completed_at IS NULL
      AND points_calculated = false
      AND scheduled_time IS NOT NULL
      AND scheduled_time <= now() - interval '15 minutes'
    LOOP
      -- Apply penalty for incomplete round
      PERFORM penalize_incomplete_patrol_round(v_overdue_patrol.id);
      
      RAISE NOTICE 'Applied penalty to patrol round % for user %', v_overdue_patrol.id, v_overdue_patrol.assigned_to;
    END LOOP;
  END;
  
  -- Check for tasks approaching deadline
  PERFORM notify_task_deadline_approaching();
  
  RAISE NOTICE 'Scheduled notification checks completed at %', now();
END;
$$;

-- ============================================================================
-- 5. FIX EXISTING ROUNDS - SET scheduled_time FOR EXISTING DATA
-- ============================================================================

-- Update existing patrol_rounds that don't have scheduled_time set
UPDATE patrol_rounds
SET scheduled_time = (date::text || ' ' || time_slot::text || '+07')::timestamptz
WHERE scheduled_time IS NULL
AND date >= CURRENT_DATE - interval '7 days';

-- ============================================================================
-- 6. ADD UNIQUE CONSTRAINT ON patrol_rounds TO PREVENT DUPLICATES
-- ============================================================================

DO $$ 
BEGIN
  -- Check if constraint already exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'unique_patrol_round_assignment'
  ) THEN
    -- First, remove any duplicate rounds (keep the oldest one)
    DELETE FROM patrol_rounds
    WHERE id IN (
      SELECT id
      FROM (
        SELECT id,
               ROW_NUMBER() OVER (
                 PARTITION BY date, time_slot, assigned_to 
                 ORDER BY created_at
               ) as rn
        FROM patrol_rounds
      ) t
      WHERE t.rn > 1
    );
    
    -- Now add the constraint
    ALTER TABLE patrol_rounds
    ADD CONSTRAINT unique_patrol_round_assignment
    UNIQUE (date, time_slot, assigned_to);
  END IF;
END $$;
