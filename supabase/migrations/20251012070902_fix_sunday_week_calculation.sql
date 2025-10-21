/*
  # Fix: Sonntag gehört zur gleichen Woche (Montag-Sonntag)

  ## Problem
  - Postgres date_trunc('week') gibt Montag zurück
  - Sonntag (DOW=0) ist der LETZTE Tag der Woche, nicht der erste
  - Sonntag 12. Okt gehört zur Woche vom 6. Okt (Montag)

  ## Lösung
  - NICHT 7 Tage subtrahieren für Sonntag
  - Postgres date_trunc('week') gibt bereits den korrekten Montag
*/

CREATE OR REPLACE FUNCTION user_is_scheduled_today(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_scheduled boolean := false;
  v_week_start date;
  v_day_name text;
BEGIN
  -- Postgres date_trunc('week') gibt immer den Montag zurück
  -- Sonntag ist der LETZTE Tag dieser Woche, nicht Anfang der nächsten
  v_week_start := date_trunc('week', p_date)::date;

  -- Tag-Name (lowercase, getrimmt)
  v_day_name := LOWER(TRIM(TO_CHAR(p_date, 'Day')));

  -- Prüfe ob User einen Nicht-Off Shift hat
  SELECT EXISTS (
    SELECT 1
    FROM weekly_schedules ws,
         jsonb_array_elements(ws.shifts) as shift
    WHERE ws.staff_id = p_user_id
    AND ws.week_start_date = v_week_start
    AND shift->>'day' = v_day_name
    AND shift->>'shift' != 'off'
  ) INTO v_is_scheduled;

  RETURN v_is_scheduled;
END;
$$;

-- Update daily_point_goals
SELECT update_daily_point_goals(NULL, CURRENT_DATE);
