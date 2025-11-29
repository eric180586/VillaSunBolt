/*
  # Remove Unused approve_task Functions
  
  1. Changes
    - Keep: approve_task_with_quality (used by Tasks.tsx)
    - Keep: approve_task_with_items (used by TaskReviewModal.tsx)
    - Remove: approve_task (unused main version)
    - Remove: approve_task_with_points (unused)
*/

-- Remove unused versions
DROP FUNCTION IF EXISTS approve_task(uuid, text, jsonb, text);
DROP FUNCTION IF EXISTS approve_task_with_points(uuid, uuid);
