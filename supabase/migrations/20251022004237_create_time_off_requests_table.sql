/*
  # Create Time Off Requests Table

  ## New Tables:
  - `time_off_requests`
    - `id` (uuid, primary key)
    - `staff_id` (uuid, references profiles)
    - `request_date` (date) - The date they want off
    - `reason` (text) - Why they need time off
    - `status` (text) - pending, approved, rejected
    - `admin_response` (text) - Admin's response/notes
    - `reviewed_by` (uuid, references profiles)
    - `reviewed_at` (timestamptz)
    - `created_at` (timestamptz)

  ## Security:
  - Enable RLS
  - Staff can create their own requests
  - Staff can view their own requests
  - Admin can view all requests
  - Admin can update requests (approve/reject)
*/

CREATE TABLE IF NOT EXISTS time_off_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  request_date date NOT NULL,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_response text,
  reviewed_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE time_off_requests ENABLE ROW LEVEL SECURITY;

-- Staff can create their own requests
CREATE POLICY "Staff can create time off requests"
  ON time_off_requests FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = staff_id
    AND (SELECT role FROM profiles WHERE id = auth.uid()) = 'staff'
  );

-- Staff can view their own requests
CREATE POLICY "Staff can view own requests"
  ON time_off_requests FOR SELECT
  TO authenticated
  USING (
    auth.uid() = staff_id
    OR (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  );

-- Admin can view all requests
CREATE POLICY "Admin can view all requests"
  ON time_off_requests FOR SELECT
  TO authenticated
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  );

-- Admin can update requests (approve/reject)
CREATE POLICY "Admin can update requests"
  ON time_off_requests FOR UPDATE
  TO authenticated
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  )
  WITH CHECK (
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  );

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_time_off_requests_staff_id ON time_off_requests(staff_id);
CREATE INDEX IF NOT EXISTS idx_time_off_requests_status ON time_off_requests(status);
CREATE INDEX IF NOT EXISTS idx_time_off_requests_date ON time_off_requests(request_date);

COMMENT ON TABLE time_off_requests IS 
'Staff requests for time off, reviewed and approved by admin';
