-- The app reads and writes subscriptions.amount, but migration 20260305 renamed it to "cost",
-- so cloud saves fail with PGRST204 ("Could not find the 'amount' column").
-- Restore the name the app uses. Safe to run more than once.

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'cost')
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'public' AND table_name = 'subscriptions' AND column_name = 'amount') THEN
        ALTER TABLE public.subscriptions RENAME COLUMN cost TO amount;
    END IF;
END $$;

-- This function referenced the old column name.
CREATE OR REPLACE FUNCTION calculate_monthly_spend(p_user_id UUID)
RETURNS DECIMAL(10, 2) AS $$
DECLARE
    monthly_total DECIMAL(10, 2) := 0;
BEGIN
    SELECT COALESCE(SUM(
        CASE
            WHEN billing_frequency = 'weekly' THEN amount * 4.33
            WHEN billing_frequency = 'monthly' THEN amount
            WHEN billing_frequency = 'quarterly' THEN amount / 3
            WHEN billing_frequency = 'yearly' THEN amount / 12
            ELSE amount
        END
    ), 0) INTO monthly_total
    FROM subscriptions
    WHERE user_id = p_user_id
      AND status = 'active'
      AND (paused_until IS NULL OR paused_until < NOW());

    RETURN monthly_total;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Make the API pick up the change immediately.
NOTIFY pgrst, 'reload schema';
