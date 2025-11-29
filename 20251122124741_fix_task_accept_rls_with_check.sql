/*
  # Fix Task Accept - RLS WITH CHECK Policy
  
  1. Problem
    - Staff cannot accept unassigned tasks (assigned_to IS NULL)
    - WITH CHECK policy doesn't allow assigned_to IS NULL
    - When staff accepts task, WITH CHECK blocks the update
  
  2. Solution
    - Add "assigned_to IS NULL" to WITH CHECK
    - This allows staff to accept unassigned tasks
    - After update, assigned_to will be staff's ID (allowed by policy)
*/

-- Drop existing policy
DROP POLICY IF EXISTS "Users can update their created or assigned tasks or help with i" ON tasks;

-- Recreate with fixed WITH CHECK
CREATE POLICY "Users can update their tasks or accept unassigned tasks"
ON tasks
FOR UPDATE
TO authenticated
USING (
  auth.uid() = created_by 
  OR auth.uid() = assigned_to 
  OR assigned_to IS NULL 
  OR (items IS NOT NULL AND items <> '[]'::jsonb)
)
WITH CHECK (
  auth.uid() = created_by 
  OR auth.uid() = assigned_to 
  OR assigned_to IS NULL  -- CRITICAL: Allow accepting unassigned tasks
  OR (items IS NOT NULL AND items <> '[]'::jsonb)
);
