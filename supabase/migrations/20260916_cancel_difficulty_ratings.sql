-- Cancel Difficulty Ratings
-- Stores user-submitted ratings for how hard it was to cancel each service

CREATE TABLE IF NOT EXISTS cancel_difficulty_ratings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_name text NOT NULL,
  difficulty_rating integer NOT NULL CHECK (difficulty_rating BETWEEN 1 AND 5),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE cancel_difficulty_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can insert difficulty ratings"
  ON cancel_difficulty_ratings FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Anyone can read difficulty ratings"
  ON cancel_difficulty_ratings FOR SELECT
  USING (true);

-- View for per-service aggregate scores
CREATE OR REPLACE VIEW service_difficulty_scores AS
SELECT
  service_name,
  ROUND(AVG(difficulty_rating)::numeric, 1) AS avg_difficulty,
  COUNT(*) AS rating_count
FROM cancel_difficulty_ratings
GROUP BY service_name;
