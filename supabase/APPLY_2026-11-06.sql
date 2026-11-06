-- Pausely database changes. Paste this whole file into Supabase > SQL editor > Run.
-- Safe to run more than once. Replaces APPLY_2026-10-22.sql (included below) and adds the
-- 2026-11-06 security and sync fixes. Account deletion in the app needs part 1.

-- ======================== Part 1: pending since 2026-10-22 ========================

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

-- ======================== Part 2: 2026-11-06 sweep ========================
-- Fixes from the 2026-11-06 database sweep. Safe to run more than once. Nothing the app reads is dropped.

-- ============================================================================
-- 1. Columns the app writes (some installs never ran 20261007/20261008)
-- ============================================================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'cost')
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'amount') THEN
        ALTER TABLE public.subscriptions RENAME COLUMN cost TO amount;
    END IF;
END $$;

ALTER TABLE public.subscriptions
    ADD COLUMN IF NOT EXISTS waste_score DECIMAL(5, 2),
    ADD COLUMN IF NOT EXISTS notify_before_days INTEGER,
    ADD COLUMN IF NOT EXISTS trial_ends_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS next_billing_date TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS paused_until TIMESTAMPTZ;

-- ============================================================================
-- 2. Pro can't be self-granted
-- People may edit their own profile row, but is_pro, pro_tier and pro_activated_at change only
-- through the service role (dashboard, trusted server). The app grants Pro from is_pro at sign-in.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.protect_pro_fields()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    IF coalesce(auth.role(), '') = 'service_role' OR current_user IN ('postgres', 'supabase_admin') THEN
        RETURN NEW;
    END IF;
    IF TG_OP = 'INSERT' THEN
        NEW.is_pro := false;
        NEW.pro_tier := NULL;
        NEW.pro_activated_at := NULL;
    ELSIF NEW.is_pro IS DISTINCT FROM OLD.is_pro
       OR NEW.pro_tier IS DISTINCT FROM OLD.pro_tier
       OR NEW.pro_activated_at IS DISTINCT FROM OLD.pro_activated_at THEN
        RAISE EXCEPTION 'Pro status can only be changed by Pausely' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_pro_fields ON public.profiles;
CREATE TRIGGER protect_pro_fields
    BEFORE INSERT OR UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.protect_pro_fields();

-- The older extended profile table holds premium flags too; the app never writes it.
DROP POLICY IF EXISTS "Users can update own profile extended" ON public.user_profiles;

-- ============================================================================
-- 3. Affiliate payment details are private (they were readable by anyone)
-- Only the service role (dashboard, edge functions) reads affiliates.
-- ============================================================================
DROP POLICY IF EXISTS "Authenticated users can view active affiliates" ON public.affiliates;
DROP POLICY IF EXISTS "Anyone can view affiliates" ON public.affiliates;

-- ============================================================================
-- 4. Referral codes: no public listing of codes, owners or earnings; stats are server-kept
-- ============================================================================
DROP POLICY IF EXISTS "Anyone can view referral codes for validation" ON public.referral_codes;
DROP POLICY IF EXISTS "Users can update own referral code" ON public.referral_codes;
-- The updated_at trigger on this table had no column to write, so every update failed.
ALTER TABLE public.referral_codes ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Checking a code reveals only whether it exists.
CREATE OR REPLACE FUNCTION public.referral_code_exists(p_code text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT EXISTS (SELECT 1 FROM public.referral_codes WHERE code = upper(p_code));
$$;
REVOKE ALL ON FUNCTION public.referral_code_exists(text) FROM public;
GRANT EXECUTE ON FUNCTION public.referral_code_exists(text) TO anon, authenticated;

-- The referrer could read the email of whoever used their code.
UPDATE public.referral_conversions SET referred_user_email = NULL WHERE referred_user_email IS NOT NULL;

-- ============================================================================
-- 5. Functions nobody outside should call
-- calculate_monthly_spend(uuid) ran with owner rights for ANY user id; the app doesn't use it.
-- ============================================================================
DO $$
BEGIN
    REVOKE ALL ON FUNCTION public.calculate_monthly_spend(uuid) FROM public, anon, authenticated;
EXCEPTION WHEN undefined_function THEN
    NULL;
END $$;

-- ============================================================================
-- 6. Waitlist sign-ups go through the waitlist-signup function (service role), which validates them
-- ============================================================================
DROP POLICY IF EXISTS "Public can insert waitlist" ON public.waitlist;

-- ============================================================================
-- 7. One cancel-difficulty rating per person per service (stops one account skewing the average)
-- ============================================================================
DO $$
BEGIN
    IF to_regclass('public.cancel_difficulty_ratings') IS NOT NULL THEN
        CREATE UNIQUE INDEX IF NOT EXISTS cancel_difficulty_one_per_user
            ON public.cancel_difficulty_ratings (user_id, service_name) WHERE user_id IS NOT NULL;
    END IF;
END $$;

NOTIFY pgrst, 'reload schema';
