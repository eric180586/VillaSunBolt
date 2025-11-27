/*
  # Recalculate All Daily Goals With Fixed Achievable

  After fixing achievable to never be negative, recalculate all records.
*/

DO $$
DECLARE
  v_record RECORD;
  v_updated_count integer := 0;
  v_old_achievable integer;
  v_new_achievable integer;
  v_fixed_count integer := 0;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Recalculating with fixed achievable (never negative)...';
  RAISE NOTICE '========================================';
  
  FOR v_record IN 
    SELECT user_id, goal_date, theoretically_achievable_points
    FROM daily_point_goals
    ORDER BY goal_date ASC, user_id
  LOOP
    v_old_achievable := v_record.theoretically_achievable_points;
    
    -- Recalculate
    PERFORM update_daily_point_goals_for_user(v_record.user_id, v_record.goal_date);
    
    -- Get new value
    SELECT theoretically_achievable_points INTO v_new_achievable
    FROM daily_point_goals
    WHERE user_id = v_record.user_id 
      AND goal_date = v_record.goal_date;
    
    v_updated_count := v_updated_count + 1;
    
    -- Track fixes (where old was negative)
    IF v_old_achievable < 0 AND v_new_achievable = 0 THEN
      v_fixed_count := v_fixed_count + 1;
      
      RAISE NOTICE 'FIXED: Date: %, User: %, Old achievable: % → New: 0',
        v_record.goal_date,
        (SELECT full_name FROM profiles WHERE id = v_record.user_id),
        v_old_achievable;
    END IF;
  END LOOP;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Recalculation complete!';
  RAISE NOTICE 'Records updated: %', v_updated_count;
  RAISE NOTICE 'Negative achievable fixed: %', v_fixed_count;
  RAISE NOTICE '========================================';
END $$;
