-- Pausely Mission Control - Database Schema
-- Run this in Supabase SQL Editor to set up admin analytics

-- ==================== ADMIN ACCESS ====================

-- Add is_admin column to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- Create function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = user_id AND is_admin = TRUE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== ANALYTICS TABLES ====================

-- Daily stats snapshot
CREATE TABLE IF NOT EXISTS daily_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date DATE NOT NULL UNIQUE,
    total_users INTEGER DEFAULT 0,
    new_users INTEGER DEFAULT 0,
    pro_users INTEGER DEFAULT 0,
    mrr DECIMAL(10,2) DEFAULT 0,
    total_revenue DECIMAL(10,2) DEFAULT 0,
    active_sessions INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Security logs for tracking threats
CREATE TABLE IF NOT EXISTS security_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL,
    level TEXT CHECK (level IN ('info', 'warning', 'danger')) DEFAULT 'info',
    message TEXT NOT NULL,
    user_id UUID REFERENCES profiles(id),
    ip_address TEXT,
    user_agent TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Activity log for audit trail
CREATE TABLE IF NOT EXISTS activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id),
    action TEXT NOT NULL,
    entity_type TEXT,
    entity_id TEXT,
    old_data JSONB,
    new_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- System events
CREATE TABLE IF NOT EXISTS system_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL,
    severity TEXT CHECK (severity IN ('info', 'warning', 'critical')) DEFAULT 'info',
    message TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resolved_at TIMESTAMP WITH TIME ZONE
);

-- Referral analytics
CREATE TABLE IF NOT EXISTS referral_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_id UUID REFERENCES profiles(id),
    referred_id UUID REFERENCES profiles(id),
    code_used TEXT,
    converted BOOLEAN DEFAULT FALSE,
    conversion_date TIMESTAMP WITH TIME ZONE,
    revenue_generated DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ==================== INDEXES ====================

CREATE INDEX IF NOT EXISTS idx_security_logs_created ON security_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_logs_level ON security_logs(level);
CREATE INDEX IF NOT EXISTS idx_activity_logs_user ON activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created ON activity_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_daily_stats_date ON daily_stats(date);
CREATE INDEX IF NOT EXISTS idx_referral_analytics_referrer ON referral_analytics(referrer_id);

-- ==================== REALTIME SETUP ====================

-- Enable realtime for security logs
ALTER PUBLICATION supabase_realtime ADD TABLE security_logs;

-- Enable realtime for activity logs
ALTER PUBLICATION supabase_realtime ADD TABLE activity_logs;

-- ==================== FUNCTIONS ====================

-- Function to log security events
CREATE OR REPLACE FUNCTION log_security_event(
    p_event_type TEXT,
    p_level TEXT,
    p_message TEXT,
    p_user_id UUID DEFAULT NULL,
    p_ip_address TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO security_logs (event_type, level, message, user_id, ip_address, metadata)
    VALUES (p_event_type, p_level, p_message, p_user_id, p_ip_address, p_metadata)
    RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to log activity
CREATE OR REPLACE FUNCTION log_activity(
    p_user_id UUID,
    p_action TEXT,
    p_entity_type TEXT DEFAULT NULL,
    p_entity_id TEXT DEFAULT NULL,
    p_old_data JSONB DEFAULT NULL,
    p_new_data JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO activity_logs (user_id, action, entity_type, entity_id, old_data, new_data)
    VALUES (p_user_id, p_action, p_entity_type, p_entity_id, p_old_data, p_new_data)
    RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to calculate daily stats
CREATE OR REPLACE FUNCTION calculate_daily_stats(p_date DATE DEFAULT CURRENT_DATE)
RETURNS VOID AS $$
BEGIN
    INSERT INTO daily_stats (date, total_users, new_users, pro_users, mrr)
    SELECT 
        p_date,
        (SELECT COUNT(*) FROM profiles),
        (SELECT COUNT(*) FROM profiles WHERE DATE(created_at) = p_date),
        (SELECT COUNT(*) FROM profiles WHERE subscription_tier = 'pro'),
        COALESCE((SELECT SUM(amount) FROM payments 
                  WHERE status = 'completed' 
                  AND DATE(created_at) = p_date), 0)
    ON CONFLICT (date) DO UPDATE SET
        total_users = EXCLUDED.total_users,
        new_users = EXCLUDED.new_users,
        pro_users = EXCLUDED.pro_users,
        mrr = EXCLUDED.mrr,
        created_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get dashboard stats
CREATE OR REPLACE FUNCTION get_dashboard_stats()
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'total_users', (SELECT COUNT(*) FROM profiles),
        'pro_users', (SELECT COUNT(*) FROM profiles WHERE subscription_tier = 'pro'),
        'today_signups', (SELECT COUNT(*) FROM profiles WHERE DATE(created_at) = CURRENT_DATE),
        'mrr', COALESCE((SELECT SUM(monthly_cost) FROM user_subscriptions WHERE status = 'active'), 0),
        'total_revenue', COALESCE((SELECT SUM(amount) FROM payments WHERE status = 'completed'), 0),
        'active_threats', (SELECT COUNT(*) FROM security_logs WHERE level = 'danger' AND created_at > NOW() - INTERVAL '24 hours'),
        'failed_logins_24h', (SELECT COUNT(*) FROM security_logs WHERE event_type = 'failed_login' AND created_at > NOW() - INTERVAL '24 hours')
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== TRIGGERS ====================

-- Trigger to auto-log profile changes
CREATE OR REPLACE FUNCTION log_profile_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        PERFORM log_activity(
            NEW.id,
            'profile_updated',
            'profile',
            NEW.id::TEXT,
            to_jsonb(OLD),
            to_jsonb(NEW)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_log_profile_changes ON profiles;
CREATE TRIGGER trigger_log_profile_changes
    AFTER UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION log_profile_changes();

-- Trigger to log failed logins (hook into auth)
CREATE OR REPLACE FUNCTION log_failed_auth()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.provider = 'email' AND NEW.created_at > NOW() - INTERVAL '1 second' THEN
        PERFORM log_security_event(
            'failed_login',
            'warning',
            'Failed login attempt',
            NEW.user_id,
            NULL,
            jsonb_build_object('provider', NEW.provider)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== ROW LEVEL SECURITY ====================

-- Enable RLS
ALTER TABLE security_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_analytics ENABLE ROW LEVEL SECURITY;

-- Only admins can read security logs
CREATE POLICY "Admins can read security logs" ON security_logs
    FOR SELECT USING (is_admin(auth.uid()));

-- Only admins can read activity logs
CREATE POLICY "Admins can read activity logs" ON activity_logs
    FOR SELECT USING (is_admin(auth.uid()));

-- Only admins can read stats
CREATE POLICY "Admins can read daily stats" ON daily_stats
    FOR SELECT USING (is_admin(auth.uid()));

-- Only admins can read system events
CREATE POLICY "Admins can read system events" ON system_events
    FOR SELECT USING (is_admin(auth.uid()));

-- Only admins can read referral analytics
CREATE POLICY "Admins can read referral analytics" ON referral_analytics
    FOR SELECT USING (is_admin(auth.uid()));

-- ==================== INITIAL DATA ====================

-- Insert first admin (replace with your user ID after first login)
-- UPDATE profiles SET is_admin = TRUE WHERE email = 'your-email@example.com';
