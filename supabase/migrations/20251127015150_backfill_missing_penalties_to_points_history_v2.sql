/*
  # Backfill Missing Penalties to Points History

  ## THE PROBLEM:
  Many penalties were recorded in check_ins.points_awarded and patrol_rounds,
  but were NEVER added to points_history!

  This means:
  - 4 late check-ins: -427 points missing
  - 24 missed patrol rounds: -24 points missing
  - TOTAL: -451 points never recorded!

  ## THE FIX:
  Backfill all missing penalties into points_history with correct timestamps
  and categories.
*/

-- ============================================================================
-- 1. Backfill Late Check-in Penalties
-- ============================================================================

DO $$
DECLARE
  v_checkin RECORD;
  v_inserted_count integer := 0;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Backfilling late check-in penalties...';
  RAISE NOTICE '========================================';
  
  FOR v_checkin IN
    SELECT 
      ci.id,
      ci.user_id,
      ci.check_in_date,
      ci.check_in_time,
      ci.points_awarded,
      ci.minutes_late,
      p.full_name
    FROM check_ins ci
    JOIN profiles p ON p.id = ci.user_id
    WHERE ci.is_late = true
      AND ci.status = 'approved'
      AND ci.points_awarded < 0
      AND NOT EXISTS (
        SELECT 1 FROM points_history ph
        WHERE ph.user_id = ci.user_id
          AND DATE(ph.created_at AT TIME ZONE 'Asia/Phnom_Penh') = ci.check_in_date
          AND ph.category = 'check_in'
          AND ph.points_change < 0
      )
    ORDER BY ci.check_in_date ASC
  LOOP
    -- Insert penalty into points_history
    INSERT INTO points_history (
      user_id,
      points_change,
      category,
      reason,
      created_at
    ) VALUES (
      v_checkin.user_id,
      v_checkin.points_awarded,
      'check_in',
      'Late check-in penalty (backfilled): ' || v_checkin.minutes_late || ' minutes late',
      v_checkin.check_in_time  -- Use original check-in time
    );
    
    v_inserted_count := v_inserted_count + 1;
    
    RAISE NOTICE 'Backfilled: % - Date: % - Penalty: % points (% min late)',
      v_checkin.full_name,
      v_checkin.check_in_date,
      v_checkin.points_awarded,
      v_checkin.minutes_late;
  END LOOP;
  
  RAISE NOTICE '✅ Backfilled % late check-in penalties', v_inserted_count;
END $$;

-- ============================================================================
-- 2. Backfill Missed Patrol Round Penalties
-- ============================================================================

DO $$
DECLARE
  v_patrol RECORD;
  v_inserted_count integer := 0;
  v_num_locations integer;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Backfilling missed patrol round penalties...';
  RAISE NOTICE '========================================';
  
  -- Get number of patrol locations (each missed scan = -1 point)
  SELECT COUNT(*) INTO v_num_locations FROM patrol_locations;
  
  FOR v_patrol IN
    SELECT 
      pr.id,
      pr.assigned_to,
      pr.scheduled_time,
      DATE(pr.scheduled_time AT TIME ZONE 'Asia/Phnom_Penh') as scheduled_date,
      p.full_name
    FROM patrol_rounds pr
    JOIN profiles p ON p.id = pr.assigned_to
    WHERE pr.completed_at IS NULL
      AND pr.scheduled_time < NOW() - INTERVAL '1 hour'
      AND pr.points_calculated = false
      AND DATE(pr.scheduled_time AT TIME ZONE 'Asia/Phnom_Penh') >= '2025-11-20'
    ORDER BY pr.scheduled_time ASC
  LOOP
    -- Insert penalty into points_history (one penalty per location)
    INSERT INTO points_history (
      user_id,
      points_change,
      category,
      reason,
      created_at
    ) VALUES (
      v_patrol.assigned_to,
      -v_num_locations,  -- Penalty = number of locations not scanned
      'patrol_missed',
      'Missed patrol round (backfilled): ' || to_char(v_patrol.scheduled_time AT TIME ZONE 'Asia/Phnom_Penh', 'HH24:MI'),
      v_patrol.scheduled_time + INTERVAL '1 hour 30 minutes'  -- Penalty after deadline
    );
    
    -- Mark as calculated
    UPDATE patrol_rounds
    SET points_calculated = true,
        points_awarded = -v_num_locations
    WHERE id = v_patrol.id;
    
    v_inserted_count := v_inserted_count + 1;
    
    RAISE NOTICE 'Backfilled: % - Date: % - Time: % - Penalty: % points',
      v_patrol.full_name,
      v_patrol.scheduled_date,
      to_char(v_patrol.scheduled_time AT TIME ZONE 'Asia/Phnom_Penh', 'HH24:MI'),
      -v_num_locations;
  END LOOP;
  
  RAISE NOTICE '✅ Backfilled % missed patrol round penalties', v_inserted_count;
END $$;

-- ============================================================================
-- 3. Summary
-- ============================================================================

DO $$
DECLARE
  v_total_penalties integer;
  v_total_points integer;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'BACKFILL SUMMARY';
  RAISE NOTICE '========================================';
  
  SELECT COUNT(*), COALESCE(SUM(points_change), 0)
  INTO v_total_penalties, v_total_points
  FROM points_history
  WHERE reason LIKE '%(backfilled)%';
  
  RAISE NOTICE 'Total penalties backfilled: %', v_total_penalties;
  RAISE NOTICE 'Total penalty points: %', v_total_points;
  RAISE NOTICE '========================================';
END $$;
