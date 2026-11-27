-- Security, numeric precision, row-cap concurrency, GDPR waitlist erasure, and tracked_trials lockdown.
-- Mirrors the 2026-11-24 hardening additions in supabase/APPLY_2026-11-23.sql so fresh migrations stay 100% identical.

-- 1. Cancel-difficulty canonical slug + privacy threshold (>= 3 ratings)
-- Deduplicate on the computed canonical slug BEFORE normalizing rows so existing unique index
-- `cancel_difficulty_one_per_user` never aborts with 23505 when mixed-case duplicates coexist.
DELETE FROM public.cancel_difficulty_ratings r
USING (
    SELECT id,
           row_number() OVER (
               PARTITION BY user_id,
                   left(coalesce(nullif(trim(BOTH '-' FROM regexp_replace(lower(trim(service_name)), '[^a-z0-9]+', '-', 'g')), ''), 'service'), 120)
               ORDER BY created_at DESC NULLS LAST, id
           ) AS position
    FROM public.cancel_difficulty_ratings
    WHERE user_id IS NOT NULL
) ranked
WHERE r.id = ranked.id AND ranked.position > 1;

UPDATE public.cancel_difficulty_ratings
SET service_name = left(
  coalesce(nullif(trim(BOTH '-' FROM regexp_replace(lower(trim(service_name)), '[^a-z0-9]+', '-', 'g')), ''), 'service'),
  120
)
WHERE service_name !~ '^[a-z0-9][a-z0-9-]{0,119}$';

DO $$
BEGIN
  ALTER TABLE public.cancel_difficulty_ratings
    ADD CONSTRAINT cancel_difficulty_service_slug
    CHECK (service_name ~ '^[a-z0-9][a-z0-9-]{0,119}$');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_cancel_difficulty_service_name
  ON public.cancel_difficulty_ratings (service_name);

CREATE OR REPLACE VIEW public.service_difficulty_scores AS
SELECT
  service_name,
  ROUND(AVG(difficulty_rating)::numeric, 1) AS avg_difficulty,
  COUNT(*) AS rating_count
FROM public.cancel_difficulty_ratings
GROUP BY service_name
HAVING COUNT(*) >= 3;

GRANT SELECT ON public.service_difficulty_scores TO anon, authenticated;

-- 2. Revoke direct access on deletion_requests
REVOKE ALL ON TABLE public.deletion_requests FROM anon, authenticated;

-- 3. Lock server-owned profile fields on INSERT as well as UPDATE
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
        NEW.subscription_count_limit := 5;
        NEW.affiliate_code := NULL;
        NEW.attributed_at := NULL;
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

-- 4. Atomic advisory-locked enforce_row_cap supporting idempotent UPSERT retries
CREATE OR REPLACE FUNCTION public.enforce_row_cap()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    owner_column text := TG_ARGV[0];
    max_rows integer := TG_ARGV[1]::integer;
    row_json jsonb := to_jsonb(NEW);
    owner_id uuid := (row_json ->> owner_column)::uuid;
    row_id text := row_json ->> 'id';
    existing integer;
    same_row boolean := false;
BEGIN
    IF owner_id IS NULL OR coalesce(auth.role(), '') = 'service_role' THEN
        RETURN NEW;
    END IF;
    PERFORM pg_advisory_xact_lock(hashtext(TG_TABLE_NAME || ':' || owner_id::text));
    IF row_id IS NOT NULL AND row_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        EXECUTE format('SELECT EXISTS (SELECT 1 FROM %I.%I WHERE id = $1::uuid AND %I = $2)',
                       TG_TABLE_SCHEMA, TG_TABLE_NAME, owner_column)
            INTO same_row USING row_id, owner_id;
        IF same_row THEN
            RETURN NEW;
        END IF;
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

-- 5. Lock search_path on legacy trigger functions
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
               WHERE n.nspname = 'public' AND p.proname = 'update_subscription_count') THEN
        ALTER FUNCTION public.update_subscription_count() SET search_path = public, pg_temp;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
               WHERE n.nspname = 'public' AND p.proname = 'sync_subscription_to_profile') THEN
        ALTER FUNCTION public.sync_subscription_to_profile() SET search_path = public, pg_temp;
    END IF;
END $$;

-- 6. Numeric precision & payload size bounds
ALTER TABLE public.subscriptions
    ALTER COLUMN amount TYPE NUMERIC(20, 4);

CREATE INDEX IF NOT EXISTS idx_subscriptions_user_created
    ON public.subscriptions (user_id, created_at DESC);

DO $$
BEGIN
    ALTER TABLE public.subscriptions
        ADD CONSTRAINT subscriptions_amount_non_negative
        CHECK (amount >= 0);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER TABLE public.subscriptions
        ADD CONSTRAINT subscriptions_field_bounds
        CHECK (
            char_length(name) BETWEEN 1 AND 200
            AND (notes IS NULL OR char_length(notes) <= 2000)
            AND (payment_method IS NULL OR char_length(payment_method) <= 120)
            AND (category IS NULL OR char_length(category) <= 80)
            AND (currency IS NULL OR char_length(currency) <= 10)
            AND (billing_frequency IS NULL OR char_length(billing_frequency) <= 32)
            AND (status IS NULL OR char_length(status) <= 32)
        );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'tags') THEN
        BEGIN
            ALTER TABLE public.subscriptions
                ADD CONSTRAINT subscriptions_tags_bound
                CHECK (tags IS NULL OR cardinality(tags) <= 20);
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'ai_alternatives') THEN
        BEGIN
            ALTER TABLE public.subscriptions
                ADD CONSTRAINT subscriptions_ai_alternatives_bound
                CHECK (ai_alternatives IS NULL OR octet_length(ai_alternatives::text) <= 4096);
        EXCEPTION WHEN duplicate_object THEN NULL;
        END;
    END IF;
END $$;

ALTER TABLE public.lifecycle_events
    ALTER COLUMN amount TYPE NUMERIC(20, 6),
    ALTER COLUMN previous_amount TYPE NUMERIC(20, 6);

DO $$
BEGIN
    ALTER TABLE public.lifecycle_events
        ADD CONSTRAINT lifecycle_events_field_bounds
        CHECK (
            char_length(currency) BETWEEN 1 AND 10
            AND char_length(frequency) BETWEEN 1 AND 32
            AND (previous_amount IS NULL OR previous_amount >= 0)
        );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER TABLE public.pause_plans
        ADD CONSTRAINT pause_plans_ids_bound
        CHECK (cardinality(subscription_ids) <= 50);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 7. GDPR Art. 17 waitlist erasure inside delete_my_account()
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

    IF to_regclass('public.waitlist') IS NOT NULL THEN
        EXECUTE 'DELETE FROM public.waitlist WHERE converted_user_id = $1 OR lower(email) = lower((SELECT email FROM auth.users WHERE id = $1))' USING uid;
    END IF;

    DELETE FROM auth.users WHERE id = uid;
END;
$$;
REVOKE ALL ON FUNCTION public.delete_my_account() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

-- 8. Lock down unused tracked_trials & alternatives (plus drop from Realtime)
DO $$
DECLARE
    unused text;
BEGIN
    FOREACH unused IN ARRAY ARRAY['alternatives', 'tracked_trials'] LOOP
        IF to_regclass('public.' || unused) IS NOT NULL THEN
            EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon, authenticated', unused);
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', unused);
            IF EXISTS (SELECT 1 FROM pg_publication_tables
                       WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = unused) THEN
                BEGIN
                    EXECUTE format('ALTER PUBLICATION supabase_realtime DROP TABLE public.%I', unused);
                EXCEPTION WHEN insufficient_privilege THEN NULL;
                END;
            END IF;
        END IF;
    END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
