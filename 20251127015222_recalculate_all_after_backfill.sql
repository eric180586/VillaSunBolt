/*
  # Recalculate All Daily Goals After Backfilling Penalties

  After backfilling -499 points in penalties, we need to recalculate
  all daily_point_goals to reflect the new achieved values.
*/

DO $$
DECLARE
  v_record RECORD;
  v_updated_count integer := 0;
  v_old_achieved integer;
  v_new_achieved integer;
  v_significant_changes integer := 0;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Recalculating all daily_point_goals after backfill...';
  RAISE NOTICE '========================================';
  
  FOR v_record IN 
    SELECT user_id, goal_date, achieved_points
    FROM daily_point_goals
    WHERE goal_date >= '2025-11-20'  -- Only dates with backfilled penalties
    ORDER BY goal_date ASC, user_id
  LOOP
    v_old_achieved := v_record.achieved_points;
    
    -- Recalculate
    PERFORM update_daily_point_goals_for_user(v_record.user_id, v_record.goal_date);
    
    -- Get new value
    SELECT achieved_points INTO v_new_achieved
    FROM daily_point_goals
    WHERE user_id = v_record.user_id 
      AND goal_date = v_record.goal_date;
    
    v_updated_count := v_updated_count + 1;
    
    -- Track significant changes (more than 50 points difference)
    IF ABS(v_old_achieved - v_new_achieved) > 50 THEN
      v_significant_changes := v_significant_changes + 1;
      
      RAISE NOTICE 'SIGNIFICANT CHANGE - Date: %, User: %, Old: % → New: % (Δ: %)',
        v_record.goal_date,
        (SELECT full_name FROM profiles WHERE id = v_record.user_id),
        v_old_achieved,
        v_new_achieved,
        v_new_achieved - v_old_achieved;
    END IF;
  END LOOP;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Recalculation complete!';
  RAISE NOTICE 'Records updated: %', v_updated_count;
  RAISE NOTICE 'Significant changes (>50 points): %', v_significant_changes;
  RAISE NOTICE '========================================';
END $$;
