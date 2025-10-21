/*
  # Add Quiz Highscores Table

  1. New Table
    - `quiz_highscores`
      - `id` (uuid, primary key)
      - `profile_id` (uuid, foreign key, unique)
      - `games_played` (integer, default 0)
      - `games_won` (integer, default 0)
      - `total_points` (integer, default 0)
      - `best_score` (integer, default 0)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS
    - Anyone can view highscores
    - Users can manage their own highscore records
*/

CREATE TABLE IF NOT EXISTS quiz_highscores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  games_played integer DEFAULT 0,
  games_won integer DEFAULT 0,
  total_points integer DEFAULT 0,
  best_score integer DEFAULT 0,
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE quiz_highscores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view highscores"
  ON quiz_highscores FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can insert their own highscores"
  ON quiz_highscores FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = profile_id);

CREATE POLICY "Users can update their own highscores"
  ON quiz_highscores FOR UPDATE
  TO authenticated
  USING (auth.uid() = profile_id)
  WITH CHECK (auth.uid() = profile_id);
