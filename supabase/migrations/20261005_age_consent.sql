-- Age consent record (minimum age 16).
-- We store ONLY that the user confirmed they meet the minimum age, when, and under which
-- policy/app version. We deliberately do NOT store the date of birth (data minimization).

ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS age_confirmed_at       TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS age_minimum_met        BOOLEAN,
    ADD COLUMN IF NOT EXISTS age_minimum_required   INTEGER,
    ADD COLUMN IF NOT EXISTS consent_policy_version TEXT,
    ADD COLUMN IF NOT EXISTS consent_app_version    TEXT;

-- A consent record may only ever say "minimum age met". Under-age attempts never create a row.
DO $$
BEGIN
    ALTER TABLE profiles
        ADD CONSTRAINT profiles_age_consent_consistent
        CHECK (
            (age_confirmed_at IS NULL AND age_minimum_met IS NULL)
            OR (age_confirmed_at IS NOT NULL AND age_minimum_met IS TRUE AND age_minimum_required >= 16)
        );
EXCEPTION WHEN duplicate_object THEN
    NULL;
END $$;

-- Existing RLS on profiles already limits SELECT/INSERT/UPDATE to auth.uid() = id,
-- so a user can only write their own consent record. No new policies needed.

-- Compliance helper: users who have not yet confirmed age (for monitoring the re-consent rollout).
CREATE OR REPLACE VIEW profiles_missing_age_consent AS
SELECT id, created_at
FROM profiles
WHERE age_confirmed_at IS NULL;

REVOKE ALL ON profiles_missing_age_consent FROM anon, authenticated;
