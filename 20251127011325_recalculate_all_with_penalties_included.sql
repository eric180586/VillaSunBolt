/*
  # Recalculate All Daily Goals With Penalties Included

  Updates all daily_point_goals to properly reflect negative penalties.
*/

DO $$
DECLARE
  v_record RECORD;
  v_updated_count integer := 0;
BEGIN
  RAISE NOTICE 'Recalculating all daily_point_goals with penalties...';
  
  FOR v_record IN 
    SELECT DISTINCT user_id, goal_date
    FROM daily_point_goals
    ORDER BY goal_date DESC
  LOOP
    PERFORM update_daily_point_goals_for_user(v_record.user_id, v_record.goal_date);
    v_updated_count := v_updated_count + 1;
    
    IF v_updated_count % 50 = 0 THEN
      RAISE NOTICE 'Updated % records...', v_updated_count;
    END IF;
  END LOOP;
  
  RAISE NOTICE '✅ Recalculation complete! Updated % records.', v_updated_count;
END $$;
