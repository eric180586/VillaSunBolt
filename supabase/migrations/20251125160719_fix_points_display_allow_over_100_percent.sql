/*
  # Allow Over 100% Achievement (Bonuses and Extra Work)

  ## Problem
  - System was capping achieved at achievable
  - Users SHOULD be able to exceed 100% through:
    1. Quality bonuses (+2 points)
    2. Deadline bonuses (+2 points)
    3. Extra patrol scans beyond scheduled
    4. Taking on unassigned tasks
  
  ## Solution
  - Remove the cap
  - Show actual achieved points
  - Percentage can go over 100% (this is GOOD!)
  - Document this as intended behavior
*/

CREATE OR REPLACE FUNCTION update_daily_point_goals_for_user(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_achievable integer;
  v_achieved integer;
  v_percentage numeric;
  v_color text;
  v_team_achievable integer;
  v_team_achieved integer;
BEGIN
  -- Calculate individual points
  v_achievable := calculate_theoretically_achievable_points(p_user_id, p_date);
  v_achieved := calculate_achieved_points(p_user_id, p_date);

  -- Calculate percentage (CAN BE OVER 100% - this is a feature!)
  IF v_achievable > 0 THEN
    v_percentage := (v_achieved::numeric / v_achievable::numeric) * 100;
  ELSE
    v_percentage := 0;
  END IF;

  -- Get color status (uses achieved vs achievable)
  v_color := get_color_status(v_achievable, v_achieved);

  -- Calculate team points
  v_team_achievable := calculate_team_achievable_points(p_date);
  
  -- Team achieved = sum of ALL staff points earned today
  SELECT COALESCE(SUM(points_change), 0)
  INTO v_team_achieved
  FROM points_history
  WHERE DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh') = p_date
    AND user_id IN (SELECT id FROM profiles WHERE role = 'staff');

  -- Upsert into daily_point_goals
  INSERT INTO daily_point_goals (
    user_id,
    goal_date,
    theoretically_achievable_points,
    achieved_points,
    percentage,
    color_status,
    team_achievable_points,
    team_points_earned,
    updated_at
  )
  VALUES (
    p_user_id,
    p_date,
    v_achievable,
    v_achieved,  -- NO CAPPING! Show real earned points
    v_percentage,
    v_color,
    v_team_achievable,
    v_team_achieved,
    now()
  )
  ON CONFLICT (user_id, goal_date)
  DO UPDATE SET
    theoretically_achievable_points = v_achievable,
    achieved_points = v_achieved,  -- NO CAPPING!
    percentage = v_percentage,
    color_status = v_color,
    team_achievable_points = v_team_achievable,
    team_points_earned = v_team_achieved,
    updated_at = now();
END;
$$;

COMMENT ON FUNCTION update_daily_point_goals_for_user IS 
'Updates daily point goals. Achieved CAN exceed achievable through bonuses and extra work!';

-- Add helper function to explain when >100% is achieved
CREATE OR REPLACE FUNCTION get_achievement_explanation(p_user_id uuid, p_date date DEFAULT CURRENT_DATE)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_achievable integer;
  v_achieved integer;
  v_percentage numeric;
  v_explanation text := '';
BEGIN
  v_achievable := calculate_theoretically_achievable_points(p_user_id, p_date);
  v_achieved := calculate_achieved_points(p_user_id, p_date);
  
  IF v_achievable = 0 THEN
    RETURN 'No schedule or check-in today';
  END IF;
  
  v_percentage := (v_achieved::numeric / v_achievable::numeric) * 100;
  
  IF v_percentage >= 110 THEN
    v_explanation := '🌟 Outstanding! Over 110% through quality work and bonuses!';
  ELSIF v_percentage > 100 THEN
    v_explanation := '⭐ Excellent! Over 100% from deadline/quality bonuses or extra work!';
  ELSIF v_percentage >= 90 THEN
    v_explanation := '✅ Great job! 90%+ achieved!';
  ELSIF v_percentage >= 70 THEN
    v_explanation := '👍 Good progress, keep going!';
  ELSIF v_percentage > 0 THEN
    v_explanation := '💪 Keep working to reach your goal!';
  ELSE
    v_explanation := '📝 Start working on your tasks!';
  END IF;
  
  RETURN v_explanation;
END;
$$;

COMMENT ON FUNCTION get_achievement_explanation IS 
'Provides encouraging explanation of achievement level, celebrating >100% performance';
