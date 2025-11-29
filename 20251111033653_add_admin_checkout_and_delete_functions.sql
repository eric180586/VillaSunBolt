/*
  # Admin Checkout und Delete Funktionen mit Logging

  1. Neue Funktionen
    - `admin_checkout_user` - Admin kann Mitarbeiter manuell auschecken
    - `admin_delete_profile` - Super Admin kann Profile löschen (mit Log)
    - `admin_delete_task` - Admin kann Tasks löschen (Regular Admin braucht Bestätigung)
    
  2. Security
    - Super Admin: kann alles
    - Regular Admin: muss Tasks mit Bestätigung löschen, kann keine Profile löschen
*/

-- Funktion zum manuellen Check-out (Admin schickt Mitarbeiter nach Hause)
CREATE OR REPLACE FUNCTION admin_checkout_user(
  p_admin_id uuid,
  p_user_id uuid,
  p_checkout_time timestamptz DEFAULT now(),
  p_reason text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_check_in_id uuid;
  v_user_name text;
  v_result jsonb;
BEGIN
  -- Prüfe ob Admin
  IF NOT EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = p_admin_id 
    AND role IN ('admin', 'super_admin')
  ) THEN
    RAISE EXCEPTION 'Nur Admins können Mitarbeiter auschecken';
  END IF;

  -- Hole letztes Check-in des Users ohne Check-out
  SELECT id INTO v_check_in_id
  FROM check_ins
  WHERE user_id = p_user_id
  AND check_out_time IS NULL
  AND status = 'approved'
  ORDER BY check_in_time DESC
  LIMIT 1;

  IF v_check_in_id IS NULL THEN
    RAISE EXCEPTION 'Kein aktives Check-in gefunden für diesen Mitarbeiter';
  END IF;

  -- Hole User Name
  SELECT full_name INTO v_user_name
  FROM profiles
  WHERE id = p_user_id;

  -- Update Check-in mit Check-out Zeit
  UPDATE check_ins
  SET 
    check_out_time = p_checkout_time,
    updated_at = now()
  WHERE id = v_check_in_id;

  -- Log erstellen
  PERFORM log_admin_action(
    p_admin_id,
    'manual_checkout',
    'check_in',
    v_check_in_id,
    v_user_name,
    jsonb_build_object(
      'user_id', p_user_id,
      'user_name', v_user_name,
      'checkout_time', p_checkout_time,
      'reason', p_reason
    )
  );

  -- Benachrichtigung an Mitarbeiter
  INSERT INTO notifications (user_id, type, title_en, title_de, title_km, message_en, message_de, message_km, priority)
  VALUES (
    p_user_id,
    'checkout_approved',
    'You have been checked out',
    'Du wurdest ausgecheckt',
    'អ្នកត្រូវបានចេញពីការងារ',
    'An admin has checked you out for today. See you tomorrow!',
    'Ein Admin hat dich für heute ausgecheckt. Bis morgen!',
    'អ្នកគ្រប់គ្រងបានចុះឈ្មោះអ្នកចេញសម្រាប់ថ្ងៃនេះ។ ជួបគ្នាថ្ងៃស្អែក!',
    'normal'
  );

  v_result := jsonb_build_object(
    'success', true,
    'check_in_id', v_check_in_id,
    'user_name', v_user_name,
    'checkout_time', p_checkout_time
  );

  RETURN v_result;
END;
$$;

-- Admin löscht Profil (nur Super Admin)
CREATE OR REPLACE FUNCTION admin_delete_profile(
  p_admin_id uuid,
  p_profile_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_profile_name text;
  v_admin_role text;
BEGIN
  -- Prüfe Admin Rolle
  SELECT role INTO v_admin_role
  FROM profiles
  WHERE id = p_admin_id;

  -- Nur Super Admin kann User löschen
  IF v_admin_role != 'super_admin' THEN
    RAISE EXCEPTION 'Nur Super Admins können Mitarbeiter löschen';
  END IF;

  -- Hole Profil Name
  SELECT full_name INTO v_profile_name
  FROM profiles
  WHERE id = p_profile_id;

  IF v_profile_name IS NULL THEN
    RAISE EXCEPTION 'Profil nicht gefunden';
  END IF;

  -- Log erstellen BEVOR gelöscht wird
  PERFORM log_admin_action(
    p_admin_id,
    'delete_profile',
    'profile',
    p_profile_id,
    v_profile_name,
    jsonb_build_object('profile_name', v_profile_name)
  );

  -- Lösche Profil
  DELETE FROM profiles WHERE id = p_profile_id;

  RETURN jsonb_build_object('success', true, 'deleted_profile', v_profile_name);
END;
$$;

-- Admin löscht Task (mit Bestätigung bei regular admin)
CREATE OR REPLACE FUNCTION admin_delete_task(
  p_admin_id uuid,
  p_task_id uuid,
  p_confirmed boolean DEFAULT false
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task_title text;
  v_admin_role text;
BEGIN
  -- Prüfe Admin Rolle
  SELECT role INTO v_admin_role
  FROM profiles
  WHERE id = p_admin_id;

  IF v_admin_role NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'Nur Admins können Tasks löschen';
  END IF;

  -- Regular Admin muss bestätigen
  IF v_admin_role = 'admin' AND p_confirmed = false THEN
    RAISE EXCEPTION 'CONFIRMATION_REQUIRED';
  END IF;

  -- Hole Task Titel
  SELECT title INTO v_task_title
  FROM tasks
  WHERE id = p_task_id;

  IF v_task_title IS NULL THEN
    RAISE EXCEPTION 'Task nicht gefunden';
  END IF;

  -- Log erstellen
  PERFORM log_admin_action(
    p_admin_id,
    'delete_task',
    'task',
    p_task_id,
    v_task_title,
    jsonb_build_object('task_title', v_task_title, 'confirmed', p_confirmed)
  );

  -- Lösche Task
  DELETE FROM tasks WHERE id = p_task_id;

  RETURN jsonb_build_object('success', true, 'deleted_task', v_task_title);
END;
$$;