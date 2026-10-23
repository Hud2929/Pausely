-- Pausely database changes, 2026-10-22. Paste this whole file into Supabase > SQL editor > Run.
-- Safe to run more than once. Adds: secure cancel-difficulty ratings, the deletion audit table,
-- user_settings, and delete_my_account() which in-app Delete Account needs.
-- Nothing is dropped. (20261020_drop_smart_pause_alerts is not needed: that table doesn't exist live.)

-- ===== 20260916_cancel_difficulty_ratings.sql =====
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

-- ===== 20260917_gdpr_deletion_requests.sql =====
-- GDPR / CCPA Data Deletion Audit Trail
-- Records deletion requests for compliance — required by GDPR Art. 17 to demonstrate
-- that deletion was actioned within 30 days.

CREATE TABLE IF NOT EXISTS deletion_requests (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  email         text,                                    -- stored in case user_id is deleted first
  requested_at  timestamptz NOT NULL DEFAULT now(),
  source        text NOT NULL DEFAULT 'in_app'           -- 'in_app' | 'web_form' | 'email'
                CHECK (source IN ('in_app', 'web_form', 'email')),
  completed_at  timestamptz,
  notes         text
);

-- Only service-role can read deletion requests (admin use only)
ALTER TABLE deletion_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "No public access to deletion_requests" ON deletion_requests;
CREATE POLICY "No public access to deletion_requests"
  ON deletion_requests FOR ALL
  USING (false);

-- Index for compliance queries
CREATE INDEX IF NOT EXISTS idx_deletion_requests_requested_at ON deletion_requests (requested_at);
CREATE INDEX IF NOT EXISTS idx_deletion_requests_user_id ON deletion_requests (user_id);

-- ===== 20261022a_user_settings.sql =====
-- Per-user app settings stored on the server. The app reads and writes referral_discount_used.
-- It was referenced by the app but never created. Idempotent.

CREATE TABLE IF NOT EXISTS public.user_settings (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  referral_discount_used boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage their own settings" ON public.user_settings;
CREATE POLICY "Users manage their own settings"
  ON public.user_settings FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ===== 20261022b_delete_my_account.sql =====
-- In-app account deletion (App Store guideline 5.1.1(v), GDPR Art. 17).
-- The app calls rpc('delete_my_account'). It deletes the signed-in user from auth.users, which
-- cascades to profiles, subscriptions, usage, tracked trials, referrals and devices. Anonymous
-- aggregates (cancel_difficulty_ratings) keep their rows with user_id set to NULL.
-- Idempotent: safe to run more than once.

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;

  -- Audit trail required to show the deletion was actioned. No email is kept.
  insert into public.deletion_requests (user_id, source, completed_at, notes)
  values (uid, 'in_app', now(), 'Deleted from the app');

  -- Tables created outside these migrations may not cascade from auth.users.
  if to_regclass('public.user_settings') is not null then
    execute 'delete from public.user_settings where user_id = $1' using uid;
  end if;

  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public;
revoke all on function public.delete_my_account() from anon;
grant execute on function public.delete_my_account() to authenticated;
