/*
  # Fix Staff Schedule Visibility

  ## Changes
  - Update RLS policy on weekly_schedules to allow ALL staff to view ALL schedules
  - Staff should be able to see each other's schedules for coordination
  - Only admins can still edit schedules

  ## Security
  - All authenticated staff users can view all weekly schedules
  - Only admins can create, update, or delete schedules
*/

-- Drop the old restrictive policy
DROP POLICY IF EXISTS "Users can view own schedules or admins view all" ON weekly_schedules;

-- Create new policy that allows all authenticated users to view all schedules
CREATE POLICY "All authenticated users can view all schedules"
  ON weekly_schedules FOR SELECT
  TO authenticated
  USING (true);
