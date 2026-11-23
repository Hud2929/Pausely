-- Multi-device sync for Savings Receipt history & Pause Plan, everyday subscription fields
-- (notes, payment method, cost splitting), server-side StoreKit entitlements, and unused-surface cleanup.
-- Safe to run more than once.

-- ============================================================================
-- 1. Everyday subscription metadata (notes, payment method, split count)
-- ============================================================================
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

-- ============================================================================
-- 2. Lifecycle events (Savings Receipt, price history, kept decisions — synced across devices)
-- ============================================================================
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

-- ============================================================================
-- 3. Pause Plans (streaming rotation schedule — synced across devices)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.pause_plans (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    subscription_ids UUID[] NOT NULL DEFAULT '{}',
    started_on TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.pause_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own pause plan" ON public.pause_plans;
CREATE POLICY "Users manage own pause plan"
    ON public.pause_plans FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

DROP TRIGGER IF EXISTS update_pause_plans_updated_at ON public.pause_plans;
CREATE TRIGGER update_pause_plans_updated_at
    BEFORE UPDATE ON public.pause_plans
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- 4. Server-side App Store entitlements (written only by appstore-notifications Edge Function)
-- ============================================================================
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
    last_event_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

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

-- ============================================================================
-- 5. Row cap on lifecycle_events (far above real use)
-- ============================================================================
DO $$
BEGIN
    IF to_regclass('public.lifecycle_events') IS NOT NULL
       AND EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                   WHERE n.nspname = 'public' AND p.proname = 'enforce_row_cap') THEN
        DROP TRIGGER IF EXISTS enforce_row_cap ON public.lifecycle_events;
        CREATE TRIGGER enforce_row_cap
            BEFORE INSERT ON public.lifecycle_events
            FOR EACH ROW EXECUTE FUNCTION public.enforce_row_cap('user_id', '5000');
    END IF;
END $$;

-- ============================================================================
-- 6. Account deletion cleans new tables explicitly as well as via CASCADE
-- ============================================================================
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

-- ============================================================================
-- 7. Close unused alternatives table & drop unused Realtime publications
-- ============================================================================
DO $$
DECLARE
    pub_table text;
BEGIN
    IF to_regclass('public.alternatives') IS NOT NULL THEN
        REVOKE ALL ON TABLE public.alternatives FROM anon, authenticated;
        ALTER TABLE public.alternatives ENABLE ROW LEVEL SECURITY;
    END IF;

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
