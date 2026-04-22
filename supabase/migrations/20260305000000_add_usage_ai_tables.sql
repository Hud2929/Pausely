-- Add Usage, AI Insights, and Alternatives tables
-- Align with documented schema

-- ============================================
-- USAGE SNAPSHOTS (historical usage data)
-- ============================================
CREATE TABLE IF NOT EXISTS usage_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    date DATE NOT NULL,
    week_number INTEGER,
    month INTEGER,
    year INTEGER,
    
    minutes_used INTEGER DEFAULT 0,
    app_launches INTEGER DEFAULT 0,
    screen_time_category TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_usage_snapshots_subscription ON usage_snapshots(subscription_id);
CREATE INDEX IF NOT EXISTS idx_usage_snapshots_user ON usage_snapshots(user_id);
CREATE INDEX IF NOT EXISTS idx_usage_snapshots_date ON usage_snapshots(date);

-- RLS
ALTER TABLE usage_snapshots ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own usage snapshots" ON usage_snapshots;
CREATE POLICY "Users can view own usage snapshots" ON usage_snapshots FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert own usage snapshots" ON usage_snapshots;
CREATE POLICY "Users can insert own usage snapshots" ON usage_snapshots FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update own usage snapshots" ON usage_snapshots;
CREATE POLICY "Users can update own usage snapshots" ON usage_snapshots FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can delete own usage snapshots" ON usage_snapshots;
CREATE POLICY "Users can delete own usage snapshots" ON usage_snapshots FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- USER DEVICES (for Screen Time sync)
-- ============================================
CREATE TABLE IF NOT EXISTS user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    device_name TEXT,
    device_model TEXT,
    os_version TEXT,
    last_sync_at TIMESTAMPTZ,
    
    -- Screen Time authorization
    screen_time_enabled BOOLEAN DEFAULT FALSE,
    screen_time_token TEXT, -- encrypted
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_devices_user ON user_devices(user_id);

-- RLS
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own devices" ON user_devices;
CREATE POLICY "Users can view own devices" ON user_devices FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert own devices" ON user_devices;
CREATE POLICY "Users can insert own devices" ON user_devices FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update own devices" ON user_devices;
CREATE POLICY "Users can update own devices" ON user_devices FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can delete own devices" ON user_devices;
CREATE POLICY "Users can delete own devices" ON user_devices FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- AI INSIGHTS LOG (track AI recommendations)
-- ============================================
CREATE TABLE IF NOT EXISTS ai_insights_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
    
    insight_type TEXT NOT NULL, -- 'unused', 'price_increase', 'alternative', 'usage_warning'
    insight_text TEXT NOT NULL,
    confidence_score INTEGER, -- 0-100
    
    action_taken TEXT, -- 'ignored', 'cancelled', 'paused', 'kept'
    user_feedback TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_ai_insights_user ON ai_insights_log(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_insights_subscription ON ai_insights_log(subscription_id);
CREATE INDEX IF NOT EXISTS idx_ai_insights_type ON ai_insights_log(insight_type);

-- RLS
ALTER TABLE ai_insights_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own ai insights" ON ai_insights_log;
CREATE POLICY "Users can view own ai insights" ON ai_insights_log FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "System can insert ai insights" ON ai_insights_log;
CREATE POLICY "System can insert ai insights" ON ai_insights_log FOR INSERT WITH CHECK (true);

-- ============================================
-- ALTERNATIVES (for AI recommendations)
-- ============================================
CREATE TABLE IF NOT EXISTS alternatives (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    source_subscription_name TEXT NOT NULL, -- e.g., "Netflix"
    source_category TEXT NOT NULL,
    
    alternative_name TEXT NOT NULL,
    alternative_url TEXT,
    alternative_cost DECIMAL(10, 2),
    alternative_billing_cycle TEXT,
    alternative_logo_url TEXT,
    
    is_free BOOLEAN DEFAULT FALSE,
    is_cheaper BOOLEAN DEFAULT FALSE,
    savings_amount DECIMAL(10, 2),
    
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_alternatives_source_name ON alternatives(source_subscription_name);
CREATE INDEX IF NOT EXISTS idx_alternatives_category ON alternatives(source_category);

-- RLS - Alternatives are read-only for users (managed by system)
ALTER TABLE alternatives ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view alternatives" ON alternatives;
CREATE POLICY "Anyone can view alternatives" ON alternatives FOR SELECT USING (true);

-- ============================================
-- UPDATE SUBSCRIPTIONS TABLE (add missing columns)
-- ============================================
-- Add usage tracking columns if they don't exist
ALTER TABLE subscriptions 
    ADD COLUMN IF NOT EXISTS app_bundle_id TEXT,
    ADD COLUMN IF NOT EXISTS website_url TEXT,
    ADD COLUMN IF NOT EXISTS tags TEXT[],
    ADD COLUMN IF NOT EXISTS start_date DATE,
    ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS ai_usage_insight TEXT,
    ADD COLUMN IF NOT EXISTS ai_recommendation TEXT,
    ADD COLUMN IF NOT EXISTS ai_alternatives JSONB;

-- Rename amount to cost if needed (align with documentation)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'subscriptions' AND column_name = 'amount'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'subscriptions' AND column_name = 'cost'
    ) THEN
        ALTER TABLE subscriptions RENAME COLUMN amount TO cost;
    END IF;
END $$;

-- ============================================
-- UPDATE PROFILES TABLE (add missing columns)
-- ============================================
ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS email TEXT,
    ADD COLUMN IF NOT EXISTS full_name TEXT,
    ADD COLUMN IF NOT EXISTS avatar_url TEXT,
    ADD COLUMN IF NOT EXISTS subscription_count_limit INTEGER DEFAULT 5,
    ADD COLUMN IF NOT EXISTS notification_days_before_renewal INTEGER DEFAULT 3,
    ADD COLUMN IF NOT EXISTS enable_usage_tracking BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS enable_ai_insights BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS screen_time_connected BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS bank_connected BOOLEAN DEFAULT FALSE;

-- Rename display_name to full_name if needed
ALTER TABLE profiles 
    ALTER COLUMN display_name DROP NOT NULL;

-- ============================================
-- DATABASE FUNCTIONS
-- ============================================

-- Function to calculate monthly spend
CREATE OR REPLACE FUNCTION calculate_monthly_spend(p_user_id UUID)
RETURNS DECIMAL(10, 2) AS $$
DECLARE
    monthly_total DECIMAL(10, 2) := 0;
BEGIN
    SELECT COALESCE(SUM(
        CASE 
            WHEN billing_frequency = 'weekly' THEN cost * 4.33
            WHEN billing_frequency = 'monthly' THEN cost
            WHEN billing_frequency = 'quarterly' THEN cost / 3
            WHEN billing_frequency = 'yearly' THEN cost / 12
            ELSE cost
        END
    ), 0) INTO monthly_total
    FROM subscriptions
    WHERE user_id = p_user_id 
      AND status = 'active' 
      AND (paused_until IS NULL OR paused_until < NOW());
    
    RETURN monthly_total;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update profile on subscription change
CREATE OR REPLACE FUNCTION update_subscription_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE profiles
    SET updated_at = NOW()
    WHERE id = COALESCE(NEW.user_id, OLD.user_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_subscription_change ON subscriptions;
CREATE TRIGGER on_subscription_change
    AFTER INSERT OR UPDATE OR DELETE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_subscription_count();

-- ============================================
-- REALTIME - Add new tables
-- ============================================
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE usage_snapshots;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE ai_insights_log;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================
-- SEED DATA - Popular alternatives
-- ============================================
INSERT INTO alternatives (source_subscription_name, source_category, alternative_name, alternative_url, alternative_cost, alternative_billing_cycle, is_free, is_cheaper, savings_amount, description) VALUES
-- Entertainment
('Netflix', 'entertainment', 'Hulu (with ads)', 'https://www.hulu.com', 7.99, 'monthly', false, true, 7.50, 'Cheaper streaming with ads'),
('Netflix', 'entertainment', 'Peacock', 'https://www.peacocktv.com', 5.99, 'monthly', false, true, 9.50, 'NBC content at lower price'),
('Netflix', 'entertainment', 'Tubi', 'https://tubitv.com', 0, 'monthly', true, true, 15.49, 'Free ad-supported streaming'),
('Spotify', 'entertainment', 'Apple Music Voice', 'https://music.apple.com', 4.99, 'monthly', false, true, 5.00, 'Voice-controlled music'),
('Spotify', 'entertainment', 'YouTube Music (free)', 'https://music.youtube.com', 0, 'monthly', true, true, 9.99, 'Free tier with ads'),
('Spotify', 'entertainment', 'Pandora (free)', 'https://www.pandora.com', 0, 'monthly', true, true, 9.99, 'Free ad-supported radio'),

-- Productivity
('Notion', 'productivity', 'Obsidian', 'https://obsidian.md', 0, 'monthly', true, true, 10.00, 'Free for personal use, one-time purchase'),
('Notion', 'productivity', 'Standard Notes', 'https://standardnotes.com', 0, 'monthly', true, true, 10.00, 'Free encrypted notes'),
('Adobe Creative Cloud', 'productivity', 'Affinity Suite', 'https://affinity.serif.com', 69.99, 'one-time', false, true, 50.00, 'One-time purchase vs subscription'),
('Adobe Creative Cloud', 'productivity', 'GIMP + Inkscape', 'https://www.gimp.org', 0, 'monthly', true, true, 54.99, 'Free open-source alternatives'),

-- Fitness
('Peloton', 'fitness', 'Apple Fitness+', 'https://fitness.apple.com', 9.99, 'monthly', false, true, 35.00, 'Lower cost fitness'),
('Peloton', 'fitness', 'Nike Training Club', 'https://www.nike.com/ntc', 0, 'monthly', true, true, 44.99, 'Free workout app'),
('Peloton', 'fitness', 'Down Dog', 'https://www.downdogapp.com', 7.99, 'monthly', false, true, 37.00, 'Lower cost yoga/fitness'),

-- Wellness
('Headspace', 'wellness', 'Insight Timer', 'https://insighttimer.com', 0, 'monthly', true, true, 12.99, 'Free meditation library'),
('Headspace', 'wellness', 'UCLA Mindful', 'https://mindful.ucla.edu', 0, 'monthly', true, true, 12.99, 'Free from UCLA'),
('Calm', 'wellness', 'MyLife Meditation', 'https://my.life', 0, 'monthly', true, true, 14.99, 'Free meditation app'),

-- Utilities
('1Password', 'utilities', 'Bitwarden', 'https://bitwarden.com', 0, 'monthly', true, true, 3.99, 'Free password manager'),
('LastPass', 'utilities', 'Bitwarden', 'https://bitwarden.com', 0, 'monthly', true, true, 3.00, 'Free secure alternative'),
('Dropbox', 'utilities', 'Google Drive (15GB free)', 'https://drive.google.com', 0, 'monthly', true, true, 9.99, 'Generous free tier'),
('Dropbox', 'utilities', 'pCloud', 'https://www.pcloud.com', 4.99, 'monthly', false, true, 5.00, 'Lower cost storage'),

-- News
('NYTimes', 'news', 'AP News', 'https://apnews.com', 0, 'monthly', true, true, 17.00, 'Free news source'),
('Washington Post', 'news', 'NPR', 'https://www.npr.org', 0, 'monthly', true, true, 12.00, 'Free quality journalism'),
('Apple News+', 'news', 'Feedly (free)', 'https://feedly.com', 0, 'monthly', true, true, 9.99, 'Free RSS reader'),

-- Education
('MasterClass', 'education', 'Khan Academy', 'https://www.khanacademy.org', 0, 'monthly', true, true, 15.00, 'Free education platform'),
('Skillshare', 'education', 'YouTube', 'https://www.youtube.com', 0, 'monthly', true, true, 13.99, 'Free tutorials on everything'),
('Duolingo Plus', 'education', 'Duolingo (free)', 'https://www.duolingo.com', 0, 'monthly', true, true, 6.99, 'Use free tier with ads'),
('Coursera Plus', 'education', 'edX (audit free)', 'https://www.edx.org', 0, 'monthly', true, true, 59.00, 'Audit courses for free');
