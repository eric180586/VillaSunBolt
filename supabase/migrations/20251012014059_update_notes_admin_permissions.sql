/*
  # Update Notes Permissions for Admins
  
  1. Changes
    - Drop existing delete and update policies for notes
    - Create new policies allowing admins to delete/update any note
    - Keep user permission to delete/update their own notes
  
  2. Security
    - Admins can manage all notes
    - Users can only manage their own notes
*/

DROP POLICY IF EXISTS "Users can delete their notes" ON notes;
DROP POLICY IF EXISTS "Users can update their notes" ON notes;

CREATE POLICY "Users and admins can delete notes"
  ON notes
  FOR DELETE
  TO authenticated
  USING (
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Users and admins can update notes"
  ON notes
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );
