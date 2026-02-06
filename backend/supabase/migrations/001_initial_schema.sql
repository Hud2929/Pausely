-- Pausely Database Schema
-- Supabase PostgreSQL

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT UNIQUE,
    full_name TEXT,
    avatar_url TEXT,
    onboarding_completed BOOLEAN DEFAULT FALSE,
    total_monthly_spend DECIMAL(10,2) DEFAULT 0,
    total_annual_spend DECIMAL(10,2) DEFAULT 0,
    potential_savings DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW())
);

-- Bank Connections (Plaid or similar)
CREATE TABLE IF NOT EXISTS public.bank_connections (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    institution_name TEXT NOT NULL,
    institution_id TEXT,
    access_token TEXT, -- Encrypted
    item_id TEXT,
    status TEXT DEFAULT 'active', -- active, disconnected, error
    last_sync_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW())
);

-- Subscriptions detected from bank transactions
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    bank_connection_id UUID REFERENCES public.bank_connections(id) ON DELETE SET NULL,
    
    -- Basic Info
    name TEXT NOT NULL,
    description TEXT,
    logo_url TEXT,
    category TEXT, -- streaming, productivity, fitness, etc.
    
    -- Financial
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT DEFAULT 'USD',
    billing_frequency TEXT NOT NULL, -- monthly, yearly, weekly
    next_billing_date DATE,
    
    -- Usage tracking
    monthly_usage_minutes INTEGER DEFAULT 0,
    cost_per_hour DECIMAL(10,4),
    roi_score DECIMAL(3,2), -- 0.00 to 1.00
    
    -- Status
    status TEXT DEFAULT 'active', -- active, paused, cancelled, trial
    is_detected BOOLEAN DEFAULT TRUE, -- auto-detected vs manually added
    
    -- Pause functionality
    can_pause BOOLEAN DEFAULT FALSE,
    pause_url TEXT,
    paused_until DATE,
    
    -- Meta
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW())
);

-- Free Perks (what users have access to)
CREATE TABLE IF NOT EXISTS public.user_perks (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    
    -- Perk source
    source_type TEXT NOT NULL, -- credit_card, employer, library, insurance, etc.
    source_name TEXT NOT NULL, -- "Chase Sapphire Reserve", "Company Inc", "NY Public Library"
    
    -- What they get
    perk_name TEXT NOT NULL, -- "DashPass", "Calm Premium", "Kanopy"
    service_category TEXT,
    estimated_value DECIMAL(10,2),
    
    -- Activation
    activation_url TEXT,
    activation_code TEXT,
    is_activated BOOLEAN DEFAULT FALSE,
    activated_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW())
);

-- Perk Opportunities (subscriptions they pay for that they could get free)
CREATE TABLE IF NOT EXISTS public.perk_opportunities (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE CASCADE,
    user_perk_id UUID REFERENCES public.user_perks(id) ON DELETE CASCADE,
    
    savings_amount DECIMAL(10,2),
    is_dismissed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW())
);

-- Pause History
CREATE TABLE IF NOT EXISTS public.pause_history (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE CASCADE,
    
    paused_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()),
    resumed_at TIMESTAMP WITH TIME ZONE,
    intended_duration_days INTEGER,
    actual_savings DECIMAL(10,2),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW())
);

-- Screen Time (imported from device)
CREATE TABLE IF NOT EXISTS public.screen_time (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE CASCADE,
    
    app_name TEXT,
    date DATE NOT NULL,
    usage_minutes INTEGER NOT NULL,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW())
);

-- Known Subscription Database (for auto-detection)
CREATE TABLE IF NOT EXISTS public.subscription_catalog (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    logo_url TEXT,
    category TEXT,
    website_url TEXT,
    
    -- Pause info
    can_pause BOOLEAN DEFAULT FALSE,
    pause_instructions TEXT,
    pause_url TEXT,
    
    -- Free alternatives
    free_alternatives JSONB, -- [{"name": "...", "url": "..."}]
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW())
);

-- Row Level Security Policies

-- Profiles: Users can only see their own profile
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- Subscriptions: Users can only see their own subscriptions
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own subscriptions" ON public.subscriptions
    FOR ALL USING (auth.uid() = user_id);

-- Bank Connections
ALTER TABLE public.bank_connections ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own bank connections" ON public.bank_connections
    FOR ALL USING (auth.uid() = user_id);

-- User Perks
ALTER TABLE public.user_perks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own perks" ON public.user_perks
    FOR ALL USING (auth.uid() = user_id);

-- Perk Opportunities
ALTER TABLE public.perk_opportunities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own opportunities" ON public.perk_opportunities
    FOR ALL USING (auth.uid() = user_id);

-- Pause History
ALTER TABLE public.pause_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own pause history" ON public.pause_history
    FOR ALL USING (auth.uid() = user_id);

-- Screen Time
ALTER TABLE public.screen_time ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own screen time" ON public.screen_time
    FOR ALL USING (auth.uid() = user_id);

-- Catalog is public read-only
ALTER TABLE public.subscription_catalog ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Catalog is public readable" ON public.subscription_catalog
    FOR SELECT USING (true);

-- Functions

-- Update total spend on subscription change
CREATE OR REPLACE FUNCTION public.update_user_spend()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.profiles
    SET 
        total_monthly_spend = (
            SELECT COALESCE(SUM(amount), 0) 
            FROM public.subscriptions 
            WHERE user_id = NEW.user_id 
            AND status = 'active'
            AND billing_frequency = 'monthly'
        ),
        total_annual_spend = (
            SELECT COALESCE(SUM(
                CASE 
                    WHEN billing_frequency = 'yearly' THEN amount
                    WHEN billing_frequency = 'monthly' THEN amount * 12
                    ELSE amount * 52 / 12
                END
            ), 0)
            FROM public.subscriptions 
            WHERE user_id = NEW.user_id 
            AND status = 'active'
        ),
        updated_at = TIMEZONE('utc'::TEXT, NOW())
    WHERE id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_spend_on_subscription_change
    AFTER INSERT OR UPDATE OR DELETE ON public.subscriptions
    FOR EACH ROW EXECUTE FUNCTION public.update_user_spend();

-- Calculate cost per hour
CREATE OR REPLACE FUNCTION public.calculate_cost_per_hour()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.monthly_usage_minutes > 0 THEN
        NEW.cost_per_hour := NEW.amount / (NEW.monthly_usage_minutes::DECIMAL / 60);
    ELSE
        NEW.cost_per_hour := NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER calculate_cost_per_hour_trigger
    BEFORE INSERT OR UPDATE ON public.subscriptions
    FOR EACH ROW EXECUTE FUNCTION public.calculate_cost_per_hour();
