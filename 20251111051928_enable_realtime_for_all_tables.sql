/*
  # Enable Realtime for All Important Tables

  1. Problem
    - All critical tables have realtime disabled
    - Frontend subscriptions don't receive live updates
    - Users have to manually refresh to see changes

  2. Solution
    - Enable realtime for all tables that need live updates
    - Add tables to supabase_realtime publication

  3. Tables Enabled
    - tasks: Task updates need to be instant
    - checklists: Checklist creation/updates
    - checklist_instances: Checklist completion tracking
    - schedules: Schedule changes
    - notes: Reception notes
    - check_ins: Staff check-in/out tracking
    - departure_requests: Early departure requests
    - patrol_rounds: Patrol completion tracking
    - chat_messages: Team chat messages
    - profiles: Profile updates (points, etc.)
    - notifications: Already enabled in previous migration
*/

-- Enable realtime for all critical tables
ALTER PUBLICATION supabase_realtime ADD TABLE tasks;
ALTER PUBLICATION supabase_realtime ADD TABLE checklists;
ALTER PUBLICATION supabase_realtime ADD TABLE checklist_instances;
ALTER PUBLICATION supabase_realtime ADD TABLE schedules;
ALTER PUBLICATION supabase_realtime ADD TABLE notes;
ALTER PUBLICATION supabase_realtime ADD TABLE check_ins;
ALTER PUBLICATION supabase_realtime ADD TABLE departure_requests;
ALTER PUBLICATION supabase_realtime ADD TABLE patrol_rounds;
ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE profiles;
