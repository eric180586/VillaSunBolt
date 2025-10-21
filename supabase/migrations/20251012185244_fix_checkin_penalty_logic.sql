/*
  # Check-in System Penalty Fix
  
  ## Problem:
  Die process_check_in Funktion hat einen Logikfehler:
  - Bei Verspätung wird v_points auf 0 reduziert (korrekt)
  - Aber die ELSIF Bedingung `v_points < 0` wird NIE erreicht
  - Dadurch gibt es KEINE Penalty-Einträge in points_history
  
  ## Lösung:
  - Separate Berechnung für Penalty-Punkte
  - Bei Verspätung > 25 Min: -5 Punkte Penalty
  - Bei Verspätung < 25 Min: Reduzierte Punkte (0-4)
  
  ## Beispiele:
  - Pünktlich: +5 Punkte
  - 5 Min zu spät: +4 Punkte
  - 10 Min zu spät: +3 Punkte
  - 25+ Min zu spät: 0 Punkte Bonus, -5 Punkte Penalty = -5 gesamt
*/

CREATE OR REPLACE FUNCTION process_check_in(
  p_user_id uuid,
  p_shift_type text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_check_in_time timestamptz;
  v_shift_start_time time;
  v_minutes_late integer := 0;
  v_is_late boolean := false;
  v_points integer := 5;
  v_penalty_points integer := 0;
  v_check_in_id uuid;
  v_reason text;
BEGIN
  v_check_in_time := now();
  
  -- Determine shift start time (9:00 für früh, 15:00 für spät)
  IF p_shift_type = 'früh' THEN
    v_shift_start_time := '09:00:00'::time;
  ELSE
    v_shift_start_time := '15:00:00'::time;
  END IF;
  
  -- Calculate if late and by how much
  IF v_check_in_time::time > v_shift_start_time THEN
    v_is_late := true;
    v_minutes_late := EXTRACT(EPOCH FROM (v_check_in_time::time - v_shift_start_time)) / 60;
    
    -- Berechne Bonus-Punkte (1 Punkt pro 5 Min weniger)
    v_points := 5 - (v_minutes_late / 5)::integer;
    
    -- Minimum 0 Punkte für Bonus
    IF v_points < 0 THEN
      v_points := 0;
    END IF;
    
    -- PENALTY: Ab 25 Minuten Verspätung gibt es zusätzlich -5 Punkte
    IF v_minutes_late >= 25 THEN
      v_penalty_points := -5;
    END IF;
  END IF;
  
  -- Create check-in record mit Bonus-Punkten (0-5)
  INSERT INTO check_ins (user_id, check_in_time, shift_type, is_late, minutes_late, points_awarded)
  VALUES (p_user_id, v_check_in_time, p_shift_type, v_is_late, v_minutes_late, v_points)
  RETURNING id INTO v_check_in_id;
  
  -- Award positive points if any
  IF v_points > 0 THEN
    v_reason := 'Pünktliches Einchecken - ' || p_shift_type || 'schicht';
    
    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (p_user_id, v_points, v_reason, 'punctuality', p_user_id);
  END IF;
  
  -- Apply penalty if late >= 25 minutes
  IF v_penalty_points < 0 THEN
    v_reason := 'Verspätetes Einchecken (' || v_minutes_late || ' Min.) - ' || p_shift_type || 'schicht';
    
    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (p_user_id, v_penalty_points, v_reason, 'penalty', p_user_id);
  END IF;
  
  RETURN jsonb_build_object(
    'check_in_id', v_check_in_id,
    'is_late', v_is_late,
    'minutes_late', v_minutes_late,
    'points_awarded', v_points,
    'penalty_points', v_penalty_points,
    'total_points', v_points + v_penalty_points
  );
END;
$$;
