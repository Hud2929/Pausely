-- Pausely database changes. Paste this whole file into Supabase > SQL editor > Run.
-- Safe to run more than once. Replaces APPLY_2026-11-06.sql: everything that file did is included.
-- It runs as one transaction: if any statement fails, nothing is changed.
-- The result shown at the end is a checklist. Every line should say "ok".
-- Proven on a local copy of the schema by scripts/dbtest/run.sh.

BEGIN;

-- ======================== Part 1: pending since 2026-10-22 ========================

-- ===== Cancel-difficulty ratings (20260916) =====
-- Individual rows are not readable by the app (they would show who cancelled what); the app reads
-- only the per-service averages through the view. Signed-in people add ratings under their own id.
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

CREATE OR REPLACE VIEW public.service_difficulty_scores AS
SELECT
  service_name,
  ROUND(AVG(difficulty_rating)::numeric, 1) AS avg_difficulty,
  COUNT(*) AS rating_count
FROM public.cancel_difficulty_ratings
GROUP BY service_name;

GRANT SELECT ON public.service_difficulty_scores TO anon, authenticated;

-- ===== Deletion audit trail (20260917) =====
CREATE TABLE IF NOT EXISTS public.deletion_requests (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  email         text,
  requested_at  timestamptz NOT NULL DEFAULT now(),
  source        text NOT NULL DEFAULT 'in_app'
                CHECK (source IN ('in_app', 'web_form', 'email')),
  completed_at  timestamptz,
  notes         text
);

ALTER TABLE public.deletion_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "No public access to deletion_requests" ON public.deletion_requests;
CREATE POLICY "No public access to deletion_requests"
  ON public.deletion_requests FOR ALL
  USING (false);

CREATE INDEX IF NOT EXISTS idx_deletion_requests_requested_at ON public.deletion_requests (requested_at);
CREATE INDEX IF NOT EXISTS idx_deletion_requests_user_id ON public.deletion_requests (user_id);

-- ===== Per-person settings (20261022a) =====
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

-- ===== In-app account deletion (20261022b) =====
-- The app calls rpc('delete_my_account'). It deletes the signed-in person from auth.users, which
-- cascades to their rows. Ratings keep their rows with user_id set to NULL.
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

  insert into public.deletion_requests (user_id, source, completed_at, notes)
  values (uid, 'in_app', now(), 'Deleted from the app');

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

-- ===== Columns the app writes =====
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

-- ===== Older tables: policies the app does not need =====
DO $$
BEGIN
    -- The extended profile table holds premium flags; the app never writes it.
    IF to_regclass('public.user_profiles') IS NOT NULL THEN
        DROP POLICY IF EXISTS "Users can update own profile extended" ON public.user_profiles;
    END IF;

    -- Affiliates are read only by the service role (dashboard, edge functions).
    IF to_regclass('public.affiliates') IS NOT NULL THEN
        DROP POLICY IF EXISTS "Authenticated users can view active affiliates" ON public.affiliates;
        DROP POLICY IF EXISTS "Anyone can view affiliates" ON public.affiliates;
    END IF;

    -- Waitlist sign-ups go through the waitlist-signup function, which validates them.
    IF to_regclass('public.waitlist') IS NOT NULL THEN
        DROP POLICY IF EXISTS "Public can insert waitlist" ON public.waitlist;
    END IF;

    -- Referral codes: each person sees their own; checking a code tells only whether it exists.
    IF to_regclass('public.referral_codes') IS NOT NULL THEN
        DROP POLICY IF EXISTS "Anyone can view referral codes for validation" ON public.referral_codes;
        DROP POLICY IF EXISTS "Users can update own referral code" ON public.referral_codes;
        ALTER TABLE public.referral_codes ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

        EXECUTE $fn$
            CREATE OR REPLACE FUNCTION public.referral_code_exists(p_code text)
            RETURNS boolean
            LANGUAGE sql
            STABLE
            SECURITY DEFINER
            SET search_path = public, pg_temp
            AS $body$
                SELECT EXISTS (SELECT 1 FROM public.referral_codes WHERE code = upper(p_code));
            $body$
        $fn$;
        REVOKE ALL ON FUNCTION public.referral_code_exists(text) FROM public;
        GRANT EXECUTE ON FUNCTION public.referral_code_exists(text) TO anon, authenticated;
    END IF;

    -- Referral conversions are recorded by the service role only (from 20260520, in case it never ran).
    -- A referral record does not need the email of the person who used the code.
    IF to_regclass('public.referral_conversions') IS NOT NULL THEN
        DROP POLICY IF EXISTS "System can insert conversions" ON public.referral_conversions;
        DROP POLICY IF EXISTS "System can update conversions" ON public.referral_conversions;
        UPDATE public.referral_conversions SET referred_user_email = NULL WHERE referred_user_email IS NOT NULL;
    END IF;
END $$;

-- ===== Age confirmation (20261005, in case it never ran) =====
-- Only that the person confirmed the minimum age, when, and under which policy. No date of birth.
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS age_confirmed_at       TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS age_minimum_met        BOOLEAN,
    ADD COLUMN IF NOT EXISTS age_minimum_required   INTEGER,
    ADD COLUMN IF NOT EXISTS consent_policy_version TEXT,
    ADD COLUMN IF NOT EXISTS consent_app_version    TEXT;

DO $$
BEGIN
    ALTER TABLE public.profiles
        ADD CONSTRAINT profiles_age_consent_consistent
        CHECK (
            (age_confirmed_at IS NULL AND age_minimum_met IS NULL)
            OR (age_confirmed_at IS NOT NULL AND age_minimum_met IS TRUE AND age_minimum_required >= 16)
        );
EXCEPTION WHEN duplicate_object THEN
    NULL;
END $$;

-- ===== A function the app does not use =====
DO $$
BEGIN
    REVOKE ALL ON FUNCTION public.calculate_monthly_spend(uuid) FROM public, anon, authenticated;
EXCEPTION WHEN undefined_function THEN
    NULL;
END $$;

-- ===== One cancel-difficulty rating per person per service =====
-- Where someone rated the same service more than once, their latest rating is kept.
DELETE FROM public.cancel_difficulty_ratings r
USING (
    SELECT id, row_number() OVER (PARTITION BY user_id, service_name
                                  ORDER BY created_at DESC NULLS LAST, id) AS position
    FROM public.cancel_difficulty_ratings
    WHERE user_id IS NOT NULL
) ranked
WHERE r.id = ranked.id AND ranked.position > 1;

CREATE UNIQUE INDEX IF NOT EXISTS cancel_difficulty_one_per_user
    ON public.cancel_difficulty_ratings (user_id, service_name) WHERE user_id IS NOT NULL;

-- ======================== Part 3: 2026-11-11 ========================

-- ===== Profile fields kept by the server =====
-- is_pro, pro_tier, pro_activated_at: a change from the app is refused.
-- subscription_count_limit, affiliate_code, attributed_at: an update from the app leaves them as they were.
-- email: always the address on the signed-in account.
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS is_pro BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS pro_tier TEXT,
    ADD COLUMN IF NOT EXISTS pro_activated_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS email TEXT,
    ADD COLUMN IF NOT EXISTS subscription_count_limit INTEGER DEFAULT 5,
    ADD COLUMN IF NOT EXISTS affiliate_code TEXT,
    ADD COLUMN IF NOT EXISTS attributed_at TIMESTAMPTZ;

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
    ELSE
        IF NEW.is_pro IS DISTINCT FROM OLD.is_pro
           OR NEW.pro_tier IS DISTINCT FROM OLD.pro_tier
           OR NEW.pro_activated_at IS DISTINCT FROM OLD.pro_activated_at THEN
            RAISE EXCEPTION 'Pro status can only be changed by Pausely' USING ERRCODE = '42501';
        END IF;
        NEW.subscription_count_limit := OLD.subscription_count_limit;
        NEW.affiliate_code := OLD.affiliate_code;
        NEW.attributed_at := OLD.attributed_at;
    END IF;
    -- With a signed-in request the address comes from the account; a server job with no request keeps its own.
    NEW.email := coalesce(nullif(auth.email(), ''), NEW.email);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_pro_fields ON public.profiles;
CREATE TRIGGER protect_pro_fields
    BEFORE INSERT OR UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.protect_pro_fields();

-- ===== Referral statistics are kept by the server =====
CREATE OR REPLACE FUNCTION public.protect_referral_stats()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    IF coalesce(auth.role(), '') = 'service_role' OR current_user IN ('postgres', 'supabase_admin') THEN
        RETURN NEW;
    END IF;
    IF TG_OP = 'INSERT' THEN
        NEW.conversions := 0;
        NEW.pending_conversions := 0;
        NEW.total_earnings := 0;
        NEW.is_eligible_for_free_pro := false;
    ELSE
        NEW.code := OLD.code;
        NEW.referrer_user_id := OLD.referrer_user_id;
        NEW.conversions := OLD.conversions;
        NEW.pending_conversions := OLD.pending_conversions;
        NEW.total_earnings := OLD.total_earnings;
        NEW.is_eligible_for_free_pro := OLD.is_eligible_for_free_pro;
    END IF;
    RETURN NEW;
END;
$$;

DO $$
BEGIN
    IF to_regclass('public.referral_codes') IS NOT NULL THEN
        ALTER TABLE public.referral_codes
            ADD COLUMN IF NOT EXISTS conversions INTEGER DEFAULT 0,
            ADD COLUMN IF NOT EXISTS pending_conversions INTEGER DEFAULT 0,
            ADD COLUMN IF NOT EXISTS total_earnings DECIMAL(10, 2) DEFAULT 0,
            ADD COLUMN IF NOT EXISTS is_eligible_for_free_pro BOOLEAN DEFAULT FALSE;
        DROP TRIGGER IF EXISTS protect_referral_stats ON public.referral_codes;
        CREATE TRIGGER protect_referral_stats
            BEFORE INSERT OR UPDATE ON public.referral_codes
            FOR EACH ROW EXECUTE FUNCTION public.protect_referral_stats();
    END IF;
END $$;

-- ===== A ceiling on rows per account, far above real use =====
CREATE OR REPLACE FUNCTION public.enforce_row_cap()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    owner_column text := TG_ARGV[0];
    max_rows integer := TG_ARGV[1]::integer;
    owner_id uuid := (to_jsonb(NEW) ->> owner_column)::uuid;
    existing integer;
BEGIN
    IF owner_id IS NULL OR coalesce(auth.role(), '') = 'service_role' THEN
        RETURN NEW;
    END IF;
    EXECUTE format('SELECT count(*) FROM %I.%I WHERE %I = $1', TG_TABLE_SCHEMA, TG_TABLE_NAME, owner_column)
        INTO existing USING owner_id;
    IF existing >= max_rows THEN
        RAISE EXCEPTION 'This account has reached the limit for %', TG_TABLE_NAME USING ERRCODE = '54000';
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.enforce_row_cap() FROM public, anon, authenticated;

DO $$
DECLARE
    item record;
BEGIN
    FOR item IN
        SELECT * FROM (VALUES
            ('subscriptions', 'user_id', 2000),
            ('referral_codes', 'referrer_user_id', 5),
            ('cancel_difficulty_ratings', 'user_id', 500)
        ) AS caps(table_name, owner_column, max_rows)
    LOOP
        IF to_regclass('public.' || item.table_name) IS NOT NULL THEN
            EXECUTE format('DROP TRIGGER IF EXISTS enforce_row_cap ON public.%I', item.table_name);
            EXECUTE format(
                'CREATE TRIGGER enforce_row_cap BEFORE INSERT ON public.%I FOR EACH ROW EXECUTE FUNCTION public.enforce_row_cap(%L, %L)',
                item.table_name, item.owner_column, item.max_rows);
        END IF;
    END LOOP;
END $$;

-- ===== Tables no build of the app uses are closed to the app =====
-- Their rows stay, and the dashboard and edge functions still reach them.
-- To open one again: GRANT ... ON public.<table> TO authenticated, and its policies apply as before.
DO $$
DECLARE
    unused text;
BEGIN
    FOREACH unused IN ARRAY ARRAY['user_profiles', 'usage_snapshots', 'user_devices', 'ai_insights_log',
                                  'affiliates', 'affiliate_conversions', 'waitlist']
    LOOP
        IF to_regclass('public.' || unused) IS NOT NULL THEN
            EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon, authenticated', unused);
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', unused);
            IF EXISTS (SELECT 1 FROM pg_publication_tables
                       WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = unused) THEN
                BEGIN
                    EXECUTE format('ALTER PUBLICATION supabase_realtime DROP TABLE public.%I', unused);
                EXCEPTION WHEN insufficient_privilege THEN
                    -- The table is already closed above; leaving it in the publication broadcasts nothing.
                    NULL;
                END;
            END IF;
        END IF;
    END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- ======================== Checklist ========================
SELECT item AS "check", CASE WHEN passed THEN 'ok' ELSE 'NOT OK' END AS result
FROM (VALUES
    (1, 'Pro can only be granted by Pausely',
        EXISTS (SELECT 1 FROM pg_trigger
                WHERE tgrelid = 'public.profiles'::regclass AND tgname = 'protect_pro_fields' AND NOT tgisinternal)),
    (2, 'Affiliate records are closed to the app',
        coalesce(NOT has_table_privilege('anon', to_regclass('public.affiliates')::oid, 'SELECT'), true)
        AND coalesce(NOT has_table_privilege('authenticated', to_regclass('public.affiliates')::oid, 'SELECT'), true)),
    (3, 'Referral codes have no public listing',
        NOT EXISTS (SELECT 1 FROM pg_policies
                    WHERE schemaname = 'public' AND tablename = 'referral_codes'
                      AND policyname = 'Anyone can view referral codes for validation')),
    (4, 'The monthly-spend function is closed',
        NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                    WHERE n.nspname = 'public' AND p.proname = 'calculate_monthly_spend'
                      AND (has_function_privilege('anon', p.oid, 'EXECUTE')
                           OR has_function_privilege('authenticated', p.oid, 'EXECUTE')))),
    (5, 'The waitlist takes sign-ups only through its function',
        coalesce(NOT has_table_privilege('anon', to_regclass('public.waitlist')::oid, 'INSERT'), true)),
    (6, 'Account deletion is installed',
        EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                WHERE n.nspname = 'public' AND p.proname = 'delete_my_account')),
    (7, 'Row limits are in place',
        EXISTS (SELECT 1 FROM pg_trigger
                WHERE tgrelid = 'public.subscriptions'::regclass AND tgname = 'enforce_row_cap' AND NOT tgisinternal)),
    (8, 'One difficulty rating per person per service',
        EXISTS (SELECT 1 FROM pg_indexes
                WHERE schemaname = 'public' AND indexname = 'cancel_difficulty_one_per_user'))
) AS checks(position, item, passed)
UNION ALL
SELECT 'Accounts marked Pro in the database: ' || count(*) FILTER (WHERE is_pro),
       'review: each should be one you granted'
FROM public.profiles;
