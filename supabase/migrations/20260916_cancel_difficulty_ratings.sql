-- Cancel Difficulty Ratings
-- Stores how hard it was to cancel each service. Applied 2026-10-22 (it had never been applied).
-- Privacy: individual rows are not readable by clients (they would reveal who cancelled what);
-- apps read only the anonymous per-service averages through the view. Signed-in users can add
-- ratings under their own id only. Idempotent.

CREATE TABLE IF NOT EXISTS public.cancel_difficulty_ratings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_name text NOT NULL CHECK (char_length(service_name) BETWEEN 1 AND 120),
  difficulty_rating integer NOT NULL CHECK (difficulty_rating BETWEEN 1 AND 5),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.cancel_difficulty_ratings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can insert difficulty ratings" ON public.cancel_difficulty_ratings;
DROP POLICY IF EXISTS "Anyone can read difficulty ratings" ON public.cancel_difficulty_ratings;
DROP POLICY IF EXISTS "Users add their own ratings" ON public.cancel_difficulty_ratings;

CREATE POLICY "Users add their own ratings"
  ON public.cancel_difficulty_ratings FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Per-service aggregates only (the view runs with its owner's rights, so it can read the table).
CREATE OR REPLACE VIEW public.service_difficulty_scores AS
SELECT
  service_name,
  ROUND(AVG(difficulty_rating)::numeric, 1) AS avg_difficulty,
  COUNT(*) AS rating_count
FROM public.cancel_difficulty_ratings
GROUP BY service_name;

GRANT SELECT ON public.service_difficulty_scores TO anon, authenticated;
