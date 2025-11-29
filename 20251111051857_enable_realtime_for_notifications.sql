/*
  # Enable Realtime for Notifications Table

  1. Problem
    - notifications table is not in realtime publication
    - Frontend realtime subscriptions don't receive updates
    - Users don't see notifications in real-time

  2. Solution
    - Add notifications table to supabase_realtime publication
    - Enable all operations (INSERT, UPDATE, DELETE)

  3. Changes
    - Enable realtime for notifications table
*/

-- Enable realtime for notifications table
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
