/*
  # Add Daily Task Count Tracking
  
  1. Changes
    - Add `total_tasks_today` column to `daily_point_goals` to track total tasks created for the day
    - Add `completed_tasks_today` column to track completed tasks (including archived/deleted)
    - Update function to increment these counters when tasks are created or completed
  
  2. Purpose
    - Keep persistent count of daily tasks that doesn't decrease when tasks are deleted/archived
    - Display accurate "X completed / Y total" metrics on dashboards
    - Reset counters at end of day automatically via existing point calculation triggers
*/

-- Add columns to track daily task counts
ALTER TABLE daily_point_goals 
ADD COLUMN IF NOT EXISTS total_tasks_today integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS completed_tasks_today integer DEFAULT 0;

-- Function to update task counts when tasks are created
CREATE OR REPLACE FUNCTION increment_daily_task_count()
RETURNS TRIGGER AS $$
DECLARE
  task_date date;
BEGIN
  -- Extract date from due_date
  task_date := DATE(NEW.due_date);
  
  IF task_date IS NOT NULL THEN
    -- Insert or update daily_point_goals with incremented task count
    INSERT INTO daily_point_goals (goal_date, total_tasks_today)
    VALUES (task_date, 1)
    ON CONFLICT (goal_date) 
    DO UPDATE SET total_tasks_today = daily_point_goals.total_tasks_today + 1;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update completed task count
CREATE OR REPLACE FUNCTION increment_completed_task_count()
RETURNS TRIGGER AS $$
DECLARE
  task_date date;
BEGIN
  -- Extract date from due_date
  task_date := DATE(NEW.due_date);
  
  -- Only increment if task is being marked as completed or archived
  IF task_date IS NOT NULL AND NEW.status IN ('completed', 'archived') AND (OLD.status IS NULL OR OLD.status NOT IN ('completed', 'archived')) THEN
    -- Update completed task count
    UPDATE daily_point_goals 
    SET completed_tasks_today = completed_tasks_today + 1
    WHERE goal_date = task_date;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS task_creation_counter ON tasks;
DROP TRIGGER IF EXISTS task_completion_counter ON tasks;

-- Trigger when a task is created
CREATE TRIGGER task_creation_counter
  AFTER INSERT ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION increment_daily_task_count();

-- Trigger when a task is updated to completed/archived
CREATE TRIGGER task_completion_counter
  AFTER UPDATE ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION increment_completed_task_count();
