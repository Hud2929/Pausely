-- Add tracked_trials table for trial protection feature
CREATE TABLE IF NOT EXISTS tracked_trials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    service_name TEXT NOT NULL,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    cost_after_trial DECIMAL(10, 2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    category TEXT DEFAULT 'Entertainment',
    status TEXT NOT NULL DEFAULT 'active',
    cancel_url TEXT,
    notes TEXT DEFAULT '',
    reminder_dates TIMESTAMPTZ[],
    has_been_reminded BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_tracked_trials_user_id ON tracked_trials(user_id);
CREATE INDEX IF NOT EXISTS idx_tracked_trials_status ON tracked_trials(status);
CREATE INDEX IF NOT EXISTS idx_tracked_trials_end_date ON tracked_trials(end_date);

-- RLS
ALTER TABLE tracked_trials ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own trials" ON tracked_trials;
CREATE POLICY "Users can view own trials" ON tracked_trials FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own trials" ON tracked_trials;
CREATE POLICY "Users can insert own trials" ON tracked_trials FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own trials" ON tracked_trials;
CREATE POLICY "Users can update own trials" ON tracked_trials FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own trials" ON tracked_trials;
CREATE POLICY "Users can delete own trials" ON tracked_trials FOR DELETE USING (auth.uid() = user_id);

-- Add updated_at trigger
DROP TRIGGER IF EXISTS update_tracked_trials_updated_at ON tracked_trials;
CREATE TRIGGER update_tracked_trials_updated_at BEFORE UPDATE ON tracked_trials FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add to realtime
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE tracked_trials;
EXCEPTION WHEN duplicate_object THEN
    NULL;
END $$;
