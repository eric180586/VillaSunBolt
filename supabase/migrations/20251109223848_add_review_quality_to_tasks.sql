/*
  # Add Review Quality System to Tasks

  1. Changes
    - Add `review_quality` column to tasks table
      - Values: 'very_good' (+2 points), 'ready' (+0 points), 'not_ready' (-1 points)
    - Add `quality_bonus_points` column to track the bonus/penalty
    - Update approve_task_with_points function to handle quality bonuses

  2. Notes
    - Very Good: Base points + 2 bonus points
    - Ready: Base points only (0 bonus)
    - Not Ready: Base points - 1 penalty point
*/

-- Add review_quality column to tasks
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'review_quality'
  ) THEN
    ALTER TABLE tasks ADD COLUMN review_quality text CHECK (review_quality IN ('very_good', 'ready', 'not_ready'));
  END IF;
END $$;

-- Add quality_bonus_points column to tasks
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tasks' AND column_name = 'quality_bonus_points'
  ) THEN
    ALTER TABLE tasks ADD COLUMN quality_bonus_points integer DEFAULT 0;
  END IF;
END $$;

-- Create or replace the approve_task_with_quality function
CREATE OR REPLACE FUNCTION approve_task_with_quality(
  p_task_id uuid,
  p_admin_id uuid,
  p_review_quality text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_task record;
  v_base_points integer;
  v_quality_bonus integer;
  v_total_points integer;
  v_deadline_bonus integer := 0;
  v_staff_id uuid;
  v_helper_id uuid;
BEGIN
  -- Get task details
  SELECT * INTO v_task FROM tasks WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found';
  END IF;

  -- Determine quality bonus
  CASE p_review_quality
    WHEN 'very_good' THEN v_quality_bonus := 2;
    WHEN 'ready' THEN v_quality_bonus := 0;
    WHEN 'not_ready' THEN v_quality_bonus := -1;
    ELSE v_quality_bonus := 0;
  END CASE;

  -- Get base points
  v_base_points := COALESCE(v_task.points_value, 0);
  
  -- Check for deadline bonus (completed before due date)
  IF v_task.completed_at < v_task.due_date THEN
    v_deadline_bonus := 2;
  END IF;

  -- Calculate total points
  v_total_points := v_base_points + v_quality_bonus + v_deadline_bonus;
  
  -- Ensure points don't go negative
  IF v_total_points < 0 THEN
    v_total_points := 0;
  END IF;

  v_staff_id := v_task.assigned_to;
  v_helper_id := v_task.helper_id;

  -- Update task status
  UPDATE tasks 
  SET 
    status = 'approved',
    admin_reviewed = true,
    admin_approved = true,
    reviewed_by = p_admin_id,
    reviewed_at = now(),
    review_quality = p_review_quality,
    quality_bonus_points = v_quality_bonus,
    updated_at = now()
  WHERE id = p_task_id;

  -- Award points to primary staff
  IF v_staff_id IS NOT NULL THEN
    INSERT INTO points_history (user_id, task_id, points, reason, category)
    VALUES (
      v_staff_id,
      p_task_id,
      v_total_points,
      'Task completed and approved',
      v_task.category
    );
  END IF;

  -- Award 50% points to helper if exists
  IF v_helper_id IS NOT NULL AND v_helper_id != v_staff_id THEN
    INSERT INTO points_history (user_id, task_id, points, reason, category)
    VALUES (
      v_helper_id,
      p_task_id,
      GREATEST(FLOOR(v_total_points * 0.5), 0),
      'Task assistance (50%)',
      v_task.category
    );
  END IF;

  -- Return success with point breakdown
  RETURN jsonb_build_object(
    'success', true,
    'base_points', v_base_points,
    'quality_bonus', v_quality_bonus,
    'deadline_bonus', v_deadline_bonus,
    'total_points', v_total_points
  );
END;
$$;
