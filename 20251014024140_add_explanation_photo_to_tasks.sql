/*
  # Add explanation_photo to tasks table

  1. Changes
    - Add `explanation_photo` column to `tasks` table to store example photo URL
    - This allows admins to upload an example photo showing what the task photo should look like
    
  2. Security
    - No RLS changes needed, follows existing tasks table security
*/

-- Add explanation_photo column to tasks
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS explanation_photo text;
