-- Pausely Supabase Database Setup
-- Run this SQL in your Supabase SQL Editor to fix the "could not find the table" error

-- =====================================================
-- 1. CREATE SUBSCRIPTIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    logo_url TEXT,
    category TEXT,
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT DEFAULT 'USD',
    billing_frequency TEXT DEFAULT 'monthly',
    next_billing_date DATE,
    monthly_usage_minutes INTEGER DEFAULT 0,
    cost_per_hour DECIMAL(10,2),
    roi_score DECIMAL(5,2),
    status TEXT DEFAULT 'active',
    is_detected BOOLEAN DEFAULT false,
    can_pause BOOLEAN DEFAULT true,
    pause_url TEXT,
    paused_until DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 2. ENABLE ROW LEVEL SECURITY
-- =====================================================
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 3. CREATE RLS POLICIES
-- =====================================================

-- Policy: Users can only see their own subscriptions
CREATE POLICY "Users can only see their own subscriptions"
    ON subscriptions FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Users can only insert their own subscriptions
CREATE POLICY "Users can only insert their own subscriptions"
    ON subscriptions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only update their own subscriptions
CREATE POLICY "Users can only update their own subscriptions"
    ON subscriptions FOR UPDATE
    USING (auth.uid() = user_id);

-- Policy: Users can only delete their own subscriptions
CREATE POLICY "Users can only delete their own subscriptions"
    ON subscriptions FOR DELETE
    USING (auth.uid() = user_id);

-- =====================================================
-- 4. CREATE INDEXES FOR PERFORMANCE
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_category ON subscriptions(category);

-- =====================================================
-- 5. CREATE UPDATED_AT TRIGGER
-- =====================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 6. CREATE USER SETTINGS TABLE (for preferences)
-- =====================================================
CREATE TABLE IF NOT EXISTS user_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    preferred_currency TEXT DEFAULT 'USD',
    email_notifications BOOLEAN DEFAULT true,
    push_notifications BOOLEAN DEFAULT true,
    smart_pause_alerts BOOLEAN DEFAULT true,
    screen_time_tracking BOOLEAN DEFAULT true,
    low_usage_threshold INTEGER DEFAULT 60, -- minutes per month
    referral_discount_used BOOLEAN DEFAULT false, -- tracks if 30% referral discount was consumed
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Migration: Add referral_discount_used column to existing user_settings table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_settings' AND column_name = 'referral_discount_used'
    ) THEN
        ALTER TABLE user_settings ADD COLUMN referral_discount_used BOOLEAN DEFAULT false;
    END IF;
END $$;

ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only see their own settings"
    ON user_settings FOR ALL
    USING (auth.uid() = user_id);

-- =====================================================
-- 7. CREATE SCREEN TIME SYNC TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS screen_time_data (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE CASCADE,
    app_bundle_id TEXT,
    usage_minutes INTEGER NOT NULL,
    date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE screen_time_data ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only see their own screen time"
    ON screen_time_data FOR ALL
    USING (auth.uid() = user_id);

-- =====================================================
-- 8. CREATE PAUSE HISTORY TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS pause_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE CASCADE,
    paused_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resumed_at TIMESTAMP WITH TIME ZONE,
    duration_days INTEGER,
    savings_amount DECIMAL(10,2),
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE pause_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only see their own pause history"
    ON pause_history FOR ALL
    USING (auth.uid() = user_id);

-- =====================================================
-- 9. CREATE REFERRAL CODES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS referral_codes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    referrer_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    conversions INTEGER DEFAULT 0,
    pending_conversions INTEGER DEFAULT 0,
    total_earnings DECIMAL(10,2) DEFAULT 0.00,
    is_eligible_for_free_pro BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see their own referral code
CREATE POLICY "Users can see their own referral code"
    ON referral_codes FOR SELECT
    USING (auth.uid() = referrer_user_id);

-- Policy: Users can insert their own referral code
CREATE POLICY "Users can insert their own referral code"
    ON referral_codes FOR INSERT
    WITH CHECK (auth.uid() = referrer_user_id);

-- Policy: Anyone can validate a referral code (needed for signup)
CREATE POLICY "Anyone can view referral codes for validation"
    ON referral_codes FOR SELECT
    USING (true);

CREATE INDEX IF NOT EXISTS idx_referral_codes_user_id ON referral_codes(referrer_user_id);
CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON referral_codes(code);

-- =====================================================
-- 10. CREATE REFERRAL CONVERSIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS referral_conversions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    referrer_code TEXT REFERENCES referral_codes(code) ON DELETE CASCADE,
    referred_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    referred_user_email TEXT,
    status TEXT DEFAULT 'pending', -- pending, converted, cancelled
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    converted_at TIMESTAMP WITH TIME ZONE
);

ALTER TABLE referral_conversions ENABLE ROW LEVEL SECURITY;

-- Policy: Referrers can see their conversions
CREATE POLICY "Referrers can see their conversions"
    ON referral_conversions FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM referral_codes 
        WHERE referral_codes.code = referral_conversions.referrer_code 
        AND referral_codes.referrer_user_id = auth.uid()
    ));

-- Policy: Users can see their own conversion record
CREATE POLICY "Users can see their own conversion"
    ON referral_conversions FOR SELECT
    USING (auth.uid() = referred_user_id);

CREATE INDEX IF NOT EXISTS idx_referral_conversions_code ON referral_conversions(referrer_code);
CREATE INDEX IF NOT EXISTS idx_referral_conversions_user ON referral_conversions(referred_user_id);

-- =====================================================
-- VERIFICATION
-- =====================================================
SELECT 'Subscriptions table created successfully' as status;
SELECT COUNT(*) as total_policies FROM pg_policies WHERE tablename = 'subscriptions';
SELECT COUNT(*) as referral_tables FROM information_schema.tables WHERE table_name IN ('referral_codes', 'referral_conversions');
