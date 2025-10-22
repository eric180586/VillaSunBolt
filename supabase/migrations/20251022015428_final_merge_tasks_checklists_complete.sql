/*
  # Final Tasks & Checklists Merge - Complete System

  1. Changes
    - Migrate all remaining checklist instances to tasks table
    - Drop checklist_instances and checklists tables completely
    - Update all point calculation functions to use only tasks table
    - Clean up old references
  
  2. Security
    - No RLS changes needed (tasks table already has policies)
*/

-- ==========================================
-- 1. MIGRATE REMAINING CHECKLIST INSTANCES
-- ==========================================

DO $$
DECLARE
  v_instance record;
  v_checklist record;
BEGIN
  FOR v_instance IN 
    SELECT ci.* FROM checklist_instances ci
  LOOP
    -- Get checklist template info
    SELECT * INTO v_checklist FROM checklists WHERE id = v_instance.checklist_id;
    
    -- Only insert if not already migrated
    IF NOT EXISTS (
      SELECT 1 FROM tasks 
      WHERE title = COALESCE(v_instance.title, v_checklist.title)
        AND assigned_to = v_instance.assigned_to
        AND due_date::date = v_instance.instance_date
    ) THEN
      INSERT INTO tasks (
        title, description, category, items, assigned_to, status,
        points_value, initial_points_value, duration_minutes,
        photo_proof_required, photo_required_sometimes, photo_optional,
        photo_explanation_text, photo_urls, admin_photos, admin_notes,
        due_date, completed_at, created_at, updated_at, is_template, recurrence
      ) VALUES (
        COALESCE(v_instance.title, v_checklist.title),
        v_checklist.description,
        v_checklist.category,
        COALESCE(v_instance.items, v_checklist.items, '[]'::jsonb),
        v_instance.assigned_to,
        v_instance.status,
        COALESCE(v_instance.points_awarded, v_checklist.points_value, 10),
        COALESCE(v_checklist.points_value, 10),
        COALESCE(v_checklist.duration_minutes, 30),
        COALESCE(v_checklist.photo_required, false),
        COALESCE(v_checklist.photo_required_sometimes, false),
        COALESCE(v_checklist.photo_optional, false),
        COALESCE(v_instance.photo_explanation_text, v_checklist.photo_explanation_text),
        COALESCE(v_instance.photo_urls, '[]'::jsonb),
        COALESCE(v_instance.admin_photos, '[]'::jsonb),
        v_instance.admin_rejection_reason,
        v_instance.instance_date::timestamptz,
        v_instance.completed_at,
        v_instance.created_at,
        v_instance.updated_at,
        false,
        'one_time'
      );
    END IF;
  END LOOP;
END $$;

-- ==========================================
-- 2. DROP OLD TABLES
-- ==========================================

DROP TABLE IF EXISTS checklist_instances CASCADE;
DROP TABLE IF EXISTS checklists CASCADE;

-- ==========================================
-- 3. UPDATE POINT CALCULATION FUNCTIONS
-- ==========================================

-- This function should only count from tasks table now
CREATE OR REPLACE FUNCTION calculate_user_daily_points(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
) RETURNS TABLE (
  earned_points integer,
  achievable_points integer
) LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_cambodia_date date;
BEGIN
  v_cambodia_date := (p_date AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Phnom_Penh')::date;

  RETURN QUERY
  SELECT 
    COALESCE(SUM(
      CASE 
        WHEN t.status = 'completed' THEN 
          t.points_value + CASE WHEN t.deadline_bonus_awarded THEN 2 ELSE 0 END
        ELSE 0 
      END
    )::integer, 0) as earned_points,
    
    COALESCE(SUM(
      t.initial_points_value + 2
    )::integer, 0) as achievable_points
    
  FROM tasks t
  WHERE t.assigned_to = p_user_id
    AND (t.due_date AT TIME ZONE 'Asia/Phnom_Penh')::date = v_cambodia_date
    AND t.is_template = false
    AND COALESCE(t.status, 'pending') != 'archived';
END; $$;

-- Calculate team daily points (only from tasks table)
CREATE OR REPLACE FUNCTION calculate_team_daily_points(
  p_date date DEFAULT CURRENT_DATE
) RETURNS TABLE (
  earned_points integer,
  achievable_points integer
) LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_cambodia_date date;
BEGIN
  v_cambodia_date := (p_date AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Phnom_Penh')::date;

  RETURN QUERY
  SELECT 
    COALESCE(SUM(
      CASE 
        WHEN t.status = 'completed' THEN
          CASE 
            WHEN t.secondary_assigned_to IS NOT NULL THEN t.points_value * 2
            ELSE t.points_value
          END +
          CASE WHEN t.deadline_bonus_awarded THEN 2 ELSE 0 END
        ELSE 0 
      END
    )::integer, 0) as earned_points,
    
    COALESCE(SUM(
      t.initial_points_value + 2
    )::integer, 0) as achievable_points
    
  FROM tasks t
  WHERE (t.due_date AT TIME ZONE 'Asia/Phnom_Penh')::date = v_cambodia_date
    AND t.is_template = false
    AND COALESCE(t.status, 'pending') != 'archived'
    AND t.assigned_to IN (SELECT id FROM profiles WHERE role = 'staff');
END; $$;

-- Count tasks for today (no more checklist_instances)
CREATE OR REPLACE FUNCTION count_user_tasks_today(p_user_id uuid)
RETURNS TABLE (
  total_count integer,
  completed_count integer,
  pending_count integer,
  pending_review_count integer
) LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_today_cambodia date;
BEGIN
  v_today_cambodia := (now() AT TIME ZONE 'Asia/Phnom_Penh')::date;
  
  RETURN QUERY
  SELECT 
    COUNT(*)::integer as total_count,
    COUNT(*) FILTER (WHERE status = 'completed')::integer as completed_count,
    COUNT(*) FILTER (WHERE status = 'pending')::integer as pending_count,
    COUNT(*) FILTER (WHERE status = 'pending_review')::integer as pending_review_count
  FROM tasks
  WHERE assigned_to = p_user_id
    AND (due_date AT TIME ZONE 'Asia/Phnom_Penh')::date = v_today_cambodia
    AND is_template = false
    AND COALESCE(status, 'pending') != 'archived';
END; $$;

-- Count team tasks for today
CREATE OR REPLACE FUNCTION count_team_tasks_today()
RETURNS TABLE (
  total_count integer,
  completed_count integer,
  pending_count integer,
  pending_review_count integer
) LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_today_cambodia date;
BEGIN
  v_today_cambodia := (now() AT TIME ZONE 'Asia/Phnom_Penh')::date;
  
  RETURN QUERY
  SELECT 
    COUNT(*)::integer as total_count,
    COUNT(*) FILTER (WHERE status = 'completed')::integer as completed_count,
    COUNT(*) FILTER (WHERE status = 'pending')::integer as pending_count,
    COUNT(*) FILTER (WHERE status = 'pending_review')::integer as pending_review_count
  FROM tasks
  WHERE (due_date AT TIME ZONE 'Asia/Phnom_Penh')::date = v_today_cambodia
    AND is_template = false
    AND COALESCE(status, 'pending') != 'archived'
    AND assigned_to IN (SELECT id FROM profiles WHERE role = 'staff');
END; $$;

COMMENT ON FUNCTION calculate_user_daily_points IS 'Calculates earned and achievable points for a user on a specific date (only from tasks table)';
COMMENT ON FUNCTION calculate_team_daily_points IS 'Calculates total team earned and achievable points (only from tasks table)';
COMMENT ON FUNCTION count_user_tasks_today IS 'Counts tasks for user today (unified system)';
COMMENT ON FUNCTION count_team_tasks_today IS 'Counts team tasks for today (unified system)';
