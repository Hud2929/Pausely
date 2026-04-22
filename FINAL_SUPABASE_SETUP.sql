-- ================================================================================
-- PAUSELY SUPABASE DATABASE SETUP
-- Production-Ready SQL Schema for Pausely iOS App
-- ================================================================================
-- 
-- DESCRIPTION:
-- This script sets up the complete database schema for the Pausely subscription
-- management app. It includes all tables, indexes, RLS policies, triggers, and
-- functions needed for production deployment.
--
-- FEATURES:
-- - Idempotent (safe to run multiple times)
-- - Row Level Security (RLS) enabled on all tables
-- - Comprehensive indexes for performance
-- - Auto-updating timestamps via triggers
-- - Database functions for business logic
--
-- TABLES:
-- - subscriptions: User subscription data
-- - referral_codes: Referral system tracking
-- - referral_conversions: Referral conversion records
-- - user_settings: User preferences and configuration
-- - screen_time_data: App usage tracking for ROI calculations
-- - pause_history: Historical pause records
--
-- RUN INSTRUCTIONS:
-- 1. Go to https://supabase.com/dashboard
-- 2. Select your Pausely project
-- 3. Navigate to SQL Editor
-- 4. Paste this entire file
-- 5. Click "Run"
--
-- ================================================================================

-- ================================================================================
-- SECTION 1: EXTENSIONS AND UTILITIES
-- ================================================================================

-- Enable UUID extension for generating unique identifiers
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================================================================================
-- SECTION 2: HELPER FUNCTIONS
-- ================================================================================

-- Function: Auto-update updated_at timestamp
-- This function is used by triggers to automatically update the updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION update_updated_at_column() IS 
'Trigger function to automatically update the updated_at timestamp on row modifications';

-- ================================================================================
-- SECTION 3: SUBSCRIPTIONS TABLE
-- ================================================================================

-- Drop existing objects if recreating (for development purposes)
DROP TRIGGER IF EXISTS update_subscriptions_updated_at ON subscriptions;
DROP TABLE IF EXISTS subscriptions CASCADE;

-- Main subscriptions table
-- Stores all user subscription information including billing details,
-- usage tracking, and pause status
CREATE TABLE subscriptions (
    -- Primary identifier
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- User relationship (links to Supabase Auth)
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Basic subscription info
    name TEXT NOT NULL CHECK (LENGTH(TRIM(name)) > 0),
    description TEXT,
    logo_url TEXT,
    category TEXT,
    
    -- Financial details
    amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
    currency TEXT NOT NULL DEFAULT 'USD' CHECK (currency ~ '^[A-Z]{3}$'),
    billing_frequency TEXT NOT NULL DEFAULT 'monthly' 
        CHECK (billing_frequency IN ('monthly', 'yearly', 'weekly', 'quarterly')),
    next_billing_date DATE,
    
    -- Usage and ROI tracking
    monthly_usage_minutes INTEGER NOT NULL DEFAULT 0 CHECK (monthly_usage_minutes >= 0),
    cost_per_hour DECIMAL(10,4),
    roi_score DECIMAL(5,2) CHECK (roi_score >= 0 AND roi_score <= 100),
    
    -- Status and control
    status TEXT NOT NULL DEFAULT 'active' 
        CHECK (status IN ('active', 'paused', 'cancelled', 'trial', 'expired')),
    is_detected BOOLEAN NOT NULL DEFAULT false,
    can_pause BOOLEAN NOT NULL DEFAULT true,
    pause_url TEXT,
    paused_until DATE,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT valid_pause_date CHECK (paused_until IS NULL OR paused_until > created_at::DATE)
);

-- Add table comment
COMMENT ON TABLE subscriptions IS 'Stores user subscription information including billing, usage tracking, and pause status';

-- Add column comments
COMMENT ON COLUMN subscriptions.id IS 'Unique identifier for the subscription';
COMMENT ON COLUMN subscriptions.user_id IS 'Reference to the Supabase Auth user who owns this subscription';
COMMENT ON COLUMN subscriptions.monthly_usage_minutes IS 'Minutes of usage per month for ROI calculations';
COMMENT ON COLUMN subscriptions.cost_per_hour IS 'Calculated cost per hour of usage';
COMMENT ON COLUMN subscriptions.roi_score IS 'ROI score from 0-100 based on usage vs cost';
COMMENT ON COLUMN subscriptions.status IS 'Current status: active, paused, cancelled, trial, or expired';
COMMENT ON COLUMN subscriptions.can_pause IS 'Whether this subscription supports pausing';
COMMENT ON COLUMN subscriptions.paused_until IS 'Date when pause expires (NULL if not paused)';

-- Enable Row Level Security
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for subscriptions

-- Policy: Users can only view their own subscriptions
CREATE POLICY "Users can view own subscriptions"
    ON subscriptions FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Users can only insert their own subscriptions
CREATE POLICY "Users can insert own subscriptions"
    ON subscriptions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only update their own subscriptions
CREATE POLICY "Users can update own subscriptions"
    ON subscriptions FOR UPDATE
    USING (auth.uid() = user_id);

-- Policy: Users can only delete their own subscriptions
CREATE POLICY "Users can delete own subscriptions"
    ON subscriptions FOR DELETE
    USING (auth.uid() = user_id);

-- Trigger: Auto-update updated_at
CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Indexes for subscriptions
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_category ON subscriptions(category);
CREATE INDEX IF NOT EXISTS idx_subscriptions_billing_date ON subscriptions(next_billing_date);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_status ON subscriptions(user_id, status);

-- ================================================================================
-- SECTION 4: REFERRAL CODES TABLE
-- ================================================================================

-- Drop existing objects
DROP TRIGGER IF EXISTS update_referral_codes_updated_at ON referral_codes;
DROP TABLE IF EXISTS referral_codes CASCADE;

-- Referral codes table
-- Tracks referral codes and conversion statistics for each referrer
CREATE TABLE referral_codes (
    -- Primary identifier
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- The actual referral code (unique, uppercase)
    code TEXT UNIQUE NOT NULL CHECK (code ~ '^[A-Z0-9]{6,12}$'),
    
    -- Referrer relationship
    referrer_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Conversion statistics
    conversions INTEGER NOT NULL DEFAULT 0 CHECK (conversions >= 0),
    pending_conversions INTEGER NOT NULL DEFAULT 0 CHECK (pending_conversions >= 0),
    total_earnings DECIMAL(10,2) NOT NULL DEFAULT 0.00 CHECK (total_earnings >= 0),
    
    -- Free Pro eligibility (3+ conversions = free Pro)
    is_eligible_for_free_pro BOOLEAN NOT NULL DEFAULT false,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Constraint: pending cannot exceed total (conversions + pending)
    CONSTRAINT valid_pending_conversions CHECK (
        pending_conversions <= (conversions + pending_conversions)
    )
);

-- Add table comment
COMMENT ON TABLE referral_codes IS 'Stores referral codes and conversion statistics for the referral program';

-- Add column comments
COMMENT ON COLUMN referral_codes.code IS 'Unique 6-12 character uppercase alphanumeric referral code';
COMMENT ON COLUMN referral_codes.conversions IS 'Number of successful conversions (paid referrals)';
COMMENT ON COLUMN referral_codes.pending_conversions IS 'Number of pending conversions (signed up but not paid)';
COMMENT ON COLUMN referral_codes.total_earnings IS 'Total earnings from referrals in currency units';
COMMENT ON COLUMN referral_codes.is_eligible_for_free_pro IS 'True when user has 3+ conversions, qualifies for free Pro';

-- Enable Row Level Security
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;

-- RLS Policies for referral_codes

-- Policy: Users can view their own referral code
CREATE POLICY "Users can view own referral code"
    ON referral_codes FOR SELECT
    USING (auth.uid() = referrer_user_id);

-- Policy: Anyone can validate a referral code (needed for signup)
-- This allows unauthenticated users to check if a code is valid
CREATE POLICY "Anyone can view referral codes for validation"
    ON referral_codes FOR SELECT
    USING (true);

-- Policy: Users can insert their own referral code
CREATE POLICY "Users can insert own referral code"
    ON referral_codes FOR INSERT
    WITH CHECK (auth.uid() = referrer_user_id);

-- Policy: Users can update their own referral code
-- Note: Typically conversions are updated via database functions, not direct updates
CREATE POLICY "Users can update own referral code"
    ON referral_codes FOR UPDATE
    USING (auth.uid() = referrer_user_id);

-- Policy: Users can delete their own referral code
CREATE POLICY "Users can delete own referral code"
    ON referral_codes FOR DELETE
    USING (auth.uid() = referrer_user_id);

-- Trigger: Auto-update updated_at
CREATE TRIGGER update_referral_codes_updated_at
    BEFORE UPDATE ON referral_codes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Indexes for referral_codes
CREATE INDEX IF NOT EXISTS idx_referral_codes_user_id ON referral_codes(referrer_user_id);
CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON referral_codes(code);
CREATE INDEX IF NOT EXISTS idx_referral_codes_eligible ON referral_codes(is_eligible_for_free_pro) 
    WHERE is_eligible_for_free_pro = true;

-- ================================================================================
-- SECTION 5: REFERRAL CONVERSIONS TABLE
-- ================================================================================

-- Drop existing objects
DROP TABLE IF EXISTS referral_conversions CASCADE;

-- Referral conversions table
-- Tracks who referred whom and the status of each conversion
CREATE TABLE referral_conversions (
    -- Primary identifier
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- Referral relationship
    referrer_code TEXT NOT NULL REFERENCES referral_codes(code) ON DELETE CASCADE,
    referred_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    referred_user_email TEXT,
    
    -- Conversion status
    status TEXT NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'converted', 'cancelled')),
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    converted_at TIMESTAMP WITH TIME ZONE,
    
    -- Constraint: converted_at only when status is 'converted'
    CONSTRAINT valid_conversion_date CHECK (
        (status = 'converted' AND converted_at IS NOT NULL) OR
        (status != 'converted' AND converted_at IS NULL)
    ),
    
    -- Unique constraint: one user can only be referred once
    UNIQUE(referred_user_id)
);

-- Add table comment
COMMENT ON TABLE referral_conversions IS 'Tracks referral conversions linking referrers to referred users';

-- Add column comments
COMMENT ON COLUMN referral_conversions.referrer_code IS 'The referral code used';
COMMENT ON COLUMN referral_conversions.referred_user_id IS 'User who was referred';
COMMENT ON COLUMN referral_conversions.status IS 'Conversion status: pending, converted, or cancelled';
COMMENT ON COLUMN referral_conversions.converted_at IS 'Timestamp when conversion completed (payment received)';

-- Enable Row Level Security
ALTER TABLE referral_conversions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for referral_conversions

-- Policy: Referrers can view their conversions
CREATE POLICY "Referrers can view their conversions"
    ON referral_conversions FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM referral_codes 
        WHERE referral_codes.code = referral_conversions.referrer_code 
        AND referral_codes.referrer_user_id = auth.uid()
    ));

-- Policy: Users can view their own conversion record
CREATE POLICY "Users can view own conversion"
    ON referral_conversions FOR SELECT
    USING (auth.uid() = referred_user_id);

-- Policy: Referrers can insert conversions (for their code)
CREATE POLICY "Referrers can insert conversions"
    ON referral_conversions FOR INSERT
    WITH CHECK (EXISTS (
        SELECT 1 FROM referral_codes 
        WHERE referral_codes.code = referral_conversions.referrer_code 
        AND referral_codes.referrer_user_id = auth.uid()
    ));

-- Indexes for referral_conversions
CREATE INDEX IF NOT EXISTS idx_referral_conversions_code ON referral_conversions(referrer_code);
CREATE INDEX IF NOT EXISTS idx_referral_conversions_user ON referral_conversions(referred_user_id);
CREATE INDEX IF NOT EXISTS idx_referral_conversions_status ON referral_conversions(status);
CREATE INDEX IF NOT EXISTS idx_referral_conversions_code_status ON referral_conversions(referrer_code, status);

-- ================================================================================
-- SECTION 6: USER SETTINGS TABLE
-- ================================================================================

-- Drop existing objects
DROP TRIGGER IF EXISTS update_user_settings_updated_at ON user_settings;
DROP TABLE IF EXISTS user_settings CASCADE;

-- User settings table
-- Stores user preferences and app configuration
CREATE TABLE user_settings (
    -- Primary identifier (user_id is the primary key - one settings per user)
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Currency preference
    preferred_currency TEXT NOT NULL DEFAULT 'USD' CHECK (preferred_currency ~ '^[A-Z]{3}$'),
    
    -- Notification preferences
    email_notifications BOOLEAN NOT NULL DEFAULT true,
    push_notifications BOOLEAN NOT NULL DEFAULT true,
    smart_pause_alerts BOOLEAN NOT NULL DEFAULT true,
    
    -- Feature preferences
    screen_time_tracking BOOLEAN NOT NULL DEFAULT true,
    low_usage_threshold INTEGER NOT NULL DEFAULT 60 CHECK (low_usage_threshold > 0),
    
    -- Referral discount tracking
    referral_discount_used BOOLEAN NOT NULL DEFAULT false, -- tracks if 30% referral discount was consumed
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Add table comment
COMMENT ON TABLE user_settings IS 'Stores user preferences and app configuration settings';

-- Add column comments
COMMENT ON COLUMN user_settings.preferred_currency IS 'Default currency for displaying amounts (ISO 4217 code)';
COMMENT ON COLUMN user_settings.email_notifications IS 'Whether user wants to receive email notifications';
COMMENT ON COLUMN user_settings.push_notifications IS 'Whether user wants to receive push notifications';
COMMENT ON COLUMN user_settings.smart_pause_alerts IS 'Whether to show smart pause suggestions';
COMMENT ON COLUMN user_settings.screen_time_tracking IS 'Whether to enable automatic screen time tracking';
COMMENT ON COLUMN user_settings.low_usage_threshold IS 'Minutes per month below which to suggest pausing (default 60)';
COMMENT ON COLUMN user_settings.referral_discount_used IS 'Whether the user has consumed their 30% referral discount (first month only)';

-- Enable Row Level Security
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_settings

-- Policy: Users can only view their own settings
CREATE POLICY "Users can view own settings"
    ON user_settings FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Users can only insert their own settings
CREATE POLICY "Users can insert own settings"
    ON user_settings FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only update their own settings
CREATE POLICY "Users can update own settings"
    ON user_settings FOR UPDATE
    USING (auth.uid() = user_id);

-- Policy: Users can only delete their own settings
CREATE POLICY "Users can delete own settings"
    ON user_settings FOR DELETE
    USING (auth.uid() = user_id);

-- Trigger: Auto-update updated_at
CREATE TRIGGER update_user_settings_updated_at
    BEFORE UPDATE ON user_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Indexes for user_settings
CREATE INDEX IF NOT EXISTS idx_user_settings_user_id ON user_settings(user_id);

-- ================================================================================
-- SECTION 7: SCREEN TIME DATA TABLE (Optional Extension)
-- ================================================================================

-- Drop existing objects
DROP TABLE IF EXISTS screen_time_data CASCADE;

-- Screen time data table
-- Tracks detailed app usage for ROI calculations
CREATE TABLE screen_time_data (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE CASCADE,
    app_bundle_id TEXT,
    usage_minutes INTEGER NOT NULL CHECK (usage_minutes >= 0),
    date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Add table comment
COMMENT ON TABLE screen_time_data IS 'Tracks detailed screen time usage for ROI calculations';

-- Enable Row Level Security
ALTER TABLE screen_time_data ENABLE ROW LEVEL SECURITY;

-- RLS Policies for screen_time_data
CREATE POLICY "Users can view own screen time"
    ON screen_time_data FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own screen time"
    ON screen_time_data FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own screen time"
    ON screen_time_data FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own screen time"
    ON screen_time_data FOR DELETE
    USING (auth.uid() = user_id);

-- Indexes for screen_time_data
CREATE INDEX IF NOT EXISTS idx_screen_time_user ON screen_time_data(user_id);
CREATE INDEX IF NOT EXISTS idx_screen_time_subscription ON screen_time_data(subscription_id);
CREATE INDEX IF NOT EXISTS idx_screen_time_date ON screen_time_data(date);

-- ================================================================================
-- SECTION 8: PAUSE HISTORY TABLE (Optional Extension)
-- ================================================================================

-- Drop existing objects
DROP TABLE IF EXISTS pause_history CASCADE;

-- Pause history table
-- Tracks historical pause events for analytics
CREATE TABLE pause_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE CASCADE,
    paused_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    resumed_at TIMESTAMP WITH TIME ZONE,
    duration_days INTEGER CHECK (duration_days > 0),
    savings_amount DECIMAL(10,2) CHECK (savings_amount >= 0),
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Constraint: resumed_at must be after paused_at
    CONSTRAINT valid_pause_duration CHECK (
        resumed_at IS NULL OR resumed_at > paused_at
    )
);

-- Add table comment
COMMENT ON TABLE pause_history IS 'Tracks historical pause events for analytics and reporting';

-- Enable Row Level Security
ALTER TABLE pause_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies for pause_history
CREATE POLICY "Users can view own pause history"
    ON pause_history FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own pause history"
    ON pause_history FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own pause history"
    ON pause_history FOR UPDATE
    USING (auth.uid() = user_id);

-- Indexes for pause_history
CREATE INDEX IF NOT EXISTS idx_pause_history_user ON pause_history(user_id);
CREATE INDEX IF NOT EXISTS idx_pause_history_subscription ON pause_history(subscription_id);
CREATE INDEX IF NOT EXISTS idx_pause_history_paused_at ON pause_history(paused_at);

-- ================================================================================
-- SECTION 9: BUSINESS LOGIC FUNCTIONS
-- ================================================================================

-- Function: Check if user has reached free tier subscription limit
-- Returns: BOOLEAN - true if user has 3 or more active subscriptions
CREATE OR REPLACE FUNCTION check_free_tier_limit(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    subscription_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO subscription_count
    FROM subscriptions
    WHERE user_id = p_user_id
      AND status IN ('active', 'trial', 'paused');
    
    RETURN subscription_count >= 3;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION check_free_tier_limit(UUID) IS 
'Checks if a user has reached the free tier limit of 3 active subscriptions';

-- Function: Get user's subscription count
-- Returns: INTEGER - number of active subscriptions for the user
CREATE OR REPLACE FUNCTION get_user_subscription_count(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    count INTEGER;
BEGIN
    SELECT COUNT(*) INTO count
    FROM subscriptions
    WHERE user_id = p_user_id
      AND status IN ('active', 'trial', 'paused');
    
    RETURN count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_user_subscription_count(UUID) IS 
'Returns the number of active/trial/paused subscriptions for a user';

-- Function: Increment referral conversion
-- Safely increments the conversions count for a referral code
CREATE OR REPLACE FUNCTION increment_referral_conversion(p_code TEXT, p_earnings DECIMAL DEFAULT 5.00)
RETURNS VOID AS $$
DECLARE
    current_conversions INTEGER;
BEGIN
    -- Update the referral code record
    UPDATE referral_codes
    SET 
        conversions = conversions + 1,
        pending_conversions = GREATEST(pending_conversions - 1, 0),
        total_earnings = total_earnings + p_earnings,
        is_eligible_for_free_pro = CASE 
            WHEN (conversions + 1) >= 3 THEN true 
            ELSE is_eligible_for_free_pro 
        END,
        updated_at = NOW()
    WHERE code = p_code;
    
    -- Check if code exists
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Referral code not found: %', p_code;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION increment_referral_conversion(TEXT, DECIMAL) IS 
'Increments conversion count for a referral code, updates earnings, and checks for free Pro eligibility';

-- Function: Apply referral code for new user
-- Creates a conversion record when a new user signs up with a referral code
CREATE OR REPLACE FUNCTION apply_referral_code(p_code TEXT, p_user_id UUID, p_email TEXT DEFAULT NULL)
RETURNS BOOLEAN AS $$
DECLARE
    code_exists BOOLEAN;
    already_referred BOOLEAN;
BEGIN
    -- Check if code exists
    SELECT EXISTS(SELECT 1 FROM referral_codes WHERE code = UPPER(p_code)) INTO code_exists;
    
    IF NOT code_exists THEN
        RETURN false;
    END IF;
    
    -- Check if user was already referred by someone
    SELECT EXISTS(SELECT 1 FROM referral_conversions WHERE referred_user_id = p_user_id) INTO already_referred;
    
    IF already_referred THEN
        RETURN false;
    END IF;
    
    -- Insert conversion record
    INSERT INTO referral_conversions (referrer_code, referred_user_id, referred_user_email, status)
    VALUES (UPPER(p_code), p_user_id, p_email, 'pending');
    
    -- Update pending conversions on referral code
    UPDATE referral_codes
    SET pending_conversions = pending_conversions + 1,
        updated_at = NOW()
    WHERE code = UPPER(p_code);
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION apply_referral_code(TEXT, UUID, TEXT) IS 
'Applies a referral code for a new user signup, creates conversion record';

-- Function: Validate referral code
-- Returns: BOOLEAN - true if code is valid
CREATE OR REPLACE FUNCTION validate_referral_code(p_code TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS(SELECT 1 FROM referral_codes WHERE code = UPPER(p_code));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION validate_referral_code(TEXT) IS 
'Validates that a referral code exists (case-insensitive)';

-- Function: Calculate cost per hour for a subscription
-- Updates the cost_per_hour and roi_score columns based on usage
CREATE OR REPLACE FUNCTION calculate_subscription_roi(p_subscription_id UUID)
RETURNS VOID AS $$
DECLARE
    sub_record RECORD;
    monthly_cost DECIMAL;
    cost_hour DECIMAL;
    roi DECIMAL;
BEGIN
    -- Get subscription details
    SELECT * INTO sub_record
    FROM subscriptions
    WHERE id = p_subscription_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Subscription not found: %', p_subscription_id;
    END IF;
    
    -- Calculate monthly cost
    CASE sub_record.billing_frequency
        WHEN 'monthly' THEN monthly_cost := sub_record.amount;
        WHEN 'yearly' THEN monthly_cost := sub_record.amount / 12;
        WHEN 'quarterly' THEN monthly_cost := sub_record.amount / 3;
        WHEN 'weekly' THEN monthly_cost := sub_record.amount * 4.33;
        ELSE monthly_cost := sub_record.amount;
    END CASE;
    
    -- Calculate cost per hour
    IF sub_record.monthly_usage_minutes > 0 THEN
        cost_hour := (monthly_cost * 60) / sub_record.monthly_usage_minutes;
        
        -- Calculate ROI score (0-100, higher is better)
        -- Lower cost per hour = higher ROI
        roi := GREATEST(0, LEAST(100, 100 - (cost_hour * 10)));
    ELSE
        cost_hour := NULL;
        roi := 0;
    END IF;
    
    -- Update subscription
    UPDATE subscriptions
    SET cost_per_hour = cost_hour,
        roi_score = roi,
        updated_at = NOW()
    WHERE id = p_subscription_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION calculate_subscription_roi(UUID) IS 
'Calculates cost per hour and ROI score for a subscription based on usage data';

-- ================================================================================
-- SECTION 10: TRIGGER FUNCTION FOR NEW USER SETUP
-- ================================================================================

-- Function: Create default settings for new users
-- Automatically called when a new user signs up
CREATE OR REPLACE FUNCTION handle_new_user_signup()
RETURNS TRIGGER AS $$
BEGIN
    -- Create default user settings
    INSERT INTO user_settings (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on auth.users for new user setup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user_signup();

COMMENT ON FUNCTION handle_new_user_signup() IS 
'Automatically creates default settings record when a new user signs up';

-- ================================================================================
-- SECTION 11: VERIFICATION AND TEST QUERIES
-- ================================================================================

-- The following queries can be used to verify the setup
-- Uncomment to run after executing this script

/*
-- List all created tables
SELECT table_name, 
       (SELECT COUNT(*) FROM information_schema.columns c WHERE c.table_name = t.table_name) as column_count
FROM information_schema.tables t
WHERE table_schema = 'public'
  AND table_name IN ('subscriptions', 'referral_codes', 'referral_conversions', 
                     'user_settings', 'screen_time_data', 'pause_history')
ORDER BY table_name;

-- List all RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- List all indexes on our tables
SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('subscriptions', 'referral_codes', 'referral_conversions', 
                    'user_settings', 'screen_time_data', 'pause_history')
ORDER BY tablename, indexname;

-- List all triggers
SELECT trigger_name, event_object_table, action_timing, event_manipulation, action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- List all functions
SELECT routine_name, routine_type, data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN ('update_updated_at_column', 'check_free_tier_limit', 
                       'get_user_subscription_count', 'increment_referral_conversion',
                       'apply_referral_code', 'validate_referral_code', 
                       'calculate_subscription_roi', 'handle_new_user_signup')
ORDER BY routine_name;

-- Test: Check RLS is enabled on all tables
SELECT relname, relrowsecurity 
FROM pg_class 
WHERE relname IN ('subscriptions', 'referral_codes', 'referral_conversions', 
                  'user_settings', 'screen_time_data', 'pause_history');
*/

-- ================================================================================
-- SECTION 12: GRANT PERMISSIONS (For service role and authenticated users)
-- ================================================================================

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- Grant table permissions
GRANT ALL ON subscriptions TO authenticated;
GRANT ALL ON referral_codes TO authenticated;
GRANT ALL ON referral_conversions TO authenticated;
GRANT ALL ON user_settings TO authenticated;
GRANT ALL ON screen_time_data TO authenticated;
GRANT ALL ON pause_history TO authenticated;

-- Grant sequence permissions (for UUID generation)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ================================================================================
-- SETUP COMPLETE
-- ================================================================================

-- Output success message
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'PAUSELY DATABASE SETUP COMPLETE!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Tables created:';
    RAISE NOTICE '  - subscriptions';
    RAISE NOTICE '  - referral_codes';
    RAISE NOTICE '  - referral_conversions';
    RAISE NOTICE '  - user_settings';
    RAISE NOTICE '  - screen_time_data (optional)';
    RAISE NOTICE '  - pause_history (optional)';
    RAISE NOTICE '';
    RAISE NOTICE 'Features enabled:';
    RAISE NOTICE '  - Row Level Security (RLS)';
    RAISE NOTICE '  - Auto-updating timestamps';
    RAISE NOTICE '  - Comprehensive indexes';
    RAISE NOTICE '  - Database functions';
    RAISE NOTICE '  - New user auto-setup';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '  1. Verify tables in Supabase Table Editor';
    RAISE NOTICE '  2. Test with the Pausely iOS app';
    RAISE NOTICE '  3. Configure LemonSqueezy for payments';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;
