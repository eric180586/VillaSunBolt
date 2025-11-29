/*
  # FINALE KORREKTUR: Team Erreichbare Punkte
  
  ## Wichtiger Unterschied:
  
  ### INDIVIDUELL:
  - Unassigned Tasks: VOLLE Punkte für jeden (jeder könnte sie machen)
  - Check-in: 5 Punkte für jeden (jeder könnte einchecken)
  
  ### TEAM:
  - Unassigned Tasks: NUR EINMAL gezählt (Task kann nur 1× erledigt werden!)
  - Check-in: Anzahl × 5 (alle können tatsächlich einchecken)
  
  ## Beispiel:
  3 Staff im Schedule, Room Cleaning (5+1 Deadline) unassigned:
  - Individuell: Jeder hat 6 Punkte erreichbar
  - Team: Nur 6 Punkte erreichbar (nicht 18!)
*/

-- ==========================================
-- TEAM: ERREICHBARE PUNKTE (FINALE VERSION)
-- ==========================================
CREATE OR REPLACE FUNCTION calculate_team_daily_achievable_points(
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points numeric := 0;
  v_scheduled_staff_count integer := 0;
  v_checkin_base integer := 0;
  v_assigned_tasks_points numeric := 0;
  v_unassigned_tasks_points numeric := 0;
BEGIN
  -- Anzahl geplanter Staff für heute (shift != 'off')
  SELECT COUNT(DISTINCT ws.staff_id)
  INTO v_scheduled_staff_count
  FROM weekly_schedules ws,
  jsonb_array_elements(ws.shifts) AS shift
  JOIN profiles p ON ws.staff_id = p.id
  WHERE ws.is_published = true
  AND (shift->>'date')::date = p_date
  AND shift->>'shift' != 'off'
  AND p.role = 'staff';

  -- Check-in: Jeder kann einchecken → Anzahl × 5
  v_checkin_base := 5 * v_scheduled_staff_count;

  -- Assigned Tasks: Jede Task nur 1× (auch bei shared tasks)
  SELECT COALESCE(SUM(
    CASE
      -- Tasks mit beiden Assignments: Volle Punkte (wird zwischen beiden geteilt)
      WHEN assigned_to IS NOT NULL AND secondary_assigned_to IS NOT NULL AND secondary_assigned_to != assigned_to THEN
        (COALESCE(initial_points_value, points_value)::numeric + 
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
      -- Tasks mit nur Primary: Volle Punkte
      WHEN assigned_to IS NOT NULL THEN
        (COALESCE(initial_points_value, points_value)::numeric + 
         (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
      ELSE 0
    END
  ), 0)
  INTO v_assigned_tasks_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND assigned_to IS NOT NULL
  AND status NOT IN ('cancelled', 'archived');

  -- Unassigned Tasks: Jede Task nur 1× (NICHT × Anzahl Staff!)
  -- Die Task kann ja nur einmal erledigt werden, egal wer sie macht
  SELECT COALESCE(SUM(
    (COALESCE(initial_points_value, points_value)::numeric + 
     (CASE WHEN due_date IS NOT NULL THEN 1 ELSE 0 END))
  ), 0)
  INTO v_unassigned_tasks_points
  FROM tasks
  WHERE DATE(due_date) = p_date
  AND assigned_to IS NULL
  AND status NOT IN ('cancelled', 'archived');

  v_total_points := v_checkin_base + v_assigned_tasks_points + v_unassigned_tasks_points;

  RETURN ROUND(v_total_points)::integer;
END;
$$;

-- Kommentar zur Klarstellung der Logik
COMMENT ON FUNCTION calculate_team_daily_achievable_points IS 
'Berechnet Team-erreichbare Punkte für einen Tag.
WICHTIG: 
- Check-in: Anzahl Staff × 5 (alle können einchecken)
- Tasks (assigned/unassigned): Jede nur 1× (kann nur 1× erledigt werden)
- Unterschied zu individuell: Individuell sehen alle unassigned tasks als erreichbar';

-- Update alle daily_point_goals für heute
SELECT initialize_daily_goals_for_today();
