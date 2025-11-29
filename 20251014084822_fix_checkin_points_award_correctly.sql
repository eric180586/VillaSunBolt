/*
  # Fix Check-In Punktevergabe System
  
  ## Problem:
  Die aktuelle approve_check_in Funktion hat fehlerhafte Logik:
  - IF points_awarded > 0 → vergibt points_awarded (korrekt)
  - ELSIF is_late → vergibt points_awarded - 5 (falsch, wird nie erreicht wenn points_awarded > 0)
  - Notification zeigt immer points_awarded statt tatsächlich vergebene Punkte
  
  ## Lösung:
  1. Vereinfachte Logik: IMMER points_awarded vergeben (kann 0-5 sein)
  2. Optional: Admin kann Punkte manuell anpassen via p_custom_points Parameter
  3. Korrekte Kategorisierung: positive=punctuality, negative=penalty, zero=keine Historie
  4. Notification zeigt tatsächlich vergebene Punkte
  
  ## Beispiele:
  - Pünktlich (9:00): 5 Punkte → punctuality
  - 5 Min spät: 4 Punkte → punctuality
  - 10 Min spät: 3 Punkte → punctuality
  - 25+ Min spät: 0 Punkte → keine points_history (aber check_in approved)
  - Admin Override: -5 bis +5 Punkte möglich
*/

-- Drop alte Funktion
DROP FUNCTION IF EXISTS approve_check_in(uuid, uuid);

-- Neue Funktion mit custom_points Parameter
CREATE OR REPLACE FUNCTION approve_check_in(
  p_check_in_id uuid,
  p_admin_id uuid,
  p_custom_points integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check_in record;
  v_reason text;
  v_final_points integer;
  v_category text;
BEGIN
  -- Verify admin role
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = p_admin_id
    AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can approve check-ins';
  END IF;

  -- Get check-in details
  SELECT * INTO v_check_in
  FROM check_ins
  WHERE id = p_check_in_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Check-in not found';
  END IF;
  
  IF v_check_in.status != 'pending' THEN
    RAISE EXCEPTION 'Check-in already processed';
  END IF;
  
  -- Determine final points: custom override or calculated
  v_final_points := COALESCE(p_custom_points, v_check_in.points_awarded);
  
  -- Update check-in status
  UPDATE check_ins
  SET 
    status = 'approved',
    approved_by = p_admin_id,
    approved_at = now(),
    points_awarded = v_final_points  -- Update with final points
  WHERE id = p_check_in_id;
  
  -- Award points (only if not zero)
  IF v_final_points != 0 THEN
    -- Determine category based on points
    IF v_final_points > 0 THEN
      v_category := 'punctuality';
      IF v_check_in.is_late THEN
        v_reason := 'Einchecken mit Verspätung (' || v_check_in.minutes_late || ' Min.) - ' || v_check_in.shift_type || 'schicht';
      ELSE
        v_reason := 'Pünktliches Einchecken - ' || v_check_in.shift_type || 'schicht';
      END IF;
    ELSE
      v_category := 'penalty';
      v_reason := 'Punktabzug für Check-In - ' || v_check_in.shift_type || 'schicht';
    END IF;
    
    -- Add custom points note if admin override
    IF p_custom_points IS NOT NULL THEN
      v_reason := v_reason || ' (Admin-Anpassung)';
    END IF;
    
    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (v_check_in.user_id, v_final_points, v_reason, v_category, p_admin_id);
  END IF;
  
  -- Update daily point goals
  PERFORM update_daily_point_goals(v_check_in.user_id, DATE(v_check_in.check_in_time));
  
  -- Notify staff member with correct points
  INSERT INTO notifications (user_id, title, message, type)
  VALUES (
    v_check_in.user_id,
    'Check-In bestätigt',
    CASE 
      WHEN v_final_points > 0 THEN 'Dein Check-In wurde bestätigt. Du hast ' || v_final_points || ' Punkte erhalten!'
      WHEN v_final_points < 0 THEN 'Dein Check-In wurde bestätigt. ' || v_final_points || ' Punkte (Abzug).'
      ELSE 'Dein Check-In wurde bestätigt.'
    END,
    'success'
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'points_awarded', v_final_points
  );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION approve_check_in(uuid, uuid, integer) TO authenticated;
