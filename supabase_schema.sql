-- Pausely App Supabase Schema
-- Run this in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- SUBSCRIPTIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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

-- Create indexes for subscriptions
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_category ON subscriptions(category);
CREATE INDEX IF NOT EXISTS idx_subscriptions_created_at ON subscriptions(created_at DESC);

-- Enable Row Level Security
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for subscriptions
CREATE POLICY "Users can view own subscriptions" 
    ON subscriptions FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own subscriptions" 
    ON subscriptions FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own subscriptions" 
    ON subscriptions FOR UPDATE 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own subscriptions" 
    ON subscriptions FOR DELETE 
    USING (auth.uid() = user_id);

-- Create trigger for updated_at
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

-- Create indexes for referral_codes
CREATE INDEX IF NOT EXISTS idx_referral_codes_user_id ON referral_codes(referrer_user_id);
CREATE INDEX IF NOT EXISTS idx_referral_codes_created_at ON referral_codes(created_at);

-- Enable Row Level Security
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for referral_codes
CREATE POLICY "Users can view own referral code" 
    ON referral_codes FOR SELECT 
    USING (auth.uid() = referrer_user_id);

CREATE POLICY "Users can insert own referral code" 
    ON referral_codes FOR INSERT 
    WITH CHECK (auth.uid() = referrer_user_id);

CREATE POLICY "Users can update own referral code" 
    ON referral_codes FOR UPDATE 
    USING (auth.uid() = referrer_user_id);

-- Allow public read for validating referral codes
CREATE POLICY "Anyone can view referral codes for validation" 
    ON referral_codes FOR SELECT 
    USING (true);

-- ============================================
-- REFERRAL CONVERSIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS referral_conversions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    referrer_code TEXT NOT NULL REFERENCES referral_codes(code) ON DELETE CASCADE,
    referred_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    referred_user_email TEXT,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    converted_at TIMESTAMPTZ
);

-- Create indexes for referral_conversions
CREATE INDEX IF NOT EXISTS idx_referral_conversions_code ON referral_conversions(referrer_code);
CREATE INDEX IF NOT EXISTS idx_referral_conversions_user_id ON referral_conversions(referred_user_id);
CREATE INDEX IF NOT EXISTS idx_referral_conversions_status ON referral_conversions(status);

-- Enable Row Level Security
ALTER TABLE referral_conversions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for referral_conversions
CREATE POLICY "Referrers can view own conversions" 
    ON referral_conversions FOR SELECT 
    USING (auth.uid() IN (
        SELECT referrer_user_id FROM referral_codes WHERE code = referrer_code
    ));

CREATE POLICY "System can insert conversions" 
    ON referral_conversions FOR INSERT 
    WITH CHECK (true);

CREATE POLICY "System can update conversions" 
    ON referral_conversions FOR UPDATE 
    USING (true);

-- ============================================
-- USER PROFILES TABLE (Optional but recommended)
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

-- Create indexes for user_profiles
CREATE INDEX IF NOT EXISTS idx_user_profiles_tier ON user_profiles(subscription_tier);

-- Enable Row Level Security
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for user_profiles
CREATE POLICY "Users can view own profile" 
    ON user_profiles FOR SELECT 
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" 
    ON user_profiles FOR UPDATE 
    USING (auth.uid() = id);

-- Create trigger for updated_at
CREATE TRIGGER update_user_profiles_updated_at 
    BEFORE UPDATE ON user_profiles 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- REALTIME SUBSCRIPTIONS (Enable realtime for live updates)
-- ============================================
-- Enable realtime for subscriptions table
BEGIN;
  -- Drop the publication if it exists
  DROP PUBLICATION IF EXISTS supabase_realtime;
  -- Create the publication
  CREATE PUBLICATION supabase_realtime;
COMMIT;

-- Add tables to realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE subscriptions;
ALTER PUBLICATION supabase_realtime ADD TABLE referral_codes;
ALTER PUBLICATION supabase_realtime ADD TABLE referral_conversions;

-- ============================================
-- SAMPLE DATA (Optional - for testing)
-- ============================================
-- Uncomment the following to insert sample data for testing

/*
-- Sample subscription (requires authenticated user)
INSERT INTO subscriptions (
    user_id, name, description, category, amount, currency, 
    billing_frequency, status, is_detected, can_pause
) VALUES (
    '00000000-0000-0000-0000-000000000000', -- Replace with actual user UUID
    'Netflix',
    'Standard streaming plan',
    'Entertainment',
    15.99,
    'USD',
    'monthly',
    'active',
    false,
    true
);

-- Sample referral code (requires authenticated user)
INSERT INTO referral_codes (
    code, referrer_user_id, conversions, pending_conversions, 
    total_earnings, is_eligible_for_free_pro
) VALUES (
    'PAUSELY-ABC123-DEF456',
    '00000000-0000-0000-0000-000000000000', -- Replace with actual user UUID
    0,
    0,
    0,
    false
);
*/

-- Print success message
SELECT 'Pausely schema created successfully!' AS message;
