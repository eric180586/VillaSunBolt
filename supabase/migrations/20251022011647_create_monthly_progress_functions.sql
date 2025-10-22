/*
  # Create Monthly Progress Functions

  ## New Functions:
  1. calculate_monthly_progress(p_user_id, p_year, p_month)
     - Calculates user's monthly point progress
  
  2. calculate_team_monthly_progress(p_year, p_month)
     - Calculates team's monthly point progress
     
  ## Returns:
  - earned_points: Points earned this month
  - achievable_points: Total achievable points this month
  - progress_percentage: Percentage of goal achieved
*/

-- Calculate individual user monthly progress
CREATE OR REPLACE FUNCTION calculate_monthly_progress(
  p_user_id uuid,
  p_year integer,
  p_month integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_start_date date;
  v_end_date date;
  v_earned_points integer := 0;
  v_achievable_points integer := 0;
  v_progress_percentage numeric := 0;
BEGIN
  -- Calculate month boundaries in Cambodia timezone
  v_start_date := make_date(p_year, p_month, 1);
  v_end_date := (v_start_date + interval '1 month' - interval '1 day')::date;
  
  -- Get earned points from points_history
  SELECT COALESCE(SUM(points_change), 0)
  INTO v_earned_points
  FROM points_history
  WHERE user_id = p_user_id
  AND DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh') >= v_start_date
  AND DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh') <= v_end_date
  AND points_change > 0;  -- Only positive points count as earned
  
  -- Calculate achievable points for the month
  -- This is a simplified version - you can enhance based on tasks/schedules
  SELECT COUNT(DISTINCT DATE(created_at AT TIME ZONE 'Asia/Phnom_Penh')) * 50
  INTO v_achievable_points
  FROM check_ins
  WHERE user_id = p_user_id
  AND DATE(check_in_time AT TIME ZONE 'Asia/Phnom_Penh') >= v_start_date
  AND DATE(check_in_time AT TIME ZONE 'Asia/Phnom_Penh') <= v_end_date;
  
  -- If no check-ins, estimate based on working days
  IF v_achievable_points = 0 THEN
    -- Rough estimate: ~22 working days per month * 50 points
    v_achievable_points := 1100;
  END IF;
  
  -- Calculate progress percentage
  IF v_achievable_points > 0 THEN
    v_progress_percentage := ROUND((v_earned_points::numeric / v_achievable_points::numeric) * 100, 2);
  END IF;
  
  RETURN jsonb_build_object(
    'earned_points', v_earned_points,
    'achievable_points', v_achievable_points,
    'progress_percentage', v_progress_percentage,
    'month', p_month,
    'year', p_year
  );
END;
$$;

-- Calculate team monthly progress
CREATE OR REPLACE FUNCTION calculate_team_monthly_progress(
  p_year integer,
  p_month integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_start_date date;
  v_end_date date;
  v_earned_points integer := 0;
  v_achievable_points integer := 0;
  v_progress_percentage numeric := 0;
  v_active_staff_count integer := 0;
BEGIN
  -- Calculate month boundaries
  v_start_date := make_date(p_year, p_month, 1);
  v_end_date := (v_start_date + interval '1 month' - interval '1 day')::date;
  
  -- Count active staff (who checked in at least once this month)
  SELECT COUNT(DISTINCT user_id)
  INTO v_active_staff_count
  FROM check_ins
  WHERE DATE(check_in_time AT TIME ZONE 'Asia/Phnom_Penh') >= v_start_date
  AND DATE(check_in_time AT TIME ZONE 'Asia/Phnom_Penh') <= v_end_date;
  
  -- Get total earned points from all staff
  SELECT COALESCE(SUM(points_change), 0)
  INTO v_earned_points
  FROM points_history ph
  JOIN profiles p ON ph.user_id = p.id
  WHERE p.role = 'staff'
  AND DATE(ph.created_at AT TIME ZONE 'Asia/Phnom_Penh') >= v_start_date
  AND DATE(ph.created_at AT TIME ZONE 'Asia/Phnom_Penh') <= v_end_date
  AND ph.points_change > 0;
  
  -- Estimate achievable points: active staff * working days * average points per day
  IF v_active_staff_count > 0 THEN
    v_achievable_points := v_active_staff_count * 22 * 50;  -- 22 days * 50 points average
  ELSE
    -- If no data, use a default estimate based on all staff
    SELECT COUNT(*) INTO v_active_staff_count
    FROM profiles
    WHERE role = 'staff';
    
    v_achievable_points := v_active_staff_count * 22 * 50;
  END IF;
  
  -- Calculate progress percentage
  IF v_achievable_points > 0 THEN
    v_progress_percentage := ROUND((v_earned_points::numeric / v_achievable_points::numeric) * 100, 2);
  END IF;
  
  RETURN jsonb_build_object(
    'earned_points', v_earned_points,
    'achievable_points', v_achievable_points,
    'progress_percentage', v_progress_percentage,
    'active_staff_count', v_active_staff_count,
    'month', p_month,
    'year', p_year
  );
END;
$$;

COMMENT ON FUNCTION calculate_monthly_progress IS 
'Calculates individual user monthly point progress';

COMMENT ON FUNCTION calculate_team_monthly_progress IS 
'Calculates team-wide monthly point progress';
