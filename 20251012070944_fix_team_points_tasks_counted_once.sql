/*
  # Team-Punkte: Tasks nur EINMAL zählen, nicht pro Person

  ## Problem
  - Aktuell: Jeder geplante Mitarbeiter bekommt alle Tasks (4 × 23 = 92)
  - Richtig: Check-Ins pro Person, aber Tasks nur einmal für das Team

  ## Logik
  - Check-In-Punkte: Anzahl geplanter Staff × 5
  - Task-Punkte: Alle Tasks einmalig (nur einmal zählen)
  - TEAM = Check-Ins + Tasks

  ## Beispiel
  - 4 Staff geplant × 5 = 20 Check-In-Punkte
  - 3 Tasks (15) + 3 Deadlines (3) = 18 Task-Punkte
  - TEAM TOTAL: 38 Punkte
*/

CREATE OR REPLACE FUNCTION calculate_team_daily_achievable_points(
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
  v_scheduled_staff_count integer := 0;
BEGIN
  -- Zähle wie viele Staff-Mitarbeiter heute geplant sind
  SELECT COUNT(DISTINCT ws.staff_id)
  INTO v_scheduled_staff_count
  FROM weekly_schedules ws
  JOIN profiles p ON p.id = ws.staff_id
  CROSS JOIN jsonb_array_elements(ws.shifts) as shift
  WHERE p.role = 'staff'
  AND ws.week_start_date = date_trunc('week', p_date)::date
  AND shift->>'day' = LOWER(TRIM(TO_CHAR(p_date, 'Day')))
  AND shift->>'shift' != 'off';

  -- Check-In Punkte: Anzahl geplanter Staff × 5
  v_checkin_points := v_scheduled_staff_count * 5;
  v_total_points := v_total_points + v_checkin_points;

  -- Task-Punkte: Alle Tasks NUR EINMAL zählen (nicht pro Person)
  SELECT COALESCE(SUM(
    points_value + (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END)
  ), 0)
  INTO v_task_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND status NOT IN ('completed', 'cancelled');

  v_total_points := v_total_points + v_task_points;

  RETURN v_total_points;
END;
$$;

-- Update daily_point_goals
SELECT update_daily_point_goals(NULL, CURRENT_DATE);
