/*
  Fügt Checklist Approval Funktionen hinzu
  
  - approve_checklist_instance()
  - reject_checklist_instance()
  - Admin review Spalten
*/

-- Füge Admin Review Spalten zu checklist_instances hinzu
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklist_instances' AND column_name = 'admin_reviewed'
  ) THEN
    ALTER TABLE checklist_instances ADD COLUMN admin_reviewed boolean DEFAULT false;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklist_instances' AND column_name = 'admin_approved'
  ) THEN
    ALTER TABLE checklist_instances ADD COLUMN admin_approved boolean DEFAULT null;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklist_instances' AND column_name = 'admin_rejection_reason'
  ) THEN
    ALTER TABLE checklist_instances ADD COLUMN admin_rejection_reason text DEFAULT null;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklist_instances' AND column_name = 'reviewed_by'
  ) THEN
    ALTER TABLE checklist_instances ADD COLUMN reviewed_by uuid REFERENCES auth.users(id) DEFAULT null;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklist_instances' AND column_name = 'reviewed_at'
  ) THEN
    ALTER TABLE checklist_instances ADD COLUMN reviewed_at timestamptz DEFAULT null;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklist_instances' AND column_name = 'assigned_to'
  ) THEN
    ALTER TABLE checklist_instances ADD COLUMN assigned_to uuid REFERENCES profiles(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'checklist_instances' AND column_name = 'title'
  ) THEN
    ALTER TABLE checklist_instances ADD COLUMN title text DEFAULT '';
  END IF;
END $$;

-- Approve Checklist Function
CREATE OR REPLACE FUNCTION approve_checklist_instance(
  p_instance_id uuid,
  p_admin_id uuid,
  p_admin_photo text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_instance record;
  v_checklist record;
BEGIN
  SELECT * INTO v_instance FROM checklist_instances WHERE id = p_instance_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Checklist instance not found');
  END IF;

  IF v_instance.status != 'completed' THEN
    RETURN json_build_object('success', false, 'error', 'Only completed checklists can be approved');
  END IF;

  -- Update instance
  UPDATE checklist_instances
  SET
    admin_reviewed = true,
    admin_approved = true,
    reviewed_by = p_admin_id,
    reviewed_at = now()
  WHERE id = p_instance_id;

  -- Get checklist for title
  SELECT * INTO v_checklist FROM checklists WHERE id = v_instance.checklist_id;

  -- Notification
  IF v_instance.assigned_to IS NOT NULL OR v_instance.completed_by IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      COALESCE(v_instance.assigned_to, v_instance.completed_by),
      'Checklist genehmigt',
      'Deine Checklist "' || COALESCE(v_instance.title, v_checklist.title, 'Checklist') || '" wurde genehmigt!',
      'success'
    );
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

-- Reject Checklist Function
CREATE OR REPLACE FUNCTION reject_checklist_instance(
  p_instance_id uuid,
  p_admin_id uuid,
  p_rejection_reason text,
  p_admin_photo text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_instance record;
  v_checklist record;
  v_points_to_deduct integer;
  v_user_id uuid;
BEGIN
  SELECT * INTO v_instance FROM checklist_instances WHERE id = p_instance_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Checklist instance not found');
  END IF;

  IF v_instance.status != 'completed' THEN
    RETURN json_build_object('success', false, 'error', 'Only completed checklists can be rejected');
  END IF;

  v_user_id := COALESCE(v_instance.assigned_to, v_instance.completed_by);
  
  -- Check if points were awarded (boolean or integer)
  IF v_instance.points_awarded IS NOT NULL THEN
    -- If it's a boolean true or an integer > 0
    IF (v_instance.points_awarded::text = 'true') OR (v_instance.points_awarded::integer > 0) THEN
      -- Get checklist to know points value
      SELECT * INTO v_checklist FROM checklists WHERE id = v_instance.checklist_id;
      v_points_to_deduct := COALESCE(v_checklist.points_value, 0);
      
      -- Deduct points
      IF v_points_to_deduct > 0 AND v_user_id IS NOT NULL THEN
        INSERT INTO points_history (user_id, points_change, reason, category, created_by)
        VALUES (
          v_user_id,
          -v_points_to_deduct,
          'Checklist abgelehnt: ' || COALESCE(v_instance.title, v_checklist.title, 'Checklist'),
          'deduction',
          p_admin_id
        );
      END IF;
    END IF;
  END IF;

  -- Update instance
  UPDATE checklist_instances
  SET
    status = 'pending',
    admin_reviewed = true,
    admin_approved = false,
    admin_rejection_reason = p_rejection_reason,
    reviewed_by = p_admin_id,
    reviewed_at = now(),
    completed_at = null,
    points_awarded = false
  WHERE id = p_instance_id;

  -- Notification
  IF v_user_id IS NOT NULL THEN
    SELECT * INTO v_checklist FROM checklists WHERE id = v_instance.checklist_id;
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_user_id,
      'Checklist abgelehnt',
      'Deine Checklist "' || COALESCE(v_instance.title, v_checklist.title, 'Checklist') || '" wurde abgelehnt: ' || p_rejection_reason,
      'warning'
    );
  END IF;

  RETURN json_build_object('success', true);
END;
$$;