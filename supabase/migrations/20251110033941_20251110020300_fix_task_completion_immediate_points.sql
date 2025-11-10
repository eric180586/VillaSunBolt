/*
  # Fix Task Completion - Award Points Immediately

  1. Changes
    - When task status changes to 'completed', award points IMMEDIATELY
    - Points = task.points_value (set by admin)
    - Deadline bonus (+1) if completed before due_date
    - Points go to points_history instantly
  
  2. Approval Process
    - Admin reviews later
    - If rejected/reopened: -1 penalty
    - If approved: Admin can add quality bonus or deductions
  
  3. Key Points
    - Staff gets feedback immediately (points appear right away)
    - Admin can adjust later during review
*/

-- Drop old trigger if exists
DROP TRIGGER IF EXISTS trigger_task_status_award_points ON tasks;
DROP FUNCTION IF EXISTS award_points_on_task_completion();

-- Create function to award points immediately on task completion
CREATE OR REPLACE FUNCTION award_points_on_task_completion()
RETURNS TRIGGER AS $$
DECLARE
  v_points_to_award integer := 0;
  v_deadline_bonus integer := 0;
  v_reason text;
  v_assignee_id uuid;
BEGIN
  -- Only trigger when status changes TO 'completed' FROM another status
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    
    -- Determine who completed it (assigned_to or secondary if helper involved)
    v_assignee_id := NEW.assigned_to;
    
    -- Base points from task
    v_points_to_award := COALESCE(NEW.points_value, 0);
    
    -- Check for deadline bonus (+1 if completed before due_date)
    IF NEW.due_date IS NOT NULL AND NEW.completed_at <= NEW.due_date THEN
      v_deadline_bonus := 1;
      v_points_to_award := v_points_to_award + v_deadline_bonus;
      NEW.deadline_bonus_awarded := true;
    END IF;

    -- Create reason text
    v_reason := 'Task completed: ' || NEW.title;
    IF v_deadline_bonus > 0 THEN
      v_reason := v_reason || ' (deadline bonus +1)';
    END IF;

    -- Award points to assigned user
    IF v_assignee_id IS NOT NULL THEN
      INSERT INTO points_history (
        user_id,
        points_change,
        reason,
        category,
        created_by
      ) VALUES (
        v_assignee_id,
        v_points_to_award,
        v_reason,
        'task_completed',
        v_assignee_id
      );

      -- Update daily point goals
      PERFORM update_daily_point_goals_for_user(v_assignee_id, CURRENT_DATE);
    END IF;

    -- If helper exists, award half points
    IF NEW.helper_id IS NOT NULL THEN
      INSERT INTO points_history (
        user_id,
        points_change,
        reason,
        category,
        created_by
      ) VALUES (
        NEW.helper_id,
        v_points_to_award / 2,
        'Task completed (helper): ' || NEW.title,
        'task_completed',
        NEW.helper_id
      );

      -- Update daily point goals for helper
      PERFORM update_daily_point_goals_for_user(NEW.helper_id, CURRENT_DATE);
    END IF;

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for immediate point awarding
CREATE TRIGGER trigger_task_status_award_points
  AFTER UPDATE OF status ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION award_points_on_task_completion();

-- Create function for task reopen penalty
CREATE OR REPLACE FUNCTION apply_reopen_penalty()
RETURNS TRIGGER AS $$
DECLARE
  v_assignee_id uuid;
BEGIN
  -- If task is reopened (from completed or other status to pending/in_progress)
  IF OLD.status = 'completed' AND NEW.status IN ('pending', 'in_progress') THEN
    
    v_assignee_id := NEW.assigned_to;

    -- Apply -1 penalty for reopen
    IF v_assignee_id IS NOT NULL THEN
      INSERT INTO points_history (
        user_id,
        points_change,
        reason,
        category,
        created_by
      ) VALUES (
        v_assignee_id,
        -1,
        'Task reopened: ' || NEW.title,
        'task_reopened',
        NEW.reviewed_by
      );

      -- Update daily point goals
      PERFORM update_daily_point_goals_for_user(v_assignee_id, CURRENT_DATE);
    END IF;

    -- Also penalty for helper if exists
    IF NEW.helper_id IS NOT NULL THEN
      INSERT INTO points_history (
        user_id,
        points_change,
        reason,
        category,
        created_by
      ) VALUES (
        NEW.helper_id,
        -1,
        'Task reopened (helper): ' || NEW.title,
        'task_reopened',
        NEW.reviewed_by
      );

      PERFORM update_daily_point_goals_for_user(NEW.helper_id, CURRENT_DATE);
    END IF;

    -- Reset deadline bonus flag
    NEW.deadline_bonus_awarded := false;

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for reopen penalty
DROP TRIGGER IF EXISTS trigger_task_reopen_penalty ON tasks;
CREATE TRIGGER trigger_task_reopen_penalty
  BEFORE UPDATE OF status ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION apply_reopen_penalty();

-- Update all daily point goals after task changes
CREATE OR REPLACE FUNCTION update_points_after_task_change()
RETURNS TRIGGER AS $$
DECLARE
  v_user_record RECORD;
BEGIN
  -- Update for all staff who might be affected
  FOR v_user_record IN 
    SELECT DISTINCT id FROM profiles WHERE role = 'staff'
  LOOP
    PERFORM update_daily_point_goals_for_user(v_user_record.id, CURRENT_DATE);
  END LOOP;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update achievable points when task assignment changes
DROP TRIGGER IF EXISTS trigger_update_achievable_on_task_change ON tasks;
CREATE TRIGGER trigger_update_achievable_on_task_change
  AFTER INSERT OR UPDATE OF assigned_to, helper_id, status ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION update_points_after_task_change();