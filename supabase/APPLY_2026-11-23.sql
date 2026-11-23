-- Pausely database changes. Paste this whole file into Supabase > SQL editor > Run.
-- Safe to run more than once. Replaces APPLY_2026-11-11.sql: everything that file did is included.
-- It runs as one transaction: if any statement fails, nothing is changed.
-- The result shown at the end is a checklist. Every line should say "ok".
-- Proven on a local copy of the schema by scripts/dbtest/run.sh.

BEGIN;

-- ======================== Part 1: pending since 2026-10-22 ========================

-- ===== Cancel-difficulty ratings (20260916) =====
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

-- ======================== Part 2: 2026-11-06 sweep ========================

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

DO $$
BEGIN
    IF to_regclass('public.user_profiles') IS NOT NULL THEN
        DROP POLICY IF EXISTS "Users can update own profile extended" ON public.user_profiles;
    END IF;

    IF to_regclass('public.affiliates') IS NOT NULL THEN
        DROP POLICY IF EXISTS "Authenticated users can view active affiliates" ON public.affiliates;
        DROP POLICY IF EXISTS "Anyone can view affiliates" ON public.affiliates;
    END IF;

    IF to_regclass('public.waitlist') IS NOT NULL THEN
        DROP POLICY IF EXISTS "Public can insert waitlist" ON public.waitlist;
    END IF;

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

    IF to_regclass('public.referral_conversions') IS NOT NULL THEN
        DROP POLICY IF EXISTS "System can insert conversions" ON public.referral_conversions;
        DROP POLICY IF EXISTS "System can update conversions" ON public.referral_conversions;
        UPDATE public.referral_conversions SET referred_user_email = NULL WHERE referred_user_email IS NOT NULL;
    END IF;
END $$;

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

DO $$
BEGIN
    REVOKE ALL ON FUNCTION public.calculate_monthly_spend(uuid) FROM public, anon, authenticated;
EXCEPTION WHEN undefined_function THEN
    NULL;
END $$;

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
    NEW.email := coalesce(nullif(auth.email(), ''), NEW.email);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_pro_fields ON public.profiles;
CREATE TRIGGER protect_pro_fields
    BEFORE INSERT OR UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.protect_pro_fields();

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

-- ======================== Part 4: 2026-11-23 ========================

-- ===== Everyday subscription metadata =====
ALTER TABLE public.subscriptions
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS payment_method TEXT,
    ADD COLUMN IF NOT EXISTS split_count INTEGER NOT NULL DEFAULT 1;

DO $$
BEGIN
    ALTER TABLE public.subscriptions
        ADD CONSTRAINT subscriptions_split_count_valid
        CHECK (split_count BETWEEN 1 AND 20);
EXCEPTION WHEN duplicate_object THEN
    NULL;
END $$;

-- ===== Lifecycle events (multi-device Savings Receipt, price history, kept decisions) =====
CREATE TABLE IF NOT EXISTS public.lifecycle_events (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subscription_id UUID NOT NULL,
    subscription_name TEXT NOT NULL CHECK (char_length(subscription_name) BETWEEN 1 AND 200),
    kind TEXT NOT NULL CHECK (kind IN (
        'added', 'renewed', 'trialEnded', 'priceChanged',
        'cancelled', 'reactivated', 'deleted', 'kept'
    )),
    occurred_at TIMESTAMPTZ NOT NULL,
    amount DECIMAL(12, 2) NOT NULL CHECK (amount >= 0),
    currency TEXT NOT NULL DEFAULT 'USD',
    frequency TEXT NOT NULL DEFAULT 'monthly',
    previous_amount DECIMAL(12, 2),
    renewal_date TIMESTAMPTZ,
    anchor_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lifecycle_events_user_occurred
    ON public.lifecycle_events (user_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_lifecycle_events_user_sub
    ON public.lifecycle_events (user_id, subscription_id);

ALTER TABLE public.lifecycle_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own lifecycle events" ON public.lifecycle_events;
CREATE POLICY "Users manage own lifecycle events"
    ON public.lifecycle_events FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ===== Pause Plans (multi-device rotation schedule) =====
CREATE TABLE IF NOT EXISTS public.pause_plans (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    subscription_ids UUID[] NOT NULL DEFAULT '{}',
    started_on TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.pause_plans
    ADD COLUMN IF NOT EXISTS ended_at TIMESTAMPTZ;

ALTER TABLE public.pause_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own pause plan" ON public.pause_plans;
CREATE POLICY "Users manage own pause plan"
    ON public.pause_plans FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.preserve_pause_plan_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.updated_at IS NULL THEN
        NEW.updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS update_pause_plans_updated_at ON public.pause_plans;
CREATE TRIGGER update_pause_plans_updated_at
    BEFORE UPDATE ON public.pause_plans
    FOR EACH ROW EXECUTE FUNCTION public.preserve_pause_plan_updated_at();

-- ===== Automatic profile creation on new auth.users signup =====
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
BEGIN
    INSERT INTO public.profiles (id, email)
    VALUES (NEW.id, NEW.email)
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_new_user() FROM public, anon, authenticated;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ===== Server-side App Store entitlements (ASSN v2 webhook truth) =====
CREATE TABLE IF NOT EXISTS public.app_store_entitlements (
    original_transaction_id TEXT PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    product_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN (
        'active', 'trial', 'grace_period', 'billing_retry', 'expired', 'revoked', 'refunded'
    )),
    environment TEXT NOT NULL DEFAULT 'Production' CHECK (environment IN ('Production', 'Sandbox')),
    will_auto_renew BOOLEAN,
    expires_at TIMESTAMPTZ,
    last_notification_type TEXT,
    last_signed_date TIMESTAMPTZ,
    last_event_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.app_store_entitlements
    ADD COLUMN IF NOT EXISTS last_signed_date TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_app_store_entitlements_user_id
    ON public.app_store_entitlements (user_id);
CREATE INDEX IF NOT EXISTS idx_app_store_entitlements_status
    ON public.app_store_entitlements (status);

ALTER TABLE public.app_store_entitlements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_store_entitlements FROM anon, authenticated;

DROP POLICY IF EXISTS "No public access to app_store_entitlements" ON public.app_store_entitlements;
CREATE POLICY "No public access to app_store_entitlements"
    ON public.app_store_entitlements FOR ALL
    USING (false);

DROP TRIGGER IF EXISTS update_app_store_entitlements_updated_at ON public.app_store_entitlements;
CREATE TRIGGER update_app_store_entitlements_updated_at
    BEFORE UPDATE ON public.app_store_entitlements
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ===== In-app account deletion (cascades + explicit cleanup of all user tables) =====
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  uid uuid := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not signed in' USING errcode = '28000';
  END IF;

  INSERT INTO public.deletion_requests (user_id, source, completed_at, notes)
  VALUES (uid, 'in_app', now(), 'Deleted from the app');

  IF to_regclass('public.lifecycle_events') IS NOT NULL THEN
    EXECUTE 'DELETE FROM public.lifecycle_events WHERE user_id = $1' USING uid;
  END IF;

  IF to_regclass('public.pause_plans') IS NOT NULL THEN
    EXECUTE 'DELETE FROM public.pause_plans WHERE user_id = $1' USING uid;
  END IF;

  IF to_regclass('public.user_settings') IS NOT NULL THEN
    EXECUTE 'DELETE FROM public.user_settings WHERE user_id = $1' USING uid;
  END IF;

  DELETE FROM auth.users WHERE id = uid;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM public;
REVOKE ALL ON FUNCTION public.delete_my_account() FROM anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

-- ===== Row ceilings across user-writable tables =====
DO $$
DECLARE
    item record;
BEGIN
    FOR item IN
        SELECT * FROM (VALUES
            ('subscriptions', 'user_id', 2000),
            ('lifecycle_events', 'user_id', 5000),
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

-- ===== Close unused tables & views, drop unused Realtime publications =====
DO $$
DECLARE
    unused text;
    pub_table text;
    kind "char";
BEGIN
    FOREACH unused IN ARRAY ARRAY['user_profiles', 'usage_snapshots', 'user_devices', 'ai_insights_log',
                                  'affiliates', 'affiliate_conversions', 'waitlist', 'alternatives',
                                  'orders', 'user_subscriptions',
                                  'active_subscriptions', 'expiring_subscriptions', 'payment_failures']
    LOOP
        SELECT c.relkind INTO kind FROM pg_class c WHERE c.oid = to_regclass('public.' || unused);
        IF kind IS NULL THEN
            CONTINUE;
        END IF;
        EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon, authenticated', unused);
        IF kind IN ('r', 'p') THEN
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', unused);
            IF EXISTS (SELECT 1 FROM pg_publication_tables
                       WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = unused) THEN
                BEGIN
                    EXECUTE format('ALTER PUBLICATION supabase_realtime DROP TABLE public.%I', unused);
                EXCEPTION WHEN insufficient_privilege THEN
                    NULL;
                END;
            END IF;
        END IF;
    END LOOP;

    FOREACH pub_table IN ARRAY ARRAY['subscriptions', 'referral_codes', 'referral_conversions'] LOOP
        IF EXISTS (SELECT 1 FROM pg_publication_tables
                   WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = pub_table) THEN
            BEGIN
                EXECUTE format('ALTER PUBLICATION supabase_realtime DROP TABLE public.%I', pub_table);
            EXCEPTION WHEN insufficient_privilege THEN
                NULL;
            END;
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
                WHERE tgrelid = 'public.subscriptions'::regclass AND tgname = 'enforce_row_cap' AND NOT tgisinternal)
        AND EXISTS (SELECT 1 FROM pg_trigger
                    WHERE tgrelid = 'public.lifecycle_events'::regclass AND tgname = 'enforce_row_cap' AND NOT tgisinternal)),
    (8, 'One difficulty rating per person per service',
        EXISTS (SELECT 1 FROM pg_indexes
                WHERE schemaname = 'public' AND indexname = 'cancel_difficulty_one_per_user')),
    (9, 'The earlier payment tables and views are closed to the app',
        NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                    WHERE n.nspname = 'public'
                      AND c.relname IN ('orders', 'user_subscriptions', 'active_subscriptions',
                                        'expiring_subscriptions', 'payment_failures')
                      AND (has_table_privilege('anon', c.oid, 'SELECT')
                           OR has_table_privilege('authenticated', c.oid, 'SELECT')))),
    (10, 'Lifecycle events and pause plans tables are installed',
        to_regclass('public.lifecycle_events') IS NOT NULL AND to_regclass('public.pause_plans') IS NOT NULL),
    (11, 'App Store entitlements table is server-only',
        to_regclass('public.app_store_entitlements') IS NOT NULL
        AND NOT has_table_privilege('anon', 'public.app_store_entitlements'::regclass, 'SELECT')
        AND NOT has_table_privilege('authenticated', 'public.app_store_entitlements'::regclass, 'SELECT')),
    (12, 'Unused alternatives table is closed to the app',
        coalesce(NOT has_table_privilege('anon', to_regclass('public.alternatives')::oid, 'SELECT'), true)
        AND coalesce(NOT has_table_privilege('authenticated', to_regclass('public.alternatives')::oid, 'SELECT'), true)),
    (13, 'New auth users automatically receive a profile row',
        EXISTS (SELECT 1 FROM pg_trigger
                WHERE tgrelid = 'auth.users'::regclass AND tgname = 'on_auth_user_created' AND NOT tgisinternal))
) AS checks(position, item, passed)
UNION ALL
SELECT 'Accounts marked Pro in the database: ' || count(*) FILTER (WHERE is_pro),
       'review: each should be one you granted'
FROM public.profiles;
