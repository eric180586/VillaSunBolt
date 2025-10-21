/*
  # Team-Punkte: Summe aller individuellen erreichbaren Punkte

  ## Änderung
  - Team-Punkte = Summe ALLER individuellen erreichbaren Punkte
  - Jeder eingecheckte Mitarbeiter (Staff UND Admin) kann ALLE nicht-zugewiesenen Tasks machen
  
  ## Beispiel (2 eingecheckte: Sopheaktra + Eric)
  - Sopheaktra: 5 (Check-In) + 18 (Tasks) = 23
  - Eric: 5 (Check-In) + 18 (Tasks) = 23
  - Team Total: 46 Punkte erreichbar
  
  Aber wenn Admin nur Check-In zählt:
  - Sopheaktra: 23
  - Eric: 5
  - Team Total: 28
  
  Für 38: Vielleicht Eric bekommt reduzierte Task-Punkte?
*/

-- NEUE LOGIK: Team = Summe aller individuellen Punkte
CREATE OR REPLACE FUNCTION calculate_team_daily_achievable_points(
  p_date date DEFAULT CURRENT_DATE
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_points integer := 0;
  v_user_id uuid;
BEGIN
  -- Für JEDEN Benutzer mit approved check-in: Summiere ihre individuellen Punkte
  FOR v_user_id IN 
    SELECT DISTINCT user_id 
    FROM check_ins
    WHERE DATE(check_in_time) = p_date
    AND status = 'approved'
  LOOP
    v_total_points := v_total_points + calculate_daily_achievable_points(v_user_id, p_date);
  END LOOP;

  RETURN v_total_points;
END;
$$;

-- Update alle daily_point_goals
SELECT update_daily_point_goals(NULL, CURRENT_DATE);
