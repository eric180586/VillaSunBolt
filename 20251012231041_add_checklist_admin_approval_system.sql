/*
  # Add Admin Approval System for Checklists

  1. Changes to `checklist_instances` table
    - Add `admin_reviewed` boolean field (default false)
    - Add `admin_approved` boolean field (default null until reviewed)
    - Add `admin_rejection_reason` text field for rejection notes
    - Add `reviewed_by` uuid field (FK to auth.users)
    - Add `reviewed_at` timestamptz field

  2. Logic
    - When completed, checklist gets points immediately
    - Admin can review and either approve or reject
    - If rejected: points are deducted, status returns to 'pending'
    - Similar to task approval system

  3. Security
    - Only admins can review checklists
    - Staff can see rejection reason
*/

-- Add admin review fields to checklist_instances
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
END $$;

-- Function to handle checklist rejection (deduct points, reset status)
CREATE OR REPLACE FUNCTION reject_checklist_instance(
  p_instance_id uuid,
  p_admin_id uuid,
  p_rejection_reason text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_instance record;
  v_assigned_to uuid;
  v_points_to_deduct integer;
BEGIN
  -- Get instance details
  SELECT * INTO v_instance
  FROM checklist_instances
  WHERE id = p_instance_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Checklist instance not found');
  END IF;

  -- Only completed checklists can be rejected
  IF v_instance.status != 'completed' THEN
    RETURN json_build_object('success', false, 'error', 'Only completed checklists can be rejected');
  END IF;

  -- Get assigned user
  v_assigned_to := v_instance.assigned_to;
  v_points_to_deduct := v_instance.points_awarded;

  -- Update checklist instance
  UPDATE checklist_instances
  SET
    status = 'pending',
    admin_reviewed = true,
    admin_approved = false,
    admin_rejection_reason = p_rejection_reason,
    reviewed_by = p_admin_id,
    reviewed_at = now(),
    completed_at = null,
    points_awarded = 0,
    items = (
      SELECT jsonb_agg(
        jsonb_set(item, '{completed}', 'false'::jsonb)
      )
      FROM jsonb_array_elements(items) AS item
    )
  WHERE id = p_instance_id;

  -- Deduct points from user if points were awarded
  IF v_points_to_deduct > 0 AND v_assigned_to IS NOT NULL THEN
    UPDATE profiles
    SET points = GREATEST(0, points - v_points_to_deduct)
    WHERE id = v_assigned_to;
  END IF;

  -- Create notification
  INSERT INTO notifications (user_id, title, message, type)
  VALUES (
    v_assigned_to,
    'Checklist abgelehnt',
    'Deine Checklist "' || v_instance.name || '" wurde abgelehnt: ' || p_rejection_reason,
    'checklist_rejected'
  );

  RETURN json_build_object('success', true);
END;
$$;

-- Function to approve checklist
CREATE OR REPLACE FUNCTION approve_checklist_instance(
  p_instance_id uuid,
  p_admin_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_instance record;
BEGIN
  -- Get instance details
  SELECT * INTO v_instance
  FROM checklist_instances
  WHERE id = p_instance_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Checklist instance not found');
  END IF;

  -- Only completed checklists can be approved
  IF v_instance.status != 'completed' THEN
    RETURN json_build_object('success', false, 'error', 'Only completed checklists can be approved');
  END IF;

  -- Update checklist instance
  UPDATE checklist_instances
  SET
    admin_reviewed = true,
    admin_approved = true,
    reviewed_by = p_admin_id,
    reviewed_at = now()
  WHERE id = p_instance_id;

  -- Create notification
  IF v_instance.assigned_to IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
      v_instance.assigned_to,
      'Checklist genehmigt',
      'Deine Checklist "' || v_instance.name || '" wurde genehmigt! ✓',
      'checklist_approved'
    );
  END IF;

  RETURN json_build_object('success', true);
END;
$$;