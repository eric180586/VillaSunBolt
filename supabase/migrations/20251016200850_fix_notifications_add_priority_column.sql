/*
  # Fix Notifications: Add Missing Priority Column

  ## Problem
  - process_check_in function tries to INSERT with 'priority' column
  - This column doesn't exist in notifications table
  - Causes 400 error: "column 'priority' of relation 'notifications' does not exist"

  ## Solution
  - Add priority column to notifications table
  - Allow values: 'low', 'medium', 'high', 'urgent'
  - Default to 'medium'

  ## Changes
  1. Add priority column (text with CHECK constraint)
  2. No RLS changes needed (inherits from existing policies)
*/

-- Add priority column to notifications
ALTER TABLE notifications
ADD COLUMN IF NOT EXISTS priority text DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent'));