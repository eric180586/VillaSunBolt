/*
  # Add Departure Requests and Notification Read Receipts

  ## New Tables
  
  1. `departure_requests`
    - `id` (uuid, primary key) - Unique identifier
    - `user_id` (uuid, foreign key) - Staff member requesting departure
    - `shift_date` (date) - Date of the shift
    - `shift_type` (text) - Type of shift (früh or spät)
    - `request_time` (timestamptz) - When the request was made
    - `status` (text) - pending, approved, rejected
    - `admin_id` (uuid, foreign key) - Admin who processed the request
    - `admin_notes` (text, nullable) - Optional notes from admin
    - `processed_at` (timestamptz, nullable) - When admin processed the request
    - `created_at` (timestamptz) - Record creation timestamp
    - `updated_at` (timestamptz) - Record update timestamp

  2. `notification_read_receipts`
    - `id` (uuid, primary key) - Unique identifier
    - `notification_id` (uuid, foreign key) - Reference to notification
    - `user_id` (uuid, foreign key) - User who read the notification
    - `read_at` (timestamptz) - When the notification was read
    - `created_at` (timestamptz) - Record creation timestamp

  ## Security
  
  - Enable RLS on both tables
  - Users can view their own departure requests
  - Users can create their own departure requests
  - Admins can view and update all departure requests
  - Users can create and view their own read receipts
  - Admins can view all read receipts for notifications they created
*/

-- Create departure_requests table
CREATE TABLE IF NOT EXISTS departure_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  shift_date date NOT NULL,
  shift_type text NOT NULL CHECK (shift_type IN ('früh', 'spät')),
  request_time timestamptz DEFAULT now() NOT NULL,
  status text DEFAULT 'pending' NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  admin_notes text,
  processed_at timestamptz,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Create notification_read_receipts table
CREATE TABLE IF NOT EXISTS notification_read_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id uuid REFERENCES notifications(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  read_at timestamptz DEFAULT now() NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(notification_id, user_id)
);

-- Enable RLS
ALTER TABLE departure_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_read_receipts ENABLE ROW LEVEL SECURITY;

-- Policies for departure_requests

-- Users can view their own departure requests
CREATE POLICY "Users can view own departure requests"
  ON departure_requests
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Admins can view all departure requests
CREATE POLICY "Admins can view all departure requests"
  ON departure_requests
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Users can create their own departure requests
CREATE POLICY "Users can create own departure requests"
  ON departure_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Admins can update all departure requests
CREATE POLICY "Admins can update departure requests"
  ON departure_requests
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Users can delete their own pending departure requests
CREATE POLICY "Users can delete own pending departure requests"
  ON departure_requests
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id AND status = 'pending');

-- Policies for notification_read_receipts

-- Users can view read receipts for notifications they received
CREATE POLICY "Users can view read receipts for their notifications"
  ON notification_read_receipts
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM notifications
      WHERE notifications.id = notification_read_receipts.notification_id
      AND notifications.user_id = auth.uid()
    )
  );

-- Admins can view all read receipts for notifications they created
CREATE POLICY "Admins can view read receipts for their sent notifications"
  ON notification_read_receipts
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Users can create read receipts when they read notifications
CREATE POLICY "Users can create read receipts for their notifications"
  ON notification_read_receipts
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_departure_requests_user_id ON departure_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_departure_requests_status ON departure_requests(status);
CREATE INDEX IF NOT EXISTS idx_departure_requests_shift_date ON departure_requests(shift_date);
CREATE INDEX IF NOT EXISTS idx_notification_read_receipts_notification_id ON notification_read_receipts(notification_id);
CREATE INDEX IF NOT EXISTS idx_notification_read_receipts_user_id ON notification_read_receipts(user_id);

-- Create updated_at trigger for departure_requests
CREATE OR REPLACE FUNCTION update_departure_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER departure_requests_updated_at
  BEFORE UPDATE ON departure_requests
  FOR EACH ROW
  EXECUTE FUNCTION update_departure_requests_updated_at();