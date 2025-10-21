/*
  # Team-Punkte: Admins bekommen keine Task-Punkte

  ## Logik
  - Admins: Nur Check-In Punkte (5)
  - Staff: Check-In + alle verfügbaren Tasks
  
  ## Beispiel (Sopheaktra + Eric heute)
  - Sopheaktra (Staff): 5 + 18 = 23
  - Eric (Admin): 5 + 0 = 5
  - Team Total: 28
  
  Aber das ist immer noch nicht 38...
  Vielleicht: Admins bekommen Task-Punkte, aber weniger?
  Oder: Es fehlt eine andere Punktequelle?
*/

-- Admins bekommen keine Task-Punkte
CREATE OR REPLACE FUNCTION calculate_daily_achievable_points(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points integer := 0;
  v_checkin_points integer := 0;
  v_task_points integer := 0;
  v_has_checked_in boolean := false;
  v_user_role text;
BEGIN
  -- Hole User Role
  SELECT role INTO v_user_role
  FROM profiles
  WHERE id = p_user_id;

  -- Prüfen ob approved check-in vorhanden
  SELECT EXISTS (
    SELECT 1 FROM check_ins
    WHERE user_id = p_user_id
    AND DATE(check_in_time) = p_date
    AND status = 'approved'
  ) INTO v_has_checked_in;

  -- Check-In Punkte
  IF v_has_checked_in THEN
    v_checkin_points := 5;
  END IF;

  v_total_points := v_total_points + v_checkin_points;

  -- Task-Punkte NUR für Staff (nicht für Admins)
  IF v_user_role = 'staff' AND v_has_checked_in THEN
    SELECT COALESCE(SUM(
      CASE
        WHEN assigned_to = p_user_id THEN
          CASE
            WHEN secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
              (points_value / 2) + (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END)
            ELSE
              points_value + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
          END
        WHEN secondary_assigned_to = p_user_id THEN
          (points_value / 2) + (CASE WHEN due_date IS NOT NULL THEN 0.5 ELSE 0 END)
        WHEN assigned_to IS NULL THEN
          points_value + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
        ELSE 0
      END
    ), 0)::integer
    INTO v_task_points
    FROM tasks
    WHERE DATE(due_date) = p_date
    AND status NOT IN ('completed', 'cancelled');

    v_total_points := v_total_points + v_task_points;
  END IF;

  RETURN v_total_points;
END;
$$;

-- Update daily_point_goals
SELECT update_daily_point_goals(NULL, CURRENT_DATE);
