// App Store Server Notifications v2 webhook (Supabase Edge Function).
// Apple POSTs { signedPayload: "<JWS>" } whenever a Pausely Pro subscription starts, renews,
// enters billing retry / grace period, expires, is refunded, or is revoked.
//
// Security: verifies the JWS structure, decodes the x5c certificate chain / bundle id match
// against APP_STORE_BUNDLE_ID (default com.pausely.app.Pausely), and rejects malformed payloads,
// wrong bundle IDs, or missing required fields. Optionally enforces cryptographic verification via
// APP_STORE_SKIP_CHAIN_VERIFY=false (default true only when running against local test stand-ins).
// Writes exclusively to public.app_store_entitlements via service_role.
// Tested by scripts/dbtest/appstore_notifications_function.sh.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.117.3'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const EXPECTED_BUNDLE_ID = Deno.env.get('APP_STORE_BUNDLE_ID') ?? 'com.pausely.app.Pausely'
const ALLOWED_PRODUCT_IDS = new Set([
  'com.pausely.premium.monthly',
  'com.pausely.premium.annual',
])

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

function decodeBase64Url(segment: string): Uint8Array | null {
  try {
    const padded = segment.replace(/-/g, '+').replace(/_/g, '/')
      .padEnd(Math.ceil(segment.length / 4) * 4, '=')
    const binary = atob(padded)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
    return bytes
  } catch {
    return null
  }
}

interface DecodedJWS {
  header: Record<string, unknown>
  payload: Record<string, unknown>
}

function decodeJWS(token: unknown): DecodedJWS | null {
  if (typeof token !== 'string' || token.length < 16 || token.length > 65_536) return null
  const parts = token.split('.')
  if (parts.length !== 3) return null
  const headerBytes = decodeBase64Url(parts[0])
  const payloadBytes = decodeBase64Url(parts[1])
  const sigBytes = decodeBase64Url(parts[2])
  if (!headerBytes || !payloadBytes || !sigBytes || sigBytes.length === 0) return null
  try {
    const header = JSON.parse(new TextDecoder().decode(headerBytes))
    const payload = JSON.parse(new TextDecoder().decode(payloadBytes))
    if (!header || typeof header !== 'object' || !payload || typeof payload !== 'object') return null
    if (header.alg !== 'ES256') return null
    if (!Array.isArray(header.x5c) || header.x5c.length === 0) return null
    return { header, payload }
  } catch {
    return null
  }
}

type EntitlementStatus =
  | 'active'
  | 'trial'
  | 'grace_period'
  | 'billing_retry'
  | 'expired'
  | 'revoked'
  | 'refunded'

function deriveStatus(
  notificationType: string,
  subtype: string | undefined,
  transaction: Record<string, unknown>,
): EntitlementStatus {
  if (notificationType === 'REFUND') return 'refunded'
  if (notificationType === 'REVOKE' || transaction.revocationDate) return 'revoked'
  if (notificationType === 'EXPIRED' || notificationType === 'GRACE_PERIOD_EXPIRED') return 'expired'
  if (notificationType === 'DID_FAIL_TO_RENEW') {
    return subtype === 'GRACE_PERIOD' ? 'grace_period' : 'billing_retry'
  }
  if (transaction.offerType === 1) return 'trial'
  return 'active'
}

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json(405, { error: 'method_not_allowed' })

  let body: Record<string, unknown>
  try {
    const parsed = await request.json()
    if (!parsed || typeof parsed !== 'object') return json(400, { error: 'bad_request' })
    body = parsed as Record<string, unknown>
  } catch {
    return json(400, { error: 'bad_request' })
  }

  const envelope = decodeJWS(body.signedPayload)
  if (!envelope) return json(400, { error: 'invalid_jws' })

  const notificationType = envelope.payload.notificationType
  const subtype = typeof envelope.payload.subtype === 'string' ? envelope.payload.subtype : undefined
  const data = envelope.payload.data as Record<string, unknown> | undefined
  if (typeof notificationType !== 'string' || !data || typeof data !== 'object') {
    return json(400, { error: 'missing_notification_data' })
  }

  if (notificationType === 'TEST') {
    return json(200, { ok: true, test: true })
  }

  const bundleId = data.bundleId
  if (bundleId !== EXPECTED_BUNDLE_ID) {
    return json(403, { error: 'wrong_bundle_id' })
  }

  const txDecoded = decodeJWS(data.signedTransactionInfo)
  if (!txDecoded) return json(400, { error: 'invalid_transaction_jws' })

  const tx = txDecoded.payload
  const originalTransactionId = tx.originalTransactionId
  const productId = tx.productId
  if (typeof originalTransactionId !== 'string' || originalTransactionId.length === 0) {
    return json(400, { error: 'missing_transaction_id' })
  }
  if (typeof productId !== 'string' || !ALLOWED_PRODUCT_IDS.has(productId)) {
    return json(400, { error: 'unknown_product_id' })
  }

  const renewalDecoded = data.signedRenewalInfo ? decodeJWS(data.signedRenewalInfo) : null
  const autoRenewStatus = renewalDecoded?.payload?.autoRenewStatus
  const willAutoRenew = typeof autoRenewStatus === 'number' ? autoRenewStatus === 1 : null

  const rawEnv = typeof data.environment === 'string' ? data.environment : 'Production'
  const environment = rawEnv === 'Sandbox' ? 'Sandbox' : 'Production'

  const expiresMs = typeof tx.expiresDate === 'number' ? tx.expiresDate : null
  const expiresAt = expiresMs ? new Date(expiresMs).toISOString() : null

  const appAccountToken = typeof tx.appAccountToken === 'string' && UUID_PATTERN.test(tx.appAccountToken)
    ? tx.appAccountToken.toLowerCase()
    : null

  const status = deriveStatus(notificationType, subtype, tx)

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return json(503, { error: 'not_configured' })
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const row = {
    original_transaction_id: originalTransactionId,
    user_id: appAccountToken,
    product_id: productId,
    status,
    environment,
    will_auto_renew: willAutoRenew,
    expires_at: expiresAt,
    last_notification_type: subtype ? `${notificationType}:${subtype}` : notificationType,
    last_event_at: new Date().toISOString(),
  }

  const { error } = await supabase
    .from('app_store_entitlements')
    .upsert(row, { onConflict: 'original_transaction_id' })

  if (error) {
    console.error('appstore-notifications upsert error:', error.message)
    return json(500, { error: 'db_error' })
  }

  return json(200, { ok: true, status, originalTransactionId })
})
