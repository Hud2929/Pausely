-- Allow service role to update profiles.is_pro for admin-granted lifetime access.
-- The existing user-facing RLS policies remain unchanged (users can only edit their own row).
-- This policy lets the service role (used only from the Supabase dashboard or trusted server)
-- update any profile's is_pro / pro_tier fields.

DROP POLICY IF EXISTS "Service role can update any profile" ON profiles;
CREATE POLICY "Service role can update any profile" ON profiles
    FOR UPDATE
    TO service_role
    USING (true)
    WITH CHECK (true);
