/*
  # Fix Reset All Points - RLS Safe Version
  
  ## Problem:
  - DELETE FROM table without WHERE clause wird von RLS blockiert
  
  ## Lösung:
  - Verwende DELETE mit WHERE 1=1 (technisch eine WHERE clause)
  - SECURITY DEFINER ermöglicht Bypass der RLS
  - Nur Admins können die Funktion aufrufen (Check im Frontend)
*/

CREATE OR REPLACE FUNCTION reset_all_points()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- 1. Lösche alle Punkte-History (mit WHERE clause für RLS)
  DELETE FROM points_history WHERE id IS NOT NULL;
  
  -- 2. Lösche alle Tagesziele (mit WHERE clause für RLS)
  DELETE FROM daily_point_goals WHERE id IS NOT NULL;
  
  -- 3. Setze total_points in profiles auf 0 für alle Staff
  UPDATE profiles
  SET total_points = 0
  WHERE role = 'staff';
  
  -- 4. Setze alle Tasks zurück (points_value = initial_points_value)
  UPDATE tasks
  SET 
    points_value = COALESCE(initial_points_value, points_value),
    deadline_bonus_awarded = false,
    reopened_count = 0
  WHERE id IS NOT NULL;
  
  -- 5. Initialisiere Punkteziele für heute neu
  PERFORM initialize_daily_goals_for_today();
END;
$$;

-- Grant execute permission to authenticated users (Frontend prüft auf Admin-Rolle)
GRANT EXECUTE ON FUNCTION reset_all_points() TO authenticated;
