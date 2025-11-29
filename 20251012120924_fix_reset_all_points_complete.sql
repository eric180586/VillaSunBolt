/*
  # Vollständiger Punkte-Reset
  
  ## Funktionalität:
  - Löscht ALLE Einträge aus points_history
  - Löscht ALLE Einträge aus daily_point_goals
  - Setzt total_points in profiles auf 0 für alle Staff
  - Setzt alle Tasks auf initial_points_value zurück
*/

CREATE OR REPLACE FUNCTION reset_all_points()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 1. Lösche alle Punkte-History
  DELETE FROM points_history;
  
  -- 2. Lösche alle Tagesziele
  DELETE FROM daily_point_goals;
  
  -- 3. Setze total_points in profiles auf 0
  UPDATE profiles
  SET total_points = 0
  WHERE role = 'staff';
  
  -- 4. Setze alle Tasks zurück (points_value = initial_points_value)
  UPDATE tasks
  SET 
    points_value = COALESCE(initial_points_value, points_value),
    deadline_bonus_awarded = false
  WHERE initial_points_value IS NOT NULL;
  
  -- 5. Initialisiere Punkteziele für heute neu
  PERFORM initialize_daily_goals_for_today();
END;
$$;
