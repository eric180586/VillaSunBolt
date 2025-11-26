/*
  # Fix Achievable Points - Update When Task is Accepted

  ## THE PROBLEM:
  When a user accepts an unassigned task:
  1. Task.assigned_to gets updated
  2. But daily_point_goals.theoretically_achievable_points stays the same!
  3. User completes task → percentage is wrong

  ## THE FIX:
  Create a trigger that updates daily_point_goals whenever:
  - A task gets assigned to someone (assigned_to changes from NULL to user_id)
  - A task gets unassigned (assigned_to changes from user_id to NULL)
  - A helper is added (helper_id changes)

  ## EXAMPLE FLOW:
  1. Morning 08:00: achievable = 20 (5 check-in + 15 assigned)
  2. User accepts unassigned task (12 points)
     → TRIGGER fires
     → achievable updated to 32
  3. User completes task → 12 points
  4. achieved = 17/32 = 53% ✅ CORRECT!
*/

-- Function that updates daily_point_goals when task assignment changes
CREATE OR REPLACE FUNCTION update_achievable_on_task_assignment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_affected_users uuid[];
  v_user_id uuid;
  v_task_date date;
  v_is_template boolean;
BEGIN
  -- Skip template tasks
  IF TG_OP = 'DELETE' THEN
    v_is_template := OLD.is_template;
  ELSE
    v_is_template := NEW.is_template;
  END IF;

  IF v_is_template THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    ELSE
      RETURN NEW;
    END IF;
  END IF;

  -- Determine which date to update (use due_date or created_at)
  IF TG_OP = 'DELETE' THEN
    v_task_date := COALESCE(
      OLD.due_date::date,
      DATE(OLD.created_at AT TIME ZONE 'Asia/Phnom_Penh')
    );
  ELSE
    v_task_date := COALESCE(
      NEW.due_date::date,
      DATE(NEW.created_at AT TIME ZONE 'Asia/Phnom_Penh')
    );
  END IF;

  -- Collect all affected users
  v_affected_users := ARRAY[]::uuid[];

  -- If INSERT: Add new assigned users
  IF TG_OP = 'INSERT' THEN
    IF NEW.assigned_to IS NOT NULL THEN
      v_affected_users := array_append(v_affected_users, NEW.assigned_to);
    END IF;
    IF NEW.helper_id IS NOT NULL THEN
      v_affected_users := array_append(v_affected_users, NEW.helper_id);
    END IF;

  -- If UPDATE: Check what changed
  ELSIF TG_OP = 'UPDATE' THEN
    -- assigned_to changed
    IF OLD.assigned_to IS DISTINCT FROM NEW.assigned_to THEN
      -- Old user lost the task
      IF OLD.assigned_to IS NOT NULL THEN
        v_affected_users := array_append(v_affected_users, OLD.assigned_to);
      END IF;
      -- New user got the task
      IF NEW.assigned_to IS NOT NULL THEN
        v_affected_users := array_append(v_affected_users, NEW.assigned_to);
      END IF;
    END IF;

    -- helper_id changed
    IF OLD.helper_id IS DISTINCT FROM NEW.helper_id THEN
      -- Old helper lost the task
      IF OLD.helper_id IS NOT NULL THEN
        v_affected_users := array_append(v_affected_users, OLD.helper_id);
      END IF;
      -- New helper got the task
      IF NEW.helper_id IS NOT NULL THEN
        v_affected_users := array_append(v_affected_users, NEW.helper_id);
      END IF;
    END IF;

  -- If DELETE: Remove from old users
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.assigned_to IS NOT NULL THEN
      v_affected_users := array_append(v_affected_users, OLD.assigned_to);
    END IF;
    IF OLD.helper_id IS NOT NULL THEN
      v_affected_users := array_append(v_affected_users, OLD.helper_id);
    END IF;
  END IF;

  -- Update daily_point_goals for all affected users
  FOREACH v_user_id IN ARRAY v_affected_users
  LOOP
    -- Only update if it's today or future date
    -- (historical dates use points_history)
    IF v_task_date >= CURRENT_DATE THEN
      PERFORM update_daily_point_goals_for_user(v_user_id, v_task_date);
    END IF;
  END LOOP;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS trigger_update_achievable_on_task_assignment ON tasks;

-- Create trigger on tasks table
CREATE TRIGGER trigger_update_achievable_on_task_assignment
  AFTER INSERT OR UPDATE OR DELETE ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION update_achievable_on_task_assignment();

COMMENT ON FUNCTION update_achievable_on_task_assignment IS
'Automatically updates daily_point_goals.theoretically_achievable_points when task assignments change. This ensures achievable is always current when users accept/decline tasks.';

COMMENT ON TRIGGER trigger_update_achievable_on_task_assignment ON tasks IS
'Updates achievable points for affected users when task assignment changes (accept, decline, helper added, etc.)';
