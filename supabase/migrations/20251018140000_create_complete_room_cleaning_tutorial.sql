/*
  # Complete Room Cleaning Tutorial System

  ## Features:
  - 6 Steps with Sunny's introduction, explanation, and summary
  - Multiple game types (drag-drop, search, order, quiz, error-finding)
  - Question pool system (random selection like board game)
  - Individual progress tracking with best scores
  - Repeatable steps
  - Multi-language support

  ## Tables:
  1. room_cleaning_steps - Main tutorial steps
  2. step_explanations - Sunny's dialogues (intro, why, summary)
  3. step_tasks - Interactive games per step
  4. step_task_items - Items/questions for each task
  5. user_step_progress - User progress with best scores
  6. quiz_question_pool - Question pool for random selection
  7. user_quiz_sessions - Track which questions users saw
*/

-- ============================================================================
-- 1. ROOM CLEANING STEPS
-- ============================================================================
CREATE TABLE IF NOT EXISTS room_cleaning_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  step_number integer NOT NULL UNIQUE CHECK (step_number BETWEEN 1 AND 6),
  title text NOT NULL,
  description text NOT NULL,
  sunny_introduction text NOT NULL,
  sunny_why_important text NOT NULL,
  sunny_summary text NOT NULL,
  sunny_position text DEFAULT 'left' CHECK (sunny_position IN ('left', 'right', 'center')),
  game_type text NOT NULL CHECK (game_type IN ('drag_drop', 'search_image', 'order_steps', 'multiple_choice', 'checklist', 'error_finding')),
  background_image text,
  min_score_to_pass integer DEFAULT 70,
  max_possible_score integer DEFAULT 100,
  estimated_minutes integer DEFAULT 5,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_room_cleaning_steps_number ON room_cleaning_steps(step_number);

-- ============================================================================
-- 2. STEP TASKS (Interactive games configuration)
-- ============================================================================
CREATE TABLE IF NOT EXISTS step_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  step_id uuid NOT NULL REFERENCES room_cleaning_steps(id) ON DELETE CASCADE,
  task_instruction text NOT NULL,
  task_config jsonb DEFAULT '{}',
  background_image text,
  min_correct_items integer DEFAULT 1,
  points_per_correct integer DEFAULT 10,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_step_tasks_step ON step_tasks(step_id);

-- ============================================================================
-- 3. STEP TASK ITEMS (Items for each game)
-- ============================================================================
CREATE TABLE IF NOT EXISTS step_task_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL REFERENCES step_tasks(id) ON DELETE CASCADE,
  item_name text NOT NULL,
  item_type text NOT NULL CHECK (item_type IN ('draggable', 'drop_target', 'clickable', 'orderable', 'choice')),
  item_data jsonb DEFAULT '{}',
  correct_answer text,
  position_data jsonb,
  feedback_correct text,
  feedback_incorrect text,
  points integer DEFAULT 10,
  order_index integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_step_task_items_task ON step_task_items(task_id);
CREATE INDEX IF NOT EXISTS idx_step_task_items_order ON step_task_items(task_id, order_index);

-- ============================================================================
-- 4. USER STEP PROGRESS (with best scores and repeatability)
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_step_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  step_id uuid NOT NULL REFERENCES room_cleaning_steps(id) ON DELETE CASCADE,
  completed boolean DEFAULT false,
  current_score integer DEFAULT 0,
  best_score integer DEFAULT 0,
  attempts integer DEFAULT 0,
  time_spent_seconds integer DEFAULT 0,
  last_attempt_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, step_id)
);

CREATE INDEX IF NOT EXISTS idx_user_step_progress_user ON user_step_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_user_step_progress_step ON user_step_progress(step_id);

-- ============================================================================
-- 5. QUIZ QUESTION POOL (for random selection)
-- ============================================================================
CREATE TABLE IF NOT EXISTS quiz_question_pool (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  step_id uuid REFERENCES room_cleaning_steps(id) ON DELETE CASCADE,
  category text NOT NULL,
  question_text text NOT NULL,
  question_type text DEFAULT 'multiple_choice' CHECK (question_type IN ('multiple_choice', 'true_false', 'ordering')),
  difficulty text DEFAULT 'medium' CHECK (difficulty IN ('easy', 'medium', 'hard')),
  correct_answer text NOT NULL,
  options jsonb DEFAULT '[]',
  explanation text,
  points integer DEFAULT 10,
  times_shown integer DEFAULT 0,
  times_correct integer DEFAULT 0,
  times_incorrect integer DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_quiz_questions_step ON quiz_question_pool(step_id);
CREATE INDEX IF NOT EXISTS idx_quiz_questions_category ON quiz_question_pool(category);
CREATE INDEX IF NOT EXISTS idx_quiz_questions_active ON quiz_question_pool(is_active);

-- ============================================================================
-- 6. USER QUIZ SESSIONS (track which questions users saw)
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_quiz_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  step_id uuid REFERENCES room_cleaning_steps(id) ON DELETE CASCADE,
  session_type text DEFAULT 'step_quiz' CHECK (session_type IN ('step_quiz', 'final_quiz')),
  questions_shown jsonb DEFAULT '[]',
  answers_given jsonb DEFAULT '[]',
  total_questions integer NOT NULL,
  correct_answers integer DEFAULT 0,
  score integer DEFAULT 0,
  time_spent_seconds integer DEFAULT 0,
  completed_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_quiz_sessions_user ON user_quiz_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_quiz_sessions_step ON user_quiz_sessions(step_id);

-- ============================================================================
-- 7. ENABLE RLS
-- ============================================================================
ALTER TABLE room_cleaning_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE step_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE step_task_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_step_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_question_pool ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_quiz_sessions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 8. RLS POLICIES - TUTORIAL CONTENT (Everyone can read)
-- ============================================================================

CREATE POLICY "Anyone can view room cleaning steps"
  ON room_cleaning_steps FOR SELECT USING (true);

CREATE POLICY "Anyone can view step tasks"
  ON step_tasks FOR SELECT USING (true);

CREATE POLICY "Anyone can view step task items"
  ON step_task_items FOR SELECT USING (true);

CREATE POLICY "Anyone can view quiz questions"
  ON quiz_question_pool FOR SELECT USING (is_active = true);

-- ============================================================================
-- 9. RLS POLICIES - ADMIN MANAGEMENT
-- ============================================================================

CREATE POLICY "Admins can manage room cleaning steps"
  ON room_cleaning_steps FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can manage step tasks"
  ON step_tasks FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can manage step task items"
  ON step_task_items FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can manage quiz questions"
  ON quiz_question_pool FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

-- ============================================================================
-- 10. RLS POLICIES - USER PROGRESS (Own data only)
-- ============================================================================

CREATE POLICY "Users can view own step progress"
  ON user_step_progress FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own step progress"
  ON user_step_progress FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own step progress"
  ON user_step_progress FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can view own quiz sessions"
  ON user_quiz_sessions FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own quiz sessions"
  ON user_quiz_sessions FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admins can view all progress"
  ON user_step_progress FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can view all quiz sessions"
  ON user_quiz_sessions FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

-- ============================================================================
-- 11. HELPER FUNCTIONS
-- ============================================================================

-- Function to get user's tutorial completion summary
CREATE OR REPLACE FUNCTION get_user_tutorial_summary(p_user_id uuid)
RETURNS TABLE (
  total_steps integer,
  completed_steps integer,
  total_score integer,
  best_total_score integer,
  completion_percentage numeric,
  average_score numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::integer FROM room_cleaning_steps) as total_steps,
    (SELECT COUNT(*)::integer FROM user_step_progress WHERE user_id = p_user_id AND completed = true) as completed_steps,
    COALESCE((SELECT SUM(current_score)::integer FROM user_step_progress WHERE user_id = p_user_id), 0) as total_score,
    COALESCE((SELECT SUM(best_score)::integer FROM user_step_progress WHERE user_id = p_user_id), 0) as best_total_score,
    ROUND(
      (SELECT COUNT(*)::numeric FROM user_step_progress WHERE user_id = p_user_id AND completed = true) * 100.0 /
      NULLIF((SELECT COUNT(*) FROM room_cleaning_steps), 0),
      2
    ) as completion_percentage,
    ROUND(
      COALESCE((SELECT AVG(best_score) FROM user_step_progress WHERE user_id = p_user_id AND completed = true), 0),
      2
    ) as average_score;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get random quiz questions
CREATE OR REPLACE FUNCTION get_random_quiz_questions(
  p_step_id uuid,
  p_count integer,
  p_user_id uuid
)
RETURNS TABLE (
  id uuid,
  question_text text,
  question_type text,
  difficulty text,
  correct_answer text,
  options jsonb,
  explanation text,
  points integer
) AS $$
BEGIN
  RETURN QUERY
  WITH user_recent_questions AS (
    SELECT unnest((questions_shown)::uuid[]) as question_id
    FROM user_quiz_sessions
    WHERE user_id = p_user_id
      AND (step_id = p_step_id OR (step_id IS NULL AND p_step_id IS NULL))
    ORDER BY created_at DESC
    LIMIT 3
  )
  SELECT
    q.id,
    q.question_text,
    q.question_type,
    q.difficulty,
    q.correct_answer,
    q.options,
    q.explanation,
    q.points
  FROM quiz_question_pool q
  WHERE
    (q.step_id = p_step_id OR (q.step_id IS NULL AND p_step_id IS NULL))
    AND q.is_active = true
    AND q.id NOT IN (SELECT question_id FROM user_recent_questions)
  ORDER BY
    q.times_shown ASC,
    RANDOM()
  LIMIT p_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update question statistics
CREATE OR REPLACE FUNCTION update_question_stats(
  p_question_id uuid,
  p_was_correct boolean
)
RETURNS void AS $$
BEGIN
  UPDATE quiz_question_pool
  SET
    times_shown = times_shown + 1,
    times_correct = times_correct + CASE WHEN p_was_correct THEN 1 ELSE 0 END,
    times_incorrect = times_incorrect + CASE WHEN p_was_correct THEN 0 ELSE 1 END
  WHERE id = p_question_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
