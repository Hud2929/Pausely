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
