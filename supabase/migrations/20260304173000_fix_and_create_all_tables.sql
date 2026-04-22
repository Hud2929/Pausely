-- Fix and create all Pausely tables
-- This migration handles the conflicts between existing migrations

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- PROFILES TABLE (Required by other tables)
-- ============================================
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT,
    is_pro BOOLEAN DEFAULT FALSE,
    pro_tier TEXT,
    pro_activated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- ============================================
-- SUBSCRIPTIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    logo_url TEXT,
    category TEXT,
    amount DECIMAL(10, 2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    billing_frequency TEXT NOT NULL DEFAULT 'monthly',
    next_billing_date TIMESTAMPTZ,
    monthly_usage_minutes INTEGER DEFAULT 0,
    cost_per_hour DECIMAL(10, 2),
    roi_score DECIMAL(5, 2),
    status TEXT NOT NULL DEFAULT 'active',
    is_detected BOOLEAN DEFAULT FALSE,
    can_pause BOOLEAN DEFAULT TRUE,
    pause_url TEXT,
    paused_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_category ON subscriptions(category);
CREATE INDEX IF NOT EXISTS idx_subscriptions_created_at ON subscriptions(created_at DESC);

-- RLS
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own subscriptions" ON subscriptions;
CREATE POLICY "Users can view own subscriptions" ON subscriptions FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert own subscriptions" ON subscriptions;
CREATE POLICY "Users can insert own subscriptions" ON subscriptions FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update own subscriptions" ON subscriptions;
CREATE POLICY "Users can update own subscriptions" ON subscriptions FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can delete own subscriptions" ON subscriptions;
CREATE POLICY "Users can delete own subscriptions" ON subscriptions FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- REFERRAL CODES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS referral_codes (
    code TEXT PRIMARY KEY,
    referrer_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    conversions INTEGER DEFAULT 0,
    pending_conversions INTEGER DEFAULT 0,
    total_earnings DECIMAL(10, 2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_eligible_for_free_pro BOOLEAN DEFAULT FALSE
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_referral_codes_user_id ON referral_codes(referrer_user_id);
CREATE INDEX IF NOT EXISTS idx_referral_codes_created_at ON referral_codes(created_at);

-- RLS
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own referral code" ON referral_codes;
CREATE POLICY "Users can view own referral code" ON referral_codes FOR SELECT USING (auth.uid() = referrer_user_id);
DROP POLICY IF EXISTS "Anyone can view referral codes for validation" ON referral_codes;
CREATE POLICY "Anyone can view referral codes for validation" ON referral_codes FOR SELECT USING (true);
DROP POLICY IF EXISTS "Users can insert own referral code" ON referral_codes;
CREATE POLICY "Users can insert own referral code" ON referral_codes FOR INSERT WITH CHECK (auth.uid() = referrer_user_id);
DROP POLICY IF EXISTS "Users can update own referral code" ON referral_codes;
CREATE POLICY "Users can update own referral code" ON referral_codes FOR UPDATE USING (auth.uid() = referrer_user_id);

-- ============================================
-- REFERRAL CONVERSIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS referral_conversions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_code TEXT NOT NULL REFERENCES referral_codes(code) ON DELETE CASCADE,
    referred_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    referred_user_email TEXT,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    converted_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_referral_conversions_code ON referral_conversions(referrer_code);
CREATE INDEX IF NOT EXISTS idx_referral_conversions_user_id ON referral_conversions(referred_user_id);
CREATE INDEX IF NOT EXISTS idx_referral_conversions_status ON referral_conversions(status);

-- RLS
ALTER TABLE referral_conversions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Referrers can view own conversions" ON referral_conversions;
CREATE POLICY "Referrers can view own conversions" ON referral_conversions FOR SELECT 
    USING (auth.uid() IN (SELECT referrer_user_id FROM referral_codes WHERE code = referrer_code));
DROP POLICY IF EXISTS "System can insert conversions" ON referral_conversions;
CREATE POLICY "System can insert conversions" ON referral_conversions FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "System can update conversions" ON referral_conversions;
CREATE POLICY "System can update conversions" ON referral_conversions FOR UPDATE USING (true);

-- ============================================
-- USER PROFILES EXTENDED
-- ============================================
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    first_name TEXT,
    last_name TEXT,
    avatar_url TEXT,
    subscription_tier TEXT DEFAULT 'free',
    is_premium BOOLEAN DEFAULT FALSE,
    premium_expires_at TIMESTAMPTZ,
    referral_discount_used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_profiles_tier ON user_profiles(subscription_tier);

-- RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own profile extended" ON user_profiles;
CREATE POLICY "Users can view own profile extended" ON user_profiles FOR SELECT USING (auth.uid() = id);
DROP POLICY IF EXISTS "Users can update own profile extended" ON user_profiles;
CREATE POLICY "Users can update own profile extended" ON user_profiles FOR UPDATE USING (auth.uid() = id);

-- ============================================
-- TRIGGERS
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_subscriptions_updated_at ON subscriptions;
CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_referral_codes_updated_at ON referral_codes;
CREATE TRIGGER update_referral_codes_updated_at BEFORE UPDATE ON referral_codes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- REALTIME
-- ============================================
-- Create publication if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;

-- Add tables to publication (safe to run multiple times)
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE subscriptions;
EXCEPTION WHEN duplicate_object THEN
    NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE referral_codes;
EXCEPTION WHEN duplicate_object THEN
    NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE referral_conversions;
EXCEPTION WHEN duplicate_object THEN
    NULL;
END $$;
