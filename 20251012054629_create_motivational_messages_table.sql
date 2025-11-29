/*
  # Motivational Messages System
  
  ## Neue Tabelle
  - `motivational_messages`
    - Speichert über 60 motivierende Feedback-Nachrichten
    - Wird für Task-Completion und Zielerreichung verwendet
  
  ## Security
  - RLS aktiviert
  - Alle authentifizierten User können lesen
  - Nur Admins können erstellen/bearbeiten
*/

CREATE TABLE IF NOT EXISTS motivational_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message text NOT NULL,
  category text DEFAULT 'general',
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_motivational_messages_active ON motivational_messages(is_active);

ALTER TABLE motivational_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read motivational messages"
  ON motivational_messages
  FOR SELECT
  TO authenticated
  USING (is_active = true);

CREATE POLICY "Admins can manage motivational messages"
  ON motivational_messages
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Füge über 60 motivierende Nachrichten hinzu
INSERT INTO motivational_messages (message, category) VALUES
  -- Exzellente Leistung (>95%)
  ('Unglaublich! Du bist ein absoluter Superstar! 🌟', 'excellent'),
  ('Perfekt! Deine Arbeit ist makellos!', 'excellent'),
  ('Wow! Das ist Weltklasse-Niveau!', 'excellent'),
  ('Phänomenal! Du setzt neue Maßstäbe!', 'excellent'),
  ('Outstanding! You are crushing it!', 'excellent'),
  
  -- Sehr gute Leistung (90-95%)
  ('Fantastische Arbeit! Du bist ein Star!', 'very_good'),
  ('Hervorragend! Weiter so!', 'very_good'),
  ('Großartig gemacht! Das Team ist stolz auf dich!', 'very_good'),
  ('Perfekt! Deine Hingabe zahlt sich aus!', 'very_good'),
  ('Ausgezeichnet! Du machst den Unterschied!', 'very_good'),
  ('Wunderbar! Keep up the great work!', 'very_good'),
  ('Super Leistung! Du rockst!', 'very_good'),
  ('Brillant! Deine Arbeit ist inspirierend!', 'very_good'),
  ('Spitzenleistung! Einfach großartig!', 'very_good'),
  ('Excellent work! You are amazing!', 'very_good'),
  
  -- Gute Leistung (83-90%)
  ('Sehr gut! Du bist auf dem richtigen Weg!', 'good'),
  ('Toll gemacht! Das war richtig gut!', 'good'),
  ('Klasse Arbeit! Weiter so!', 'good'),
  ('Prima! Du gibst dein Bestes!', 'good'),
  ('Gut gemacht! Deine Arbeit wird geschätzt!', 'good'),
  ('Great job! You are doing well!', 'good'),
  ('Schön! Du machst Fortschritte!', 'good'),
  ('Stark! Das kann sich sehen lassen!', 'good'),
  ('Fein! Du bist auf Kurs!', 'good'),
  ('Nice! Keep going strong!', 'good'),
  
  -- Solide Leistung (73-83%)
  ('Gut! Du arbeitest fleißig!', 'solid'),
  ('Ordentlich! Bleib dran!', 'solid'),
  ('Weiter so! Du schaffst das!', 'solid'),
  ('Nicht schlecht! Keep pushing!', 'solid'),
  ('Guter Einsatz! Weitermachen!', 'solid'),
  ('Respekt! Du gibst nicht auf!', 'solid'),
  ('Läuft! Bleib am Ball!', 'solid'),
  ('Alright! You are making progress!', 'solid'),
  ('Okay! Gib weiter Gas!', 'solid'),
  ('Solid work! Keep it up!', 'solid'),
  
  -- Allgemeine motivierende Nachrichten
  ('Jeder Tag ist eine neue Chance! 💪', 'general'),
  ('Du machst einen Unterschied!', 'general'),
  ('Deine Arbeit ist wichtig!', 'general'),
  ('Das Team braucht dich!', 'general'),
  ('Gemeinsam sind wir stark!', 'general'),
  ('Deine Energie ist ansteckend!', 'general'),
  ('Du bist ein wichtiger Teil des Teams!', 'general'),
  ('Danke für deine harte Arbeit!', 'general'),
  ('Wir schätzen dich sehr!', 'general'),
  ('You make this place better!', 'general'),
  ('Dein Einsatz wird gesehen!', 'general'),
  ('Du bist wertvoll für uns!', 'general'),
  ('Keep shining! ✨', 'general'),
  ('Deine positive Einstellung rockt!', 'general'),
  ('Du inspirierst andere!', 'general'),
  
  -- Ermutigende Nachrichten
  ('Gib nicht auf! Du schaffst das! 🚀', 'encouraging'),
  ('Kleine Schritte führen zum Ziel!', 'encouraging'),
  ('Jeder Fortschritt zählt!', 'encouraging'),
  ('Morgen ist ein neuer Tag!', 'encouraging'),
  ('Du lernst und wächst jeden Tag!', 'encouraging'),
  ('Fehler sind Teil des Lernens!', 'encouraging'),
  ('Bleib positiv! Es wird besser!', 'encouraging'),
  ('Du hast mehr Kraft, als du denkst!', 'encouraging'),
  ('Challenges make you stronger!', 'encouraging'),
  ('Weitermachen lohnt sich!', 'encouraging'),
  
  -- Teamwork Nachrichten
  ('Teamwork makes the dream work! 🤝', 'teamwork'),
  ('Zusammen schaffen wir alles!', 'teamwork'),
  ('Deine Hilfe ist Gold wert!', 'teamwork'),
  ('Gemeinsam zum Erfolg!', 'teamwork'),
  ('One team, one dream!', 'teamwork'),
  ('Du bist ein toller Teamplayer!', 'teamwork'),
  ('Gemeinsam statt einsam!', 'teamwork'),
  ('Together we rise!', 'teamwork'),
  ('Das Team ist stolz auf dich!', 'teamwork'),
  ('Wir sind ein starkes Team!', 'teamwork')
ON CONFLICT DO NOTHING;

-- Funktion zum Abrufen einer zufälligen motivierenden Nachricht
CREATE OR REPLACE FUNCTION get_random_motivational_message(
  p_category text DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_message text;
BEGIN
  IF p_category IS NOT NULL THEN
    SELECT message INTO v_message
    FROM motivational_messages
    WHERE is_active = true
    AND category = p_category
    ORDER BY random()
    LIMIT 1;
  ELSE
    SELECT message INTO v_message
    FROM motivational_messages
    WHERE is_active = true
    ORDER BY random()
    LIMIT 1;
  END IF;
  
  RETURN COALESCE(v_message, 'Great job! Keep up the good work!');
END;
$$;

-- Aktualisiere approve_task_with_points um die Datenbank-Nachrichten zu nutzen
CREATE OR REPLACE FUNCTION approve_task_with_points(
  p_task_id uuid,
  p_admin_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_task record;
  v_base_points integer;
  v_deadline_bonus integer := 0;
  v_reopen_penalty integer := 0;
  v_total_points integer;
  v_reason text;
  v_is_within_deadline boolean := false;
  v_user_name text;
  v_feedback_message text;
BEGIN
  -- Verify admin role
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = p_admin_id
    AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can approve tasks';
  END IF;

  -- Get task details
  SELECT * INTO v_task
  FROM tasks
  WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;
  
  IF v_task.status != 'pending_review' THEN
    RAISE EXCEPTION 'Task is not pending review';
  END IF;

  -- Basis-Punkte
  v_base_points := v_task.points_value;

  -- Prüfe ob innerhalb der Deadline erledigt
  IF v_task.due_date IS NOT NULL THEN
    v_is_within_deadline := v_task.completed_at <= v_task.due_date;
    IF v_is_within_deadline AND NOT v_task.deadline_bonus_awarded THEN
      v_deadline_bonus := 2;
    END IF;
  END IF;

  -- Reopen-Penalty: -1 Punkt pro Reopen
  IF v_task.reopened_count > 0 THEN
    v_reopen_penalty := v_task.reopened_count * (-1);
  END IF;

  -- Gesamtpunkte
  v_total_points := v_base_points + v_deadline_bonus + v_reopen_penalty;
  
  -- Mindestens 0 Punkte
  IF v_total_points < 0 THEN
    v_total_points := 0;
  END IF;

  -- Update task status
  UPDATE tasks
  SET 
    status = 'completed',
    completed_at = COALESCE(completed_at, now()),
    deadline_bonus_awarded = (v_deadline_bonus > 0),
    initial_points_value = COALESCE(initial_points_value, points_value),
    points_value = v_total_points,
    updated_at = now()
  WHERE id = p_task_id;

  -- Punkte vergeben an Hauptmitarbeiter
  IF v_task.assigned_to IS NOT NULL AND v_total_points > 0 THEN
    v_reason := 'Aufgabe erledigt: ' || v_task.title;
    
    IF v_deadline_bonus > 0 THEN
      v_reason := v_reason || ' (✓ Deadline-Bonus +2)';
    END IF;
    
    IF v_reopen_penalty < 0 THEN
      v_reason := v_reason || ' (' || v_reopen_penalty || ' wegen ' || v_task.reopened_count || 'x Reopen)';
    END IF;

    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (v_task.assigned_to, v_total_points, v_reason, 'task_completed', p_admin_id);

    -- Punkteziele updaten
    PERFORM update_daily_point_goals(v_task.assigned_to, CURRENT_DATE);
  END IF;

  -- Punkte vergeben an zweiten Mitarbeiter (halbe Punkte)
  IF v_task.secondary_assigned_to IS NOT NULL THEN
    v_total_points := GREATEST(v_total_points / 2, 0);
    v_reason := 'Aufgabe erledigt (Assistent): ' || v_task.title;

    IF v_deadline_bonus > 0 THEN
      v_reason := v_reason || ' (✓ Deadline-Bonus +1)';
    END IF;

    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (v_task.secondary_assigned_to, v_total_points, v_reason, 'task_completed', p_admin_id);

    -- Punkteziele updaten
    PERFORM update_daily_point_goals(v_task.secondary_assigned_to, CURRENT_DATE);
  END IF;

  -- Hole zufällige motivierende Nachricht aus Datenbank
  v_feedback_message := get_random_motivational_message('very_good');

  -- Get user name
  SELECT full_name INTO v_user_name
  FROM profiles
  WHERE id = v_task.assigned_to;

  -- Notification an Mitarbeiter mit positivem Feedback
  IF v_task.assigned_to IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_task.assigned_to,
      'Sehr gut gemacht! 🌟',
      v_feedback_message || ' +' || (v_base_points + v_deadline_bonus + v_reopen_penalty) || ' Punkte für: ' || v_task.title,
      'success'
    );
  END IF;

  IF v_task.secondary_assigned_to IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_task.secondary_assigned_to,
      'Sehr gut gemacht! 🌟',
      v_feedback_message || ' +' || GREATEST((v_base_points + v_deadline_bonus + v_reopen_penalty) / 2, 0) || ' Punkte für: ' || v_task.title,
      'success'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'base_points', v_base_points,
    'deadline_bonus', v_deadline_bonus,
    'reopen_penalty', v_reopen_penalty,
    'total_points', v_total_points,
    'within_deadline', v_is_within_deadline,
    'feedback_message', v_feedback_message
  );
END;
$$;
