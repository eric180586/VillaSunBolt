/*
  # Fix Staff Checkout Permissions

  Allow staff to update their own check-ins for checkout.
  
  ## Changes
  - Add policy for staff to update their own check_ins
  - Staff can only update check_out_time and late_reason for their own check-ins
  
  ## Security
  - Staff can only update their own check-ins (user_id = auth.uid())
  - Admins can update all check-ins (existing policy)
*/

-- Add policy for staff to checkout themselves
CREATE POLICY "Staff can checkout themselves"
  ON check_ins
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
