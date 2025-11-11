/*
  # Fix Points History Category Constraint
  
  1. Changes
    - Add 'task_reopened' to allowed categories in points_history table
    - This is needed for the reopen_task_with_penalty function to work
  
  2. Security
    - Maintains existing RLS policies
*/

-- Drop existing constraint
ALTER TABLE points_history DROP CONSTRAINT IF EXISTS points_history_category_check;

-- Add new constraint with task_reopened included
ALTER TABLE points_history ADD CONSTRAINT points_history_category_check
  CHECK (category IN ('task_completed', 'bonus', 'deduction', 'achievement', 'other', 'task_reopened', 'check_in', 'patrol', 'checklist'));
