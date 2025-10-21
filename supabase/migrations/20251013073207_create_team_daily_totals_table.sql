/*
  # Create Separate Table for Team Daily Totals
  
  1. New Table
    - `team_daily_totals` to store team-wide task counts
    - Separate from user-specific daily_point_goals
  
  2. Purpose
    - Track total tasks and completed tasks at team level
    - Used for Admin Dashboard "Aufgaben Gesamt"
    - Used for Staff Dashboard "Today's Tasks" (team view)
*/

-- Create table for team daily totals
CREATE TABLE IF NOT EXISTS team_daily_totals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  date date NOT NULL UNIQUE,
  total_tasks integer DEFAULT 0,
  completed_tasks integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE team_daily_totals ENABLE ROW LEVEL SECURITY;

-- RLS Policies - everyone can read
CREATE POLICY "Everyone can view team totals"
  ON team_daily_totals FOR SELECT
  TO authenticated
  USING (true);

-- Only system can modify (via triggers)
CREATE POLICY "System can modify team totals"
  ON team_daily_totals FOR ALL
  USING (false)
  WITH CHECK (false);

-- Recreate the trigger functions to use the new table
CREATE OR REPLACE FUNCTION increment_daily_task_count()
RETURNS TRIGGER AS $$
DECLARE
  task_date date;
BEGIN
  task_date := DATE(NEW.due_date);
  
  IF task_date IS NOT NULL THEN
    INSERT INTO team_daily_totals (date, total_tasks)
    VALUES (task_date, 1)
    ON CONFLICT (date) 
    DO UPDATE SET 
      total_tasks = team_daily_totals.total_tasks + 1,
      updated_at = now();
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update completed task count
CREATE OR REPLACE FUNCTION increment_completed_task_count()
RETURNS TRIGGER AS $$
DECLARE
  task_date date;
BEGIN
  task_date := DATE(NEW.due_date);
  
  IF task_date IS NOT NULL AND NEW.status IN ('completed', 'archived') AND (OLD.status IS NULL OR OLD.status NOT IN ('completed', 'archived')) THEN
    INSERT INTO team_daily_totals (date, completed_tasks)
    VALUES (task_date, 1)
    ON CONFLICT (date)
    DO UPDATE SET 
      completed_tasks = team_daily_totals.completed_tasks + 1,
      updated_at = now();
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Backfill today's data
INSERT INTO team_daily_totals (date, total_tasks, completed_tasks)
SELECT 
  CURRENT_DATE,
  COUNT(*),
  COUNT(*) FILTER (WHERE status IN ('completed', 'archived'))
FROM tasks
WHERE DATE(due_date) = CURRENT_DATE
ON CONFLICT (date) 
DO UPDATE SET
  total_tasks = EXCLUDED.total_tasks,
  completed_tasks = EXCLUDED.completed_tasks,
  updated_at = now();
