/*
  # Add User-Specific Daily Task Counts
  
  1. New Table
    - `user_daily_task_counts` to track task counts per user per day
    - Stores total tasks assigned and completed tasks for each user
  
  2. Purpose
    - Track individual user task counts that persist even when tasks are deleted
    - Display accurate "X completed / Y total" metrics on staff dashboards
    - Reset automatically at end of day
*/

-- Create table for user-specific daily task counts
CREATE TABLE IF NOT EXISTS user_daily_task_counts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  count_date date NOT NULL DEFAULT CURRENT_DATE,
  total_tasks integer DEFAULT 0,
  completed_tasks integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, count_date)
);

-- Enable RLS
ALTER TABLE user_daily_task_counts ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own task counts"
  ON user_daily_task_counts FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all task counts"
  ON user_daily_task_counts FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

-- Function to update user task counts when tasks are created
CREATE OR REPLACE FUNCTION increment_user_task_count()
RETURNS TRIGGER AS $$
DECLARE
  task_date date;
BEGIN
  -- Extract date from due_date
  task_date := DATE(NEW.due_date);
  
  IF task_date IS NOT NULL THEN
    -- Increment for primary assigned user
    IF NEW.assigned_to IS NOT NULL THEN
      INSERT INTO user_daily_task_counts (user_id, count_date, total_tasks)
      VALUES (NEW.assigned_to, task_date, 1)
      ON CONFLICT (user_id, count_date) 
      DO UPDATE SET total_tasks = user_daily_task_counts.total_tasks + 1;
    END IF;
    
    -- Increment for secondary assigned user (if different)
    IF NEW.secondary_assigned_to IS NOT NULL AND NEW.secondary_assigned_to != NEW.assigned_to THEN
      INSERT INTO user_daily_task_counts (user_id, count_date, total_tasks)
      VALUES (NEW.secondary_assigned_to, task_date, 1)
      ON CONFLICT (user_id, count_date) 
      DO UPDATE SET total_tasks = user_daily_task_counts.total_tasks + 1;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update user completed task count
CREATE OR REPLACE FUNCTION increment_user_completed_task_count()
RETURNS TRIGGER AS $$
DECLARE
  task_date date;
BEGIN
  -- Extract date from due_date
  task_date := DATE(NEW.due_date);
  
  -- Only increment if task is being marked as completed or archived
  IF task_date IS NOT NULL AND NEW.status IN ('completed', 'archived') AND (OLD.status IS NULL OR OLD.status NOT IN ('completed', 'archived')) THEN
    -- Increment for primary assigned user
    IF NEW.assigned_to IS NOT NULL THEN
      UPDATE user_daily_task_counts 
      SET completed_tasks = completed_tasks + 1
      WHERE user_id = NEW.assigned_to AND count_date = task_date;
    END IF;
    
    -- Increment for secondary assigned user (if different)
    IF NEW.secondary_assigned_to IS NOT NULL AND NEW.secondary_assigned_to != NEW.assigned_to THEN
      UPDATE user_daily_task_counts 
      SET completed_tasks = completed_tasks + 1
      WHERE user_id = NEW.secondary_assigned_to AND count_date = task_date;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS user_task_creation_counter ON tasks;
DROP TRIGGER IF EXISTS user_task_completion_counter ON tasks;

-- Trigger when a task is created
CREATE TRIGGER user_task_creation_counter
  AFTER INSERT ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION increment_user_task_count();

-- Trigger when a task is updated to completed/archived
CREATE TRIGGER user_task_completion_counter
  AFTER UPDATE ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION increment_user_completed_task_count();

-- Backfill existing data for today
INSERT INTO user_daily_task_counts (user_id, count_date, total_tasks, completed_tasks)
SELECT 
  assigned_to as user_id,
  DATE(due_date) as count_date,
  COUNT(*) as total_tasks,
  COUNT(*) FILTER (WHERE status IN ('completed', 'archived')) as completed_tasks
FROM tasks
WHERE DATE(due_date) = CURRENT_DATE
  AND assigned_to IS NOT NULL
GROUP BY assigned_to, DATE(due_date)
ON CONFLICT (user_id, count_date) 
DO UPDATE SET
  total_tasks = EXCLUDED.total_tasks,
  completed_tasks = EXCLUDED.completed_tasks;
