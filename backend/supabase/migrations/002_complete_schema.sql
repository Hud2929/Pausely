-- Complete Pausely Database Schema
-- Run this in Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- User Profiles Table
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    full_name TEXT,
    currency_preference TEXT DEFAULT 'USD',
    total_saved DECIMAL(10,2) DEFAULT 0,
    subscription_count INTEGER DEFAULT 0,
    plan_type TEXT DEFAULT 'free', -- 'free' or 'pro'
    lemonsqueezy_customer_id TEXT,
    lemonsqueezy_subscription_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Subscriptions Table
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    category TEXT NOT NULL,
    status TEXT DEFAULT 'active', -- 'active', 'paused', 'cancelled'
    renewal_date DATE,
    billing_cycle TEXT DEFAULT 'monthly', -- 'monthly', 'yearly', 'weekly'
    website_url TEXT,
    description TEXT,
    logo_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Cancellation Requests Table
CREATE TABLE IF NOT EXISTS cancellation_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
    service_name TEXT NOT NULL,
    status TEXT DEFAULT 'drafting', -- 'drafting', 'sent', 'negotiating', 'cancelled', 'saved'
    email_content TEXT,
    company_response TEXT,
    final_status TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Pause History Table
CREATE TABLE IF NOT EXISTS pause_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    paused_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resumed_at TIMESTAMP WITH TIME ZONE,
    amount_saved DECIMAL(10,2) DEFAULT 0
);

-- AI Insights Table
CREATE TABLE IF NOT EXISTS ai_insights (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL, -- 'savings', 'perk', 'reminder', 'tip', 'cancellation'
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    amount DECIMAL(10,2),
    is_read BOOLEAN DEFAULT FALSE,
    action_taken BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE cancellation_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE pause_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_insights ENABLE ROW LEVEL SECURITY;

-- Create policies for user_profiles
CREATE POLICY "Users can view own profile"
    ON user_profiles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile"
    ON user_profiles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
    ON user_profiles FOR UPDATE
    USING (auth.uid() = user_id);

-- Create policies for subscriptions
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

-- Create policies for cancellation_requests
CREATE POLICY "Users can view own cancellation requests"
    ON cancellation_requests FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own cancellation requests"
    ON cancellation_requests FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own cancellation requests"
    ON cancellation_requests FOR UPDATE
    USING (auth.uid() = user_id);

-- Create policies for pause_history
CREATE POLICY "Users can view own pause history"
    ON pause_history FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own pause history"
    ON pause_history FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Create policies for ai_insights
CREATE POLICY "Users can view own insights"
    ON ai_insights FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update own insights"
    ON ai_insights FOR UPDATE
    USING (auth.uid() = user_id);

-- Function to update user profile stats
CREATE OR REPLACE FUNCTION update_user_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Update subscription count
    UPDATE user_profiles 
    SET subscription_count = (
        SELECT COUNT(*) FROM subscriptions 
        WHERE user_id = COALESCE(NEW.user_id, OLD.user_id)
        AND status = 'active'
    ),
    updated_at = NOW()
    WHERE user_id = COALESCE(NEW.user_id, OLD.user_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger to update stats on subscription changes
DROP TRIGGER IF EXISTS update_stats_on_subscription_change ON subscriptions;
CREATE TRIGGER update_stats_on_subscription_change
    AFTER INSERT OR UPDATE OR DELETE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_user_stats();

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_profiles (user_id, email, full_name)
    VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to create profile on signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_cancellation_requests_user_id ON cancellation_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_insights_user_id ON ai_insights(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);
