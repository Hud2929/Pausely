-- Follow-up to 20261106_security_and_sync_fixes.sql. Safe to run more than once.
-- Nothing a shipped build reads or writes is dropped. Tables no build uses are closed to the app,
-- not deleted: their rows stay, and the dashboard and edge functions still reach them.

-- ============================================================================
-- 1. Profile fields kept by the server
-- is_pro, pro_tier, pro_activated_at: a change from the app is refused (as in 20261106).
-- subscription_count_limit, affiliate_code, attributed_at: an update from the app leaves them as they were.
-- email: always the address on the signed-in account.
-- ============================================================================
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

-- ============================================================================
-- 2. Referral statistics are kept by the server
-- A person may create their own code. The counts, earnings and the free-Pro flag start at zero and
-- change only through the service role.
-- ============================================================================
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

-- ============================================================================
-- 3. A ceiling on rows per account, far above real use, so one account can't fill a table
-- ============================================================================
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

-- ============================================================================
-- 4. Tables no build of the app uses are closed to the app
-- (user_profiles, usage_snapshots, user_devices, ai_insights_log, affiliates, affiliate_conversions,
-- waitlist). The waitlist is written by the waitlist-signup function, which uses the service role.
-- To open one again: GRANT ... ON public.<table> TO authenticated, and its policies apply as before.
-- ============================================================================
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
