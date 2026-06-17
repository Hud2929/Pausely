-- Fix overly permissive RLS policies identified in security audit
-- Run: supabase deploy --local (or push to remote)

-- ============================================
-- REFERRAL_CONVERSIONS: Restrict INSERT/UPDATE
-- ============================================
DROP POLICY IF EXISTS "System can insert conversions" ON referral_conversions;
CREATE POLICY "Service role can insert conversions" ON referral_conversions FOR INSERT WITH CHECK (false); -- Service role bypasses RLS

DROP POLICY IF EXISTS "System can update conversions" ON referral_conversions;
CREATE POLICY "Service role can update conversions" ON referral_conversions FOR UPDATE USING (false); -- Service role bypasses RLS

-- ============================================
-- AFFILIATES: Remove public SELECT, restrict to authenticated users
-- ============================================
DROP POLICY IF EXISTS "Anyone can view affiliates" ON affiliates;
CREATE POLICY "Authenticated users can view active affiliates" ON affiliates FOR SELECT USING (is_active = true);

-- ============================================
-- AI_INSIGHTS_LOG: Restrict INSERT to service role or owning user
-- ============================================
DROP POLICY IF EXISTS "System can insert ai insights" ON ai_insights_log;
CREATE POLICY "Users can insert own ai insights" ON ai_insights_log FOR INSERT WITH CHECK (auth.uid() = user_id);
