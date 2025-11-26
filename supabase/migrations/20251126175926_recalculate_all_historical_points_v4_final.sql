/*
  # Recalculate All Historical Points - V4 FINAL

  ## Purpose:
  Recalculates ALL daily_point_goals based on the new correct points calculation system.
  Uses correct column name: goal_date (not date)
  Handles percentage > 100% correctly

  ## What it does:
  1. Loops through all dates where any user has points_history entries
  2. For each date and user, recalculates:
     - achieved_points (from points_history)
     - theoretically_achievable_points (based on what they could have earned)
  3. Updates daily_point_goals table with correct values
*/

-- ============================================================================
-- First: Expand percentage column to handle values > 100
-- ============================================================================
ALTER TABLE daily_point_goals 
  ALTER COLUMN percentage TYPE numeric(7,2);

-- ============================================================================
-- Function to recalculate all historical daily_point_goals
-- ============================================================================
CREATE OR REPLACE FUNCTION recalculate_all_historical_daily_goals()
RETURNS TABLE(
  dates_processed integer,
  records_updated integer
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_date date;
  v_user_id uuid;
  v_achieved integer;
  v_achievable integer;
  v_percentage numeric(7,2);
  v_dates_count integer := 0;
  v_records_count integer := 0;
  v_date_record RECORD;
  v_user_record RECORD;
BEGIN
  RAISE NOTICE '🔄 Starting recalculation of all historical daily_point_goals...';

  -- Get all unique dates from points_history (last 90 days for performance)
  FOR v_date_record IN
    SELECT DISTINCT DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh') as point_date
    FROM points_history
    WHERE created_at >= (CURRENT_DATE - INTERVAL '90 days')
    ORDER BY point_date ASC
  LOOP
    v_date := v_date_record.point_date;
    v_dates_count := v_dates_count + 1;

    -- Get all users who have points on this date
    FOR v_user_record IN
      SELECT DISTINCT user_id
      FROM points_history
      WHERE DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh') = v_date
    LOOP
      v_user_id := v_user_record.user_id;

      -- Calculate achieved points (from points_history)
      BEGIN
        v_achieved := calculate_achieved_points(v_user_id, v_date);
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Error calculating achieved for user % on %: %', v_user_id, v_date, SQLERRM;
        v_achieved := 0;
      END;

      -- Calculate achievable points (what they could have earned)
      BEGIN
        v_achievable := calculate_theoretically_achievable_points(v_user_id, v_date);
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Error calculating achievable for user % on %: %', v_user_id, v_date, SQLERRM;
        v_achievable := 0;
      END;

      -- Calculate percentage (cap at 999.99 for safety)
      IF v_achievable > 0 THEN
        v_percentage := LEAST((v_achieved::numeric / v_achievable::numeric * 100)::numeric(7,2), 999.99);
      ELSE
        v_percentage := 0;
      END IF;

      -- Upsert into daily_point_goals
      INSERT INTO daily_point_goals (
        user_id,
        goal_date,
        achieved_points,
        theoretically_achievable_points,
        percentage,
        updated_at
      )
      VALUES (
        v_user_id,
        v_date,
        v_achieved,
        v_achievable,
        v_percentage,
        now()
      )
      ON CONFLICT (user_id, goal_date)
      DO UPDATE SET
        achieved_points = EXCLUDED.achieved_points,
        theoretically_achievable_points = EXCLUDED.theoretically_achievable_points,
        percentage = EXCLUDED.percentage,
        updated_at = now();

      v_records_count := v_records_count + 1;
    END LOOP;

    IF v_dates_count % 10 = 0 THEN
      RAISE NOTICE '   Processed % dates, % records so far...', v_dates_count, v_records_count;
    END IF;
  END LOOP;

  RAISE NOTICE '✅ Recalculation complete!';
  RAISE NOTICE '   - Dates processed: %', v_dates_count;
  RAISE NOTICE '   - Records updated: %', v_records_count;

  RETURN QUERY SELECT v_dates_count, v_records_count;
END;
$$;

COMMENT ON FUNCTION recalculate_all_historical_daily_goals IS
'Recalculates ALL historical daily_point_goals based on new correct logic (last 90 days)';

-- ============================================================================
-- Execute the recalculation immediately
-- ============================================================================
DO $$
DECLARE
  v_result RECORD;
BEGIN
  RAISE NOTICE '🚀 Starting historical points recalculation (last 90 days)...';
  
  SELECT * INTO v_result FROM recalculate_all_historical_daily_goals();
  
  RAISE NOTICE '✅ DONE! Processed % dates, updated % records',
    v_result.dates_processed, v_result.records_updated;
END $$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION recalculate_all_historical_daily_goals TO authenticated;
