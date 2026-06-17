-- Make alternatives seed data idempotent and add unique constraint to affiliate_conversions

-- ============================================
-- ALTERNATIVES: Prevent duplicate seed data on re-run
-- ============================================
-- First ensure we have a unique constraint for conflict detection
DO $$
BEGIN
    ALTER TABLE alternatives ADD CONSTRAINT alternatives_unique_name UNIQUE (source_subscription_name, alternative_name);
EXCEPTION WHEN duplicate_table OR duplicate_object THEN
    NULL;
END $$;

-- ============================================
-- AFFILIATE_CONVERSIONS: Prevent duplicate conversions
-- ============================================
DO $$
BEGIN
    ALTER TABLE affiliate_conversions ADD CONSTRAINT affiliate_conversions_unique_user_affiliate UNIQUE (affiliate_id, user_id);
EXCEPTION WHEN duplicate_table OR duplicate_object THEN
    NULL;
END $$;
