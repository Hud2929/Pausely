-- The app saves these three fields, but no earlier migration created them,
-- so every cloud save fails with PGRST204. Safe to run more than once.

ALTER TABLE public.subscriptions
    ADD COLUMN IF NOT EXISTS waste_score DECIMAL(5, 2),
    ADD COLUMN IF NOT EXISTS notify_before_days INTEGER,
    ADD COLUMN IF NOT EXISTS trial_ends_at TIMESTAMPTZ;

NOTIFY pgrst, 'reload schema';
