/*
  # Add patrol_missed category to points_history

  1. Changes
    - Update points_history category constraint to include 'patrol_missed'
    - This allows penalties for missed patrol rounds to be recorded

  2. Security
    - No RLS changes needed
*/

-- Drop the old constraint
ALTER TABLE points_history DROP CONSTRAINT IF EXISTS points_history_category_check;

-- Add new constraint with patrol_missed included
ALTER TABLE points_history ADD CONSTRAINT points_history_category_check
CHECK (category IN (
  'task_completed',
  'task_approved', 
  'task_bonus',
  'task_reopened',
  'check_in',
  'checklist_completed',
  'bonus',
  'penalty',
  'deduction',
  'adjustment',
  'patrol_completed',
  'patrol_missed',
  'patrol_late',
  'fortune_wheel'
));