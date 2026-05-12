-- Add waitlist, affiliate tracking, and influencer attribution tables
-- This enables the waitlist-to-app attribution bridge for influencer campaigns

-- ============================================
-- AFFILIATES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS affiliates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    revenue_share_pct DECIMAL(5,2) NOT NULL DEFAULT 20.00,
    payment_method TEXT,
    payment_details TEXT,
    total_earnings DECIMAL(10,2) DEFAULT 0,
    total_conversions INTEGER DEFAULT 0,
    total_waitlist_signups INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_affiliates_code ON affiliates(code);
CREATE INDEX IF NOT EXISTS idx_affiliates_active ON affiliates(is_active);

-- RLS: Anyone can read (for code validation), service role manages writes
ALTER TABLE affiliates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view affiliates" ON affiliates;
CREATE POLICY "Anyone can view affiliates" ON affiliates FOR SELECT USING (true);

-- ============================================
-- WAITLIST TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS waitlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    affiliate_code TEXT REFERENCES affiliates(code) ON DELETE SET NULL,
    source TEXT DEFAULT 'waitlist',
    signed_up_at TIMESTAMPTZ DEFAULT NOW(),
    notified_at TIMESTAMPTZ,
    converted_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    converted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_waitlist_email ON waitlist(email);
CREATE INDEX IF NOT EXISTS idx_waitlist_affiliate ON waitlist(affiliate_code);
CREATE INDEX IF NOT EXISTS idx_waitlist_converted ON waitlist(converted_user_id);

-- RLS: Public can insert (for landing page), service role reads all
ALTER TABLE waitlist ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can insert waitlist" ON waitlist;
CREATE POLICY "Public can insert waitlist" ON waitlist FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Public can view own waitlist entry" ON waitlist;
CREATE POLICY "Public can view own waitlist entry" ON waitlist FOR SELECT USING (email = auth.email());

-- ============================================
-- AFFILIATE CONVERSIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS affiliate_conversions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    affiliate_id UUID NOT NULL REFERENCES affiliates(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    waitlist_id UUID REFERENCES waitlist(id) ON DELETE SET NULL,
    conversion_type TEXT NOT NULL,
    revenue_amount DECIMAL(10,2) NOT NULL,
    commission_amount DECIMAL(10,2) NOT NULL,
    commission_pct DECIMAL(5,2) NOT NULL,
    status TEXT DEFAULT 'pending',
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_affiliate_conversions_affiliate ON affiliate_conversions(affiliate_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_conversions_user ON affiliate_conversions(user_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_conversions_status ON affiliate_conversions(status);
CREATE INDEX IF NOT EXISTS idx_affiliate_conversions_created ON affiliate_conversions(created_at DESC);

-- RLS: Service role managed only
ALTER TABLE affiliate_conversions ENABLE ROW LEVEL SECURITY;

-- ============================================
-- PROFILES TABLE EXTENSIONS
-- ============================================
ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS affiliate_code TEXT,
    ADD COLUMN IF NOT EXISTS attributed_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_profiles_affiliate ON profiles(affiliate_code);

-- ============================================
-- TRIGGERS
-- ============================================
DROP TRIGGER IF EXISTS update_affiliates_updated_at ON affiliates;
CREATE TRIGGER update_affiliates_updated_at BEFORE UPDATE ON affiliates FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_waitlist_updated_at ON waitlist;
CREATE TRIGGER update_waitlist_updated_at BEFORE UPDATE ON waitlist FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_affiliate_conversions_updated_at ON affiliate_conversions;
CREATE TRIGGER update_affiliate_conversions_updated_at BEFORE UPDATE ON affiliate_conversions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- REALTIME
-- ============================================
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE affiliates;
EXCEPTION WHEN duplicate_object THEN
    NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE waitlist;
EXCEPTION WHEN duplicate_object THEN
    NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE affiliate_conversions;
EXCEPTION WHEN duplicate_object THEN
    NULL;
END $$;
