/*
  # Fix Team Points Always Showing 0/0
  
  ## Problem
  Die Funktion `update_daily_point_goals()` wurde von einer älteren Migration überschrieben
  und schreibt keine `percentage` und `color_status` mehr. Team Points werden berechnet,
  aber erscheinen als 0/0 im Frontend.
  
  ## Changes
  1. Repariere `update_daily_point_goals()` komplett
     - Berechne team_points einmal für alle User
     - Berechne percentage korrekt
     - Berechne color_status nach existierendem Schema
  
  ## Color Schema (existing)
  - dark_green: >= 95%
  - green: >= 90%
  - orange: >= 83%
  - yellow: >= 74%
  - red: < 74%
  - gray: 0 achievable
*/

CREATE OR REPLACE FUNCTION update_daily_point_goals(
  p_user_id uuid DEFAULT NULL,
  p_date date DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user record;
  v_target_date date;
  v_achievable integer;
  v_achieved integer;
  v_team_achievable integer;
  v_team_achieved integer;
  v_percentage numeric;
  v_color text;
BEGIN
  v_target_date := COALESCE(p_date, current_date_cambodia());

  -- Team-Punkte einmal berechnen (für alle User gleich)
  v_team_achievable := calculate_team_daily_achievable_points(v_target_date);
  v_team_achieved := calculate_team_daily_achieved_points(v_target_date);

  -- Wenn kein User angegeben, alle Staff-User updaten
  IF p_user_id IS NULL THEN
    FOR v_user IN 
      SELECT id FROM profiles WHERE role = 'staff'
    LOOP
      PERFORM update_daily_point_goals(v_user.id, v_target_date);
    END LOOP;
    RETURN;
  END IF;

  -- Individual Punkte berechnen
  v_achievable := calculate_individual_daily_achievable_points(p_user_id, v_target_date);
  v_achieved := calculate_individual_daily_achieved_points(p_user_id, v_target_date);

  -- Percentage berechnen
  IF v_achievable > 0 THEN
    v_percentage := ROUND((v_achieved::numeric / v_achievable::numeric) * 100, 2);
  ELSE
    v_percentage := 0;
  END IF;

  -- Color basierend auf existierendem Schema
  IF v_achievable = 0 THEN
    v_color := 'gray';
  ELSIF v_percentage >= 95 THEN
    v_color := 'dark_green';
  ELSIF v_percentage >= 90 THEN
    v_color := 'green';
  ELSIF v_percentage >= 83 THEN
    v_color := 'orange';
  ELSIF v_percentage >= 74 THEN
    v_color := 'yellow';
  ELSE
    v_color := 'red';
  END IF;

  -- Insert or Update mit ALLEN Feldern
  INSERT INTO daily_point_goals (
    user_id,
    goal_date,
    theoretically_achievable_points,
    achieved_points,
    team_achievable_points,
    team_points_earned,
    percentage,
    color_status
  )
  VALUES (
    p_user_id,
    v_target_date,
    v_achievable,
    v_achieved,
    v_team_achievable,
    v_team_achieved,
    v_percentage,
    v_color
  )
  ON CONFLICT (user_id, goal_date)
  DO UPDATE SET
    theoretically_achievable_points = EXCLUDED.theoretically_achievable_points,
    achieved_points = EXCLUDED.achieved_points,
    team_achievable_points = EXCLUDED.team_achievable_points,
    team_points_earned = EXCLUDED.team_points_earned,
    percentage = EXCLUDED.percentage,
    color_status = EXCLUDED.color_status,
    updated_at = now();
END;
$$;

-- Stelle sicher dass initialize_daily_goals_for_today die richtige Funktion nutzt
CREATE OR REPLACE FUNCTION initialize_daily_goals_for_today()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM update_daily_point_goals(NULL, current_date_cambodia());
END;
$$;

-- Sofort für heute aktualisieren
SELECT initialize_daily_goals_for_today();
