/*
  # Create Fortune Wheel Gamification System

  1. New Tables
    - `fortune_wheel_spins`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references profiles)
      - `check_in_id` (uuid, references check_ins)
      - `spin_date` (date)
      - `reward_type` (text) - 'bonus_points', 'multiplier_2x', 'early_leave_30min', 'task_joker', 'lucky_badge'
      - `reward_value` (integer) - points amount or multiplier value
      - `reward_label` (text) - display text
      - `created_at` (timestamptz)
      
  2. Security
    - Enable RLS on fortune_wheel_spins
    - Users can view their own spins
    - Users can insert their own spins (once per day)
    - Admins can view all spins

  3. Constraints
    - One spin per user per day
    - Must be linked to a check_in
*/

CREATE TABLE IF NOT EXISTS fortune_wheel_spins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  check_in_id uuid REFERENCES check_ins(id) ON DELETE CASCADE NOT NULL,
  spin_date date DEFAULT CURRENT_DATE NOT NULL,
  reward_type text NOT NULL CHECK (reward_type IN ('bonus_points', 'multiplier_2x', 'early_leave_30min', 'task_joker', 'lucky_badge')),
  reward_value integer NOT NULL DEFAULT 0,
  reward_label text NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE(user_id, spin_date)
);

ALTER TABLE fortune_wheel_spins ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own fortune wheel spins"
  ON fortune_wheel_spins FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own fortune wheel spins"
  ON fortune_wheel_spins FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id 
    AND NOT EXISTS (
      SELECT 1 FROM fortune_wheel_spins 
      WHERE user_id = auth.uid() 
      AND spin_date = CURRENT_DATE
    )
  );

CREATE POLICY "Admins can view all fortune wheel spins"
  ON fortune_wheel_spins FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'admin'
    )
  );

CREATE INDEX IF NOT EXISTS idx_fortune_wheel_spins_user_date 
  ON fortune_wheel_spins(user_id, spin_date);

CREATE INDEX IF NOT EXISTS idx_fortune_wheel_spins_check_in 
  ON fortune_wheel_spins(check_in_id);
