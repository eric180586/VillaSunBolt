/*
  # Recalculate All Historical Daily Goals After Unassigned Task Fix

  ## What this does:
  Re-runs the achievable calculation for ALL historical daily_point_goals
  using the NEW logic (without unassigned tasks).

  ## Why needed:
  The old logic counted unassigned tasks, which was wrong.
  We need to update all past records to show correct achievable values.
*/

DO $$
DECLARE
  v_record RECORD;
  v_updated_count integer := 0;
BEGIN
  RAISE NOTICE 'Starting recalculation of all historical daily_point_goals...';
  
  -- Update all daily_point_goals with correct achievable
  FOR v_record IN 
    SELECT DISTINCT user_id, goal_date
    FROM daily_point_goals
    ORDER BY goal_date DESC
  LOOP
    PERFORM update_daily_point_goals_for_user(v_record.user_id, v_record.goal_date);
    v_updated_count := v_updated_count + 1;
    
    -- Log progress every 50 records
    IF v_updated_count % 50 = 0 THEN
      RAISE NOTICE 'Updated % records...', v_updated_count;
    END IF;
  END LOOP;
  
  RAISE NOTICE '✅ Recalculation complete! Updated % daily_point_goals records.', v_updated_count;
END $$;
