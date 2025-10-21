/*
  # Create Check-In System

  1. New Tables
    - `check_ins`
      - `id` (uuid, primary key)
      - `user_id` (uuid) - Staff member checking in
      - `check_in_time` (timestamptz) - When they checked in
      - `shift_type` (text) - 'früh' or 'spät'
      - `is_late` (boolean) - Whether they were late
      - `minutes_late` (integer) - How many minutes late
      - `points_awarded` (integer) - Points given (5 for on time, reduced for late)
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on `check_ins` table
    - Users can create their own check-ins
    - Everyone can view all check-ins
*/

CREATE TABLE IF NOT EXISTS check_ins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  check_in_time timestamptz DEFAULT now() NOT NULL,
  shift_type text NOT NULL,
  is_late boolean DEFAULT false,
  minutes_late integer DEFAULT 0,
  points_awarded integer DEFAULT 5,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_check_ins_user_id ON check_ins(user_id);
CREATE INDEX IF NOT EXISTS idx_check_ins_date ON check_ins(check_in_time);

ALTER TABLE check_ins ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all check-ins"
  ON check_ins
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can create own check-ins"
  ON check_ins
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can delete check-ins"
  ON check_ins
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Function to calculate punctuality points and award them
CREATE OR REPLACE FUNCTION process_check_in(
  p_user_id uuid,
  p_shift_type text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_check_in_time timestamptz;
  v_shift_start_time time;
  v_minutes_late integer := 0;
  v_is_late boolean := false;
  v_points integer := 5;
  v_check_in_id uuid;
  v_reason text;
BEGIN
  v_check_in_time := now();
  
  -- Determine shift start time (9:00 for früh, 15:00 for spät)
  IF p_shift_type = 'früh' THEN
    v_shift_start_time := '09:00:00'::time;
  ELSE
    v_shift_start_time := '15:00:00'::time;
  END IF;
  
  -- Calculate if late and by how much
  IF v_check_in_time::time > v_shift_start_time THEN
    v_is_late := true;
    v_minutes_late := EXTRACT(EPOCH FROM (v_check_in_time::time - v_shift_start_time)) / 60;
    
    -- Deduct 1 point per full 5 minutes late
    v_points := 5 - (v_minutes_late / 5)::integer;
    
    -- Minimum 0 points
    IF v_points < 0 THEN
      v_points := 0;
    END IF;
  END IF;
  
  -- Create check-in record
  INSERT INTO check_ins (user_id, check_in_time, shift_type, is_late, minutes_late, points_awarded)
  VALUES (p_user_id, v_check_in_time, p_shift_type, v_is_late, v_minutes_late, v_points)
  RETURNING id INTO v_check_in_id;
  
  -- Award points if positive
  IF v_points > 0 THEN
    v_reason := 'Pünktliches Einchecken - ' || p_shift_type || 'schicht';
    
    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (p_user_id, v_points, v_reason, 'punctuality', p_user_id);
  ELSIF v_points < 0 THEN
    v_reason := 'Verspätetes Einchecken (' || v_minutes_late || ' Min.) - ' || p_shift_type || 'schicht';
    
    INSERT INTO points_history (user_id, points_change, reason, category, created_by)
    VALUES (p_user_id, v_points, v_reason, 'penalty', p_user_id);
  END IF;
  
  RETURN jsonb_build_object(
    'check_in_id', v_check_in_id,
    'is_late', v_is_late,
    'minutes_late', v_minutes_late,
    'points_awarded', v_points
  );
END;
$$;