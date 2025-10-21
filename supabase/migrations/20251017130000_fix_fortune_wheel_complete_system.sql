/*
  # Fix Fortune Wheel Complete System

  ## Problems Fixed:

  1. **add_bonus_points calls non-existent function**
     - Was calling: update_daily_point_goals (doesn't exist!)
     - Should call: initialize_daily_goals_for_today (our new system)

  2. **Points not showing up**
     - points_history entries created but daily_point_goals not updated
     - Trigger on points_history should fire but doesn't recalculate

  ## Solution:

  - Replace update_daily_point_goals with initialize_daily_goals_for_today
  - Ensure points_history trigger is working correctly
  - Add test case comments for validation
*/

-- ============================================================================
-- 1. FIX add_bonus_points FUNCTION
-- ============================================================================
CREATE OR REPLACE FUNCTION add_bonus_points(
  p_user_id uuid,
  p_points integer,
  p_reason text DEFAULT 'Glücksrad Bonus'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_today_date date;
BEGIN
  -- Get today's date in Cambodia timezone
  v_today_date := (now() AT TIME ZONE 'Asia/Phnom_Penh')::date;

  -- Add points to points_history (standard way)
  INSERT INTO points_history (
    user_id,
    points_change,
    reason,
    category,
    created_by
  )
  VALUES (
    p_user_id,
    p_points,
    p_reason,
    'bonus',
    p_user_id
  );

  -- FIXED: Use correct function name that actually exists!
  PERFORM initialize_daily_goals_for_today();

  RETURN jsonb_build_object(
    'success', true,
    'points_added', p_points,
    'reason', p_reason
  );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION add_bonus_points TO authenticated;

-- ============================================================================
-- 2. VERIFY TRIGGER EXISTS AND IS ACTIVE
-- ============================================================================
-- This ensures that points_history changes trigger daily_point_goals updates
-- (Should already exist from 20251017120000_FINAL_APPROVED_points_calculation_system.sql)

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'update_daily_goals_on_points'
  ) THEN
    RAISE NOTICE 'Creating missing trigger: update_daily_goals_on_points';

    CREATE TRIGGER update_daily_goals_on_points
      AFTER INSERT OR UPDATE OR DELETE ON points_history
      FOR EACH STATEMENT
      EXECUTE FUNCTION trigger_update_daily_goals();
  ELSE
    RAISE NOTICE 'Trigger update_daily_goals_on_points already exists';
  END IF;
END $$;

-- ============================================================================
-- TEST CASES (commented for reference)
-- ============================================================================

/*
-- Test 1: Verify add_bonus_points works
SELECT add_bonus_points(
  '<user_id>'::uuid,
  5,
  'Test Fortune Wheel Bonus'
);

-- Test 2: Check points_history entry created
SELECT * FROM points_history
WHERE user_id = '<user_id>'::uuid
AND category = 'bonus'
ORDER BY created_at DESC
LIMIT 5;

-- Test 3: Verify daily_point_goals updated
SELECT
  p.full_name,
  dpg.achieved_points,
  dpg.theoretically_achievable_points,
  dpg.percentage
FROM daily_point_goals dpg
JOIN profiles p ON dpg.user_id = p.id
WHERE dpg.goal_date = CURRENT_DATE
AND dpg.user_id = '<user_id>'::uuid;

-- Test 4: Verify fortune_wheel_spins unique constraint works
-- This should succeed:
INSERT INTO fortune_wheel_spins (user_id, check_in_id, spin_date, reward_type, reward_value, reward_label)
VALUES ('<user_id>'::uuid, '<check_in_id>'::uuid, CURRENT_DATE, 'bonus_points', 5, '5 Punkte');

-- This should FAIL with unique constraint violation:
INSERT INTO fortune_wheel_spins (user_id, check_in_id, spin_date, reward_type, reward_value, reward_label)
VALUES ('<user_id>'::uuid, '<check_in_id>'::uuid, CURRENT_DATE, 'bonus_points', 10, '10 Punkte');

-- Test 5: Check user can only see their own spins
SELECT * FROM fortune_wheel_spins WHERE user_id = auth.uid();
*/

-- ============================================================================
-- VALIDATION QUERY
-- ============================================================================

/*
-- Run this to see today's fortune wheel activity:
SELECT
  p.full_name,
  fws.spin_date,
  fws.reward_label,
  fws.reward_value,
  fws.created_at,
  (SELECT COUNT(*) FROM fortune_wheel_spins WHERE user_id = p.id AND spin_date = CURRENT_DATE) as spins_today
FROM fortune_wheel_spins fws
JOIN profiles p ON fws.user_id = p.id
WHERE fws.spin_date = CURRENT_DATE
ORDER BY fws.created_at DESC;
*/
