/*
  # Push Notifications System
  
  ## New Tables
  1. `push_subscriptions` - Stores web push subscription data
     - `id` (uuid, primary key)
     - `user_id` (uuid, references profiles) - User who subscribed
     - `endpoint` (text) - Push service endpoint URL
     - `p256dh` (text) - Encryption key
     - `auth` (text) - Authentication secret
     - `user_agent` (text, optional) - Device/browser info
     - `created_at` (timestamptz)
     - `updated_at` (timestamptz)
  
  2. `notification_preferences` - User notification settings
     - `user_id` (uuid, primary key, references profiles)
     - `check_in_request` (boolean) - Notify on check-in requests
     - `check_in_approved` (boolean) - Notify when check-in approved
     - `task_assigned` (boolean) - Notify on task assignment
     - `reception_note` (boolean) - Notify on reception notes
     - `all_notifications` (boolean) - Master switch
     - `created_at` (timestamptz)
     - `updated_at` (timestamptz)
  
  ## Security
  - Enable RLS on all tables
  - Users can manage their own subscriptions
  - Users can manage their own preferences
  - System can insert push notifications
*/

-- =====================================================
-- 1. CREATE TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS push_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  endpoint TEXT NOT NULL,
  p256dh TEXT NOT NULL,
  auth TEXT NOT NULL,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, endpoint)
);

CREATE TABLE IF NOT EXISTS notification_preferences (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  check_in_request BOOLEAN DEFAULT true,
  check_in_approved BOOLEAN DEFAULT true,
  check_in_rejected BOOLEAN DEFAULT true,
  task_assigned BOOLEAN DEFAULT true,
  task_approved BOOLEAN DEFAULT true,
  checklist_approved BOOLEAN DEFAULT true,
  checklist_rejected BOOLEAN DEFAULT true,
  reception_note BOOLEAN DEFAULT true,
  departure_request BOOLEAN DEFAULT true,
  all_notifications BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =====================================================
-- 2. ENABLE RLS
-- =====================================================

ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 3. RLS POLICIES
-- =====================================================

-- Push Subscriptions: Users can manage their own
CREATE POLICY "Users can view own push subscriptions"
  ON push_subscriptions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create own push subscriptions"
  ON push_subscriptions
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own push subscriptions"
  ON push_subscriptions
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Notification Preferences: Users can manage their own
CREATE POLICY "Users can view own notification preferences"
  ON notification_preferences
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own notification preferences"
  ON notification_preferences
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own notification preferences"
  ON notification_preferences
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- =====================================================
-- 4. HELPER FUNCTIONS
-- =====================================================

-- Create default notification preferences for new users
CREATE OR REPLACE FUNCTION create_default_notification_preferences()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO notification_preferences (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
END;
$$;

-- Trigger to create default preferences for new profiles
DROP TRIGGER IF EXISTS create_notification_preferences_on_profile ON profiles;

CREATE TRIGGER create_notification_preferences_on_profile
AFTER INSERT ON profiles
FOR EACH ROW
EXECUTE FUNCTION create_default_notification_preferences();

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS update_push_subscriptions_updated_at ON push_subscriptions;
DROP TRIGGER IF EXISTS update_notification_preferences_updated_at ON notification_preferences;

CREATE TRIGGER update_push_subscriptions_updated_at
BEFORE UPDATE ON push_subscriptions
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_notification_preferences_updated_at
BEFORE UPDATE ON notification_preferences
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 5. CREATE DEFAULT PREFERENCES FOR EXISTING USERS
-- =====================================================

INSERT INTO notification_preferences (user_id)
SELECT id FROM profiles
ON CONFLICT (user_id) DO NOTHING;

-- =====================================================
-- 6. GRANT PERMISSIONS
-- =====================================================

GRANT SELECT, INSERT, DELETE ON push_subscriptions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON notification_preferences TO authenticated;
