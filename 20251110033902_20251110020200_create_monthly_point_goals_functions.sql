/*
  # Create Monthly Point Goals Functions

  1. Functions
    - update_monthly_point_goals_for_user(): Calculate monthly totals for one user
    - update_all_monthly_point_goals(): Update all users' monthly goals
  
  2. Logic
    - Sum all daily_point_goals for the current month
    - Calculate percentage and color status
    - Upsert into monthly_point_goals table
  
  3. Security
    - Functions are SECURITY DEFINER
    - Called by scheduled jobs or triggers
*/

-- Function to update monthly point goals for a specific user
CREATE OR REPLACE FUNCTION update_monthly_point_goals_for_user(
  p_user_id uuid,
  p_month text DEFAULT TO_CHAR(CURRENT_DATE, 'YYYY-MM')
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_achievable integer := 0;
  v_total_achieved integer := 0;
  v_percentage numeric := 0;
  v_color text;
BEGIN
  -- Sum all daily goals for this month
  SELECT 
    COALESCE(SUM(theoretically_achievable_points), 0),
    COALESCE(SUM(achieved_points), 0)
  INTO v_total_achievable, v_total_achieved
  FROM daily_point_goals
  WHERE user_id = p_user_id
    AND TO_CHAR(goal_date, 'YYYY-MM') = p_month;

  -- Calculate percentage
  IF v_total_achievable > 0 THEN
    v_percentage := (v_total_achieved::numeric / v_total_achievable::numeric) * 100;
  ELSE
    v_percentage := 0;
  END IF;

  -- Get color status
  v_color := get_color_status(v_total_achievable, v_total_achieved);

  -- Upsert into monthly_point_goals
  INSERT INTO monthly_point_goals (
    user_id,
    month,
    total_achievable_points,
    total_achieved_points,
    percentage,
    color_status
  )
  VALUES (
    p_user_id,
    p_month,
    v_total_achievable,
    v_total_achieved,
    v_percentage,
    v_color
  )
  ON CONFLICT (user_id, month)
  DO UPDATE SET
    total_achievable_points = v_total_achievable,
    total_achieved_points = v_total_achieved,
    percentage = v_percentage,
    color_status = v_color,
    updated_at = now();
END;
$$;

-- Function to update all users' monthly point goals
CREATE OR REPLACE FUNCTION update_all_monthly_point_goals(
  p_month text DEFAULT TO_CHAR(CURRENT_DATE, 'YYYY-MM')
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_record RECORD;
BEGIN
  FOR v_user_record IN 
    SELECT id FROM profiles WHERE role = 'staff'
  LOOP
    PERFORM update_monthly_point_goals_for_user(v_user_record.id, p_month);
  END LOOP;
END;
$$;

-- Trigger to update monthly goals when daily goals change
CREATE OR REPLACE FUNCTION trigger_update_monthly_on_daily_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Update monthly goals for affected user
  PERFORM update_monthly_point_goals_for_user(
    NEW.user_id,
    TO_CHAR(NEW.goal_date, 'YYYY-MM')
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on daily_point_goals
DROP TRIGGER IF EXISTS trigger_daily_to_monthly_update ON daily_point_goals;
CREATE TRIGGER trigger_daily_to_monthly_update
  AFTER INSERT OR UPDATE ON daily_point_goals
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_monthly_on_daily_change();