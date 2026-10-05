-- GDPR / CCPA Data Deletion Audit Trail
-- Records deletion requests for compliance — required by GDPR Art. 17 to demonstrate
-- that deletion was actioned within 30 days.

CREATE TABLE IF NOT EXISTS deletion_requests (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  email         text,                                    -- stored in case user_id is deleted first
  requested_at  timestamptz NOT NULL DEFAULT now(),
  source        text NOT NULL DEFAULT 'in_app'           -- 'in_app' | 'web_form' | 'email'
                CHECK (source IN ('in_app', 'web_form', 'email')),
  completed_at  timestamptz,
  notes         text
);

-- Only service-role can read deletion requests (admin use only)
ALTER TABLE deletion_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "No public access to deletion_requests"
  ON deletion_requests FOR ALL
  USING (false);

-- Index for compliance queries
CREATE INDEX idx_deletion_requests_requested_at ON deletion_requests (requested_at);
CREATE INDEX idx_deletion_requests_user_id ON deletion_requests (user_id);
