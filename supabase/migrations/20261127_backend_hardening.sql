-- Backend security, atomicity, retention, precision, and client-contract hardening (2026-11-27).
-- Mirrors Part 5 of supabase/APPLY_2026-11-27.sql so fresh migrations and APPLY converge identically.

-- 1. Pause Plan: persist cumulative `savings_since` across devices and reinstalls.
ALTER TABLE public.pause_plans
    ADD COLUMN IF NOT EXISTS savings_since TIMESTAMPTZ;

-- 2. Remove unused legacy SECURITY DEFINER helper with mutable search_path & DECIMAL(10,2) overflow.
DROP FUNCTION IF EXISTS public.calculate_monthly_spend(uuid);

-- 3. Lock search_path = '' (excluding pg_temp) on all SQL/PLpgSQL functions and harden protect_pro_fields().
CREATE OR REPLACE FUNCTION public.protect_pro_fields()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    IF coalesce(auth.role(), '') = 'service_role' OR current_user IN ('postgres', 'supabase_admin') THEN
        RETURN NEW;
    END IF;
    IF TG_OP = 'INSERT' THEN
        NEW.is_pro := false;
        NEW.pro_tier := NULL;
        NEW.pro_activated_at := NULL;
        NEW.subscription_count_limit := 5;
        NEW.affiliate_code := NULL;
        NEW.attributed_at := NULL;
        NEW.email := nullif(auth.email(), '');
        IF NEW.age_confirmed_at IS NOT NULL AND (
            NEW.age_confirmed_at < '2024-01-01T00:00:00Z'::timestamptz
            OR NEW.age_confirmed_at > pg_catalog.now() + interval '1 day'
        ) THEN
            RAISE EXCEPTION 'Invalid age confirmation timestamp' USING ERRCODE = '22023';
        END IF;
    ELSE
        IF NEW.is_pro IS DISTINCT FROM OLD.is_pro
           OR NEW.pro_tier IS DISTINCT FROM OLD.pro_tier
           OR NEW.pro_activated_at IS DISTINCT FROM OLD.pro_activated_at THEN
            RAISE EXCEPTION 'Pro status can only be changed by Pausely' USING ERRCODE = '42501';
        END IF;
        NEW.subscription_count_limit := OLD.subscription_count_limit;
        NEW.affiliate_code := OLD.affiliate_code;
        NEW.attributed_at := OLD.attributed_at;
        NEW.email := coalesce(nullif(auth.email(), ''), OLD.email);

        -- Once statutory age consent is recorded, never allow erasing, downgrading, or backdating it.
        IF OLD.age_confirmed_at IS NOT NULL THEN
            IF NEW.age_confirmed_at IS NULL
               OR NEW.age_minimum_met IS NOT TRUE
               OR coalesce(NEW.age_minimum_required, 0) < coalesce(OLD.age_minimum_required, 16)
               OR NEW.age_confirmed_at < OLD.age_confirmed_at THEN
                RAISE EXCEPTION 'Age consent record cannot be removed or backdated' USING ERRCODE = '42501';
            END IF;
            NEW.age_confirmed_at := OLD.age_confirmed_at;
        ELSIF NEW.age_confirmed_at IS NOT NULL AND (
            NEW.age_confirmed_at < '2024-01-01T00:00:00Z'::timestamptz
            OR NEW.age_confirmed_at > pg_catalog.now() + interval '1 day'
        ) THEN
            RAISE EXCEPTION 'Invalid age confirmation timestamp' USING ERRCODE = '22023';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.protect_pro_fields() FROM public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.protect_referral_stats()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
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
REVOKE ALL ON FUNCTION public.protect_referral_stats() FROM public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.enforce_row_cap()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    owner_column text := TG_ARGV[0];
    max_rows integer := TG_ARGV[1]::integer;
    row_json jsonb := pg_catalog.to_jsonb(NEW);
    owner_id uuid := (row_json ->> owner_column)::uuid;
    row_id text := row_json ->> 'id';
    existing integer;
    same_row boolean := false;
BEGIN
    IF owner_id IS NULL OR coalesce(auth.role(), '') = 'service_role' THEN
        RETURN NEW;
    END IF;
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(TG_TABLE_NAME || ':' || owner_id::text));
    IF row_id IS NOT NULL AND row_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        EXECUTE pg_catalog.format('SELECT EXISTS (SELECT 1 FROM %I.%I WHERE id = $1::uuid AND %I = $2)',
                                  TG_TABLE_SCHEMA, TG_TABLE_NAME, owner_column)
            INTO same_row USING row_id, owner_id;
        IF same_row THEN
            RETURN NEW;
        END IF;
    END IF;
    EXECUTE pg_catalog.format('SELECT count(*) FROM %I.%I WHERE %I = $1', TG_TABLE_SCHEMA, TG_TABLE_NAME, owner_column)
        INTO existing USING owner_id;
    IF existing >= max_rows THEN
        RAISE EXCEPTION 'This account has reached the limit for %', TG_TABLE_NAME USING ERRCODE = '54000';
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.enforce_row_cap() FROM public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    NEW.updated_at = pg_catalog.now();
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.update_updated_at_column() FROM public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.preserve_pause_plan_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    IF NEW.updated_at IS NULL THEN
        NEW.updated_at = pg_catalog.now();
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.preserve_pause_plan_updated_at() FROM public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.profiles (id, email)
    VALUES (NEW.id, NEW.email)
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM public, anon, authenticated;

-- Backfill any pre-existing auth.users rows missing a public.profiles row (matching APPLY).
INSERT INTO public.profiles (id, email)
SELECT u.id, u.email
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    uid uuid := auth.uid();
BEGIN
    IF uid IS NULL THEN
        RAISE EXCEPTION 'Not signed in' USING ERRCODE = '28000';
    END IF;

    INSERT INTO public.deletion_requests (user_id, source, completed_at, notes)
    VALUES (uid, 'in_app', pg_catalog.now(), 'Deleted from the app');

    IF pg_catalog.to_regclass('public.lifecycle_events') IS NOT NULL THEN
        EXECUTE 'DELETE FROM public.lifecycle_events WHERE user_id = $1' USING uid;
    END IF;

    IF pg_catalog.to_regclass('public.pause_plans') IS NOT NULL THEN
        EXECUTE 'DELETE FROM public.pause_plans WHERE user_id = $1' USING uid;
    END IF;

    IF pg_catalog.to_regclass('public.user_settings') IS NOT NULL THEN
        EXECUTE 'DELETE FROM public.user_settings WHERE user_id = $1' USING uid;
    END IF;

    IF pg_catalog.to_regclass('public.waitlist') IS NOT NULL THEN
        EXECUTE 'DELETE FROM public.waitlist WHERE converted_user_id = $1 OR pg_catalog.lower(email) = pg_catalog.lower((SELECT email FROM auth.users WHERE id = $1))' USING uid;
    END IF;

    DELETE FROM auth.users WHERE id = uid;
END;
$$;
REVOKE ALL ON FUNCTION public.delete_my_account() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

DO $$
BEGIN
    IF pg_catalog.to_regclass('public.referral_codes') IS NOT NULL THEN
        EXECUTE $fn$
            CREATE OR REPLACE FUNCTION public.referral_code_exists(p_code text)
            RETURNS boolean
            LANGUAGE sql
            STABLE
            SECURITY DEFINER
            SET search_path = ''
            AS $body$
                SELECT EXISTS (SELECT 1 FROM public.referral_codes WHERE code = pg_catalog.upper(p_code));
            $body$
        $fn$;
        REVOKE ALL ON FUNCTION public.referral_code_exists(text) FROM public;
        GRANT EXECUTE ON FUNCTION public.referral_code_exists(text) TO anon, authenticated;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
               WHERE n.nspname = 'public' AND p.proname = 'update_subscription_count') THEN
        EXECUTE $fn$
            CREATE OR REPLACE FUNCTION public.update_subscription_count()
            RETURNS trigger
            LANGUAGE plpgsql
            SET search_path = ''
            AS $body$
            BEGIN
                UPDATE public.profiles
                SET updated_at = pg_catalog.now()
                WHERE id = coalesce(NEW.user_id, OLD.user_id);
                RETURN coalesce(NEW, OLD);
            END;
            $body$
        $fn$;
        REVOKE ALL ON FUNCTION public.update_subscription_count() FROM public, anon, authenticated;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
               WHERE n.nspname = 'public' AND p.proname = 'sync_subscription_to_profile') THEN
        EXECUTE $fn$
            CREATE OR REPLACE FUNCTION public.sync_subscription_to_profile()
            RETURNS trigger
            LANGUAGE plpgsql
            SET search_path = ''
            AS $body$
            BEGIN
                UPDATE public.profiles
                SET is_pro = (NEW.status = 'active'),
                    pro_tier = CASE WHEN NEW.status = 'active' THEN NEW.tier ELSE NULL END,
                    updated_at = pg_catalog.now()
                WHERE id = NEW.user_id;
                RETURN NEW;
            END;
            $body$
        $fn$;
        REVOKE ALL ON FUNCTION public.sync_subscription_to_profile() FROM public, anon, authenticated;
    END IF;
END $$;

-- 4. Automatic rolling retention for lifecycle_events (keeps newest 2,000 events per user so accounts never brick at 5,000).
CREATE OR REPLACE FUNCTION public.prune_lifecycle_events_retention()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    keep_limit integer := COALESCE(NULLIF(TG_ARGV[0], '')::integer, 2000);
BEGIN
    IF NEW.user_id IS NULL THEN
        RETURN NEW;
    END IF;
    -- Cheap indexed probe: only run DELETE when the account actually exceeds keep_limit rows.
    IF EXISTS (
        SELECT 1
        FROM public.lifecycle_events
        WHERE user_id = NEW.user_id
        ORDER BY occurred_at DESC, id DESC
        OFFSET keep_limit
        LIMIT 1
    ) THEN
        DELETE FROM public.lifecycle_events
        WHERE id IN (
            SELECT id
            FROM public.lifecycle_events
            WHERE user_id = NEW.user_id
            ORDER BY occurred_at DESC, id DESC
            OFFSET keep_limit
        );
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.prune_lifecycle_events_retention() FROM public, anon, authenticated;

DROP TRIGGER IF EXISTS prune_lifecycle_events_retention ON public.lifecycle_events;
CREATE TRIGGER prune_lifecycle_events_retention
    AFTER INSERT ON public.lifecycle_events
    FOR EACH ROW EXECUTE FUNCTION public.prune_lifecycle_events_retention('2000');

-- 5. Atomic replay-safe App Store Server Notifications v2 entitlement upsert RPC (closes TOCTOU race).
CREATE OR REPLACE FUNCTION public.upsert_app_store_entitlement(
    p_original_transaction_id text,
    p_user_id uuid,
    p_product_id text,
    p_status text,
    p_environment text,
    p_will_auto_renew boolean,
    p_expires_at timestamptz,
    p_last_notification_type text,
    p_last_signed_date timestamptz
)
RETURNS TABLE (applied boolean, current_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_auto_renew boolean;
    v_status text;
BEGIN
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('assn:' || p_original_transaction_id));

    v_auto_renew := CASE
        WHEN p_will_auto_renew IS NOT NULL THEN p_will_auto_renew
        WHEN p_status IN ('refunded', 'revoked', 'expired') THEN false
        ELSE NULL
    END;

    BEGIN
        INSERT INTO public.app_store_entitlements (
            original_transaction_id, user_id, product_id, status, environment,
            will_auto_renew, expires_at, last_notification_type, last_signed_date, last_event_at
        )
        VALUES (
            p_original_transaction_id, p_user_id, p_product_id, p_status, p_environment,
            v_auto_renew, p_expires_at, p_last_notification_type, p_last_signed_date, pg_catalog.now()
        )
        ON CONFLICT (original_transaction_id) DO UPDATE
        SET user_id = coalesce(EXCLUDED.user_id, public.app_store_entitlements.user_id),
            product_id = EXCLUDED.product_id,
            status = EXCLUDED.status,
            environment = EXCLUDED.environment,
            will_auto_renew = coalesce(EXCLUDED.will_auto_renew, public.app_store_entitlements.will_auto_renew),
            expires_at = EXCLUDED.expires_at,
            last_notification_type = EXCLUDED.last_notification_type,
            last_signed_date = EXCLUDED.last_signed_date,
            last_event_at = pg_catalog.now()
        WHERE public.app_store_entitlements.last_signed_date IS NULL
           OR public.app_store_entitlements.last_signed_date < EXCLUDED.last_signed_date
        RETURNING public.app_store_entitlements.status INTO v_status;
    EXCEPTION WHEN foreign_key_violation THEN
        INSERT INTO public.app_store_entitlements (
            original_transaction_id, user_id, product_id, status, environment,
            will_auto_renew, expires_at, last_notification_type, last_signed_date, last_event_at
        )
        VALUES (
            p_original_transaction_id, NULL, p_product_id, p_status, p_environment,
            v_auto_renew, p_expires_at, p_last_notification_type, p_last_signed_date, pg_catalog.now()
        )
        ON CONFLICT (original_transaction_id) DO UPDATE
        SET user_id = public.app_store_entitlements.user_id,
            product_id = EXCLUDED.product_id,
            status = EXCLUDED.status,
            environment = EXCLUDED.environment,
            will_auto_renew = coalesce(EXCLUDED.will_auto_renew, public.app_store_entitlements.will_auto_renew),
            expires_at = EXCLUDED.expires_at,
            last_notification_type = EXCLUDED.last_notification_type,
            last_signed_date = EXCLUDED.last_signed_date,
            last_event_at = pg_catalog.now()
        WHERE public.app_store_entitlements.last_signed_date IS NULL
           OR public.app_store_entitlements.last_signed_date < EXCLUDED.last_signed_date
        RETURNING public.app_store_entitlements.status INTO v_status;
    END;

    IF FOUND THEN
        RETURN QUERY SELECT true, v_status;
    ELSE
        SELECT e.status INTO v_status
        FROM public.app_store_entitlements e
        WHERE e.original_transaction_id = p_original_transaction_id;
        RETURN QUERY SELECT false, v_status;
    END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.upsert_app_store_entitlement(text, uuid, text, text, text, boolean, timestamptz, text, timestamptz) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_app_store_entitlement(text, uuid, text, text, text, boolean, timestamptz, text, timestamptz) TO service_role;

-- 6. Persistent server-only Edge Function rate-limit store + atomic RPC (e.g. apple-revoke per-user throttle).
CREATE TABLE IF NOT EXISTS public.edge_rate_limits (
    key TEXT PRIMARY KEY CHECK (char_length(key) BETWEEN 1 AND 200),
    window_start TIMESTAMPTZ NOT NULL DEFAULT pg_catalog.now(),
    hit_count INTEGER NOT NULL DEFAULT 1 CHECK (hit_count >= 1)
);

ALTER TABLE public.edge_rate_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.edge_rate_limits FROM anon, authenticated;

DROP POLICY IF EXISTS "No public access to edge_rate_limits" ON public.edge_rate_limits;
CREATE POLICY "No public access to edge_rate_limits"
    ON public.edge_rate_limits FOR ALL
    USING (false);

CREATE OR REPLACE FUNCTION public.consume_rate_limit(
    p_key text,
    p_max_hits integer,
    p_window_seconds integer
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_hits integer;
    v_now timestamptz := pg_catalog.now();
    v_window interval := pg_catalog.make_interval(secs => GREATEST(1, p_window_seconds));
BEGIN
    DELETE FROM public.edge_rate_limits
    WHERE window_start < v_now - GREATEST(interval '24 hours', v_window);

    INSERT INTO public.edge_rate_limits (key, window_start, hit_count)
    VALUES (p_key, v_now, 1)
    ON CONFLICT (key) DO UPDATE
    SET hit_count = CASE
            WHEN public.edge_rate_limits.window_start + v_window <= v_now THEN 1
            ELSE public.edge_rate_limits.hit_count + 1
        END,
        window_start = CASE
            WHEN public.edge_rate_limits.window_start + v_window <= v_now THEN v_now
            ELSE public.edge_rate_limits.window_start
        END
    RETURNING hit_count INTO v_hits;

    RETURN v_hits <= p_max_hits;
END;
$$;
REVOKE ALL ON FUNCTION public.consume_rate_limit(text, integer, integer) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_rate_limit(text, integer, integer) TO service_role;

-- 7. Waitlist index + atomic hourly ceiling RPC (closes count-then-insert TOCTOU race and full-table scan).
DO $$
BEGIN
    IF pg_catalog.to_regclass('public.waitlist') IS NOT NULL THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_waitlist_created_at ON public.waitlist (created_at DESC)';

        EXECUTE $fn$
            CREATE OR REPLACE FUNCTION public.join_waitlist(
                p_email text,
                p_source text,
                p_max_per_hour integer DEFAULT 200
            )
            RETURNS text
            LANGUAGE plpgsql
            SECURITY DEFINER
            SET search_path = ''
            AS $body$
            DECLARE
                v_recent integer;
            BEGIN
                PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('waitlist:hourly_cap'));
                SELECT pg_catalog.count(*) INTO v_recent
                FROM public.waitlist
                WHERE created_at > pg_catalog.now() - interval '1 hour';

                IF v_recent >= GREATEST(1, p_max_per_hour) THEN
                    RETURN 'rate_limited';
                END IF;

                INSERT INTO public.waitlist (email, source)
                VALUES (p_email, p_source)
                ON CONFLICT (email) DO NOTHING;

                IF FOUND THEN
                    RETURN 'inserted';
                END IF;
                RETURN 'existing';
            END;
            $body$
        $fn$;
        REVOKE ALL ON FUNCTION public.join_waitlist(text, text, integer) FROM public, anon, authenticated;
        GRANT EXECUTE ON FUNCTION public.join_waitlist(text, text, integer) TO service_role;
    END IF;
END $$;

-- 8. Storage-DoS & value CHECK constraints across user-writable tables.
DO $$
BEGIN
    ALTER TABLE public.profiles
        ADD CONSTRAINT profiles_field_bounds
        CHECK (
            (display_name IS NULL OR char_length(display_name) <= 120)
            AND (email IS NULL OR char_length(email) <= 320)
            AND (consent_policy_version IS NULL OR char_length(consent_policy_version) <= 32)
            AND (consent_app_version IS NULL OR char_length(consent_app_version) <= 32)
        );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'full_name') THEN
        BEGIN
            ALTER TABLE public.profiles ADD CONSTRAINT profiles_full_name_bound CHECK (full_name IS NULL OR char_length(full_name) <= 120);
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'avatar_url') THEN
        BEGIN
            ALTER TABLE public.profiles ADD CONSTRAINT profiles_avatar_url_bound CHECK (avatar_url IS NULL OR char_length(avatar_url) <= 500);
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'affiliate_code') THEN
        BEGIN
            ALTER TABLE public.profiles ADD CONSTRAINT profiles_affiliate_code_bound CHECK (affiliate_code IS NULL OR char_length(affiliate_code) <= 64);
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
    END IF;
END $$;

DO $$
BEGIN
    ALTER TABLE public.subscriptions
        ADD CONSTRAINT subscriptions_notify_days_bound
        CHECK (notify_before_days IS NULL OR notify_before_days BETWEEN 0 AND 365);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'description') THEN
        BEGIN
            ALTER TABLE public.subscriptions ADD CONSTRAINT subscriptions_description_bound CHECK (description IS NULL OR char_length(description) <= 1000);
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'logo_url') THEN
        BEGIN
            ALTER TABLE public.subscriptions ADD CONSTRAINT subscriptions_logo_url_bound CHECK (logo_url IS NULL OR char_length(logo_url) <= 500);
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'pause_url') THEN
        BEGIN
            ALTER TABLE public.subscriptions ADD CONSTRAINT subscriptions_pause_url_bound CHECK (pause_url IS NULL OR char_length(pause_url) <= 500);
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'app_bundle_id') THEN
        BEGIN
            ALTER TABLE public.subscriptions ADD CONSTRAINT subscriptions_app_bundle_id_bound CHECK (app_bundle_id IS NULL OR char_length(app_bundle_id) <= 200);
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'website_url') THEN
        BEGIN
            ALTER TABLE public.subscriptions ADD CONSTRAINT subscriptions_website_url_bound CHECK (website_url IS NULL OR char_length(website_url) <= 500);
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'ai_usage_insight') THEN
        BEGIN
            ALTER TABLE public.subscriptions ADD CONSTRAINT subscriptions_ai_usage_insight_bound CHECK (ai_usage_insight IS NULL OR char_length(ai_usage_insight) <= 2000);
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'ai_recommendation') THEN
        BEGIN
            ALTER TABLE public.subscriptions ADD CONSTRAINT subscriptions_ai_recommendation_bound CHECK (ai_recommendation IS NULL OR char_length(ai_recommendation) <= 2000);
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'tags') THEN
        ALTER TABLE public.subscriptions DROP CONSTRAINT IF EXISTS subscriptions_tags_bound;
        ALTER TABLE public.subscriptions
            ADD CONSTRAINT subscriptions_tags_bound
            CHECK (tags IS NULL OR (cardinality(tags) <= 20 AND octet_length(array_to_string(tags, ',')) <= 1024));
    END IF;
END $$;

DO $$
BEGIN
    IF pg_catalog.to_regclass('public.referral_codes') IS NOT NULL THEN
        BEGIN
            ALTER TABLE public.referral_codes
                ADD CONSTRAINT referral_codes_code_bound
                CHECK (char_length(code) BETWEEN 1 AND 64);
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
    END IF;
END $$;

-- 9. Scope profiles & subscriptions RLS explicitly TO authenticated, revoke unnecessary anon table grants,
-- and guarantee profiles_missing_age_consent is locked down.
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT TO authenticated USING (auth.uid() = id);
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can view own subscriptions" ON public.subscriptions;
CREATE POLICY "Users can view own subscriptions" ON public.subscriptions FOR SELECT TO authenticated USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert own subscriptions" ON public.subscriptions;
CREATE POLICY "Users can insert own subscriptions" ON public.subscriptions FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update own subscriptions" ON public.subscriptions;
CREATE POLICY "Users can update own subscriptions" ON public.subscriptions FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can delete own subscriptions" ON public.subscriptions;
CREATE POLICY "Users can delete own subscriptions" ON public.subscriptions FOR DELETE TO authenticated USING (auth.uid() = user_id);

DO $$
DECLARE
    tbl text;
BEGIN
    FOREACH tbl IN ARRAY ARRAY['profiles', 'subscriptions', 'lifecycle_events', 'pause_plans',
                               'user_settings', 'cancel_difficulty_ratings', 'referral_codes',
                               'referral_conversions']
    LOOP
        IF pg_catalog.to_regclass('public.' || tbl) IS NOT NULL THEN
            EXECUTE pg_catalog.format('REVOKE ALL ON TABLE public.%I FROM anon', tbl);
        END IF;
    END LOOP;

    IF pg_catalog.to_regclass('public.profiles_missing_age_consent') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL ON TABLE public.profiles_missing_age_consent FROM anon, authenticated';
    END IF;
END $$;

NOTIFY pgrst, 'reload schema';
