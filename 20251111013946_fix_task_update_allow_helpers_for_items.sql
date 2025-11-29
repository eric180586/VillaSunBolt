/*
  # Allow staff to update tasks with items (for "Me Help" feature)

  Staff should be able to update task items even if they are not assigned_to.
  This enables the "Me Help" feature where any staff can contribute to tasks with items.
*/

DROP POLICY IF EXISTS "Users can update their created or assigned tasks" ON tasks;

CREATE POLICY "Users can update their created or assigned tasks or help with items"
  ON tasks
  FOR UPDATE
  TO authenticated
  USING (
    -- Creator can always update
    auth.uid() = created_by 
    OR 
    -- Assigned person can update
    auth.uid() = assigned_to 
    OR 
    -- Unassigned tasks
    assigned_to IS NULL
    OR
    -- ANY staff can update tasks with items (for "Me Help")
    (items IS NOT NULL AND items != '[]'::jsonb)
  )
  WITH CHECK (
    -- Creator can always update
    auth.uid() = created_by 
    OR 
    -- Assigned person can update
    auth.uid() = assigned_to
    OR
    -- ANY staff can update tasks with items (for "Me Help")
    (items IS NOT NULL AND items != '[]'::jsonb)
  );
