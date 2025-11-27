/*
  # Recalculate All Historical Achieved Points With Penalties

  This migration recalculates ALL historical daily_point_goals to include
  negative penalties in the achieved points calculation.

  Before: achieved points were capped at 0 (no negatives shown)
  After: achieved points include all penalties (can be negative)
*/

DO $$
DECLARE
  v_record RECORD;
  v_updated_count integer := 0;
  v_old_achieved integer;
  v_new_achieved integer;
  v_changes_count integer := 0;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Starting recalculation of all historical achieved points...';
  RAISE NOTICE '========================================';
  
  -- Loop through ALL daily_point_goals
  FOR v_record IN 
    SELECT user_id, goal_date, achieved_points
    FROM daily_point_goals
    ORDER BY goal_date ASC, user_id
  LOOP
    -- Store old value
    v_old_achieved := v_record.achieved_points;
    
    -- Recalculate using the updated function
    PERFORM update_daily_point_goals_for_user(v_record.user_id, v_record.goal_date);
    
    -- Get new value
    SELECT achieved_points INTO v_new_achieved
    FROM daily_point_goals
    WHERE user_id = v_record.user_id 
      AND goal_date = v_record.goal_date;
    
    v_updated_count := v_updated_count + 1;
    
    -- Track changes
    IF v_old_achieved != v_new_achieved THEN
      v_changes_count := v_changes_count + 1;
      
      -- Log significant changes
      IF v_old_achieved = 0 AND v_new_achieved < 0 THEN
        RAISE NOTICE 'Date: %, User: %, Old: 0 → New: % (penalty now shown)', 
          v_record.goal_date, 
          (SELECT full_name FROM profiles WHERE id = v_record.user_id),
          v_new_achieved;
      END IF;
    END IF;
    
    -- Progress update every 10 records
    IF v_updated_count % 10 = 0 THEN
      RAISE NOTICE 'Progress: % records processed, % changes detected...', 
        v_updated_count, v_changes_count;
    END IF;
  END LOOP;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Recalculation complete!';
  RAISE NOTICE 'Total records processed: %', v_updated_count;
  RAISE NOTICE 'Records with changes: %', v_changes_count;
  RAISE NOTICE '========================================';
END $$;
