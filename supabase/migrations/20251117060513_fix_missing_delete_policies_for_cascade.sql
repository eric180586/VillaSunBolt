/*
  # Fix missing DELETE policies that block CASCADE
  
  1. Problem
    - Tables have RLS enabled but no DELETE policies
    - This blocks CASCADE deletes when profiles are deleted
    - Specifically affects: daily_point_goals, monthly_point_goals
  
  2. Solution
    - Add DELETE policies for admins
    - This allows CASCADE to work properly
  
  3. Security
    - Only admins can delete these records
    - CASCADE will work because it runs as the deleting user
*/

-- daily_point_goals: Allow admin to delete
CREATE POLICY "Admin can delete daily_point_goals"
  ON daily_point_goals
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- monthly_point_goals: Allow admin to delete
CREATE POLICY "Admin can delete monthly_point_goals"
  ON monthly_point_goals
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- Also check time_off_requests structure
DO $$
BEGIN
  -- Add missing columns to time_off_requests if they don't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'time_off_requests' AND column_name = 'admin_response'
  ) THEN
    ALTER TABLE time_off_requests ADD COLUMN admin_response text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'time_off_requests' AND column_name = 'reviewed_at'
  ) THEN
    ALTER TABLE time_off_requests ADD COLUMN reviewed_at timestamptz;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'time_off_requests' AND column_name = 'reviewed_by'
  ) THEN
    ALTER TABLE time_off_requests ADD COLUMN reviewed_by uuid REFERENCES profiles(id) ON DELETE SET NULL;
  END IF;
END $$;
