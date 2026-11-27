// Revokes the tokens Apple issued to Pausely for a person who is deleting their account.
//
// Apple asks apps that offer Sign in with Apple to do this when an account is deleted
// (developer.apple.com/support/offering-account-deletion-in-your-app). The app has the person confirm
// with Apple, which yields a one-time authorization code (valid five minutes). This function exchanges
// that code for a refresh token and revokes it at once. Nothing is stored, and nothing is logged but
// the kind of failure.
//
// Security:
// - Verifies the caller's Supabase session AND requires an explicit Apple identity with subject (`sub`).
//   Never fails open when `identities` or `appleSub` is missing.
// - Enforces a per-user rate limit (max 5/hour, persistent via Postgres RPC when service_role is set,
//   with a bounded in-memory fallback) to prevent spamming Apple's token endpoints with Team credentials.
// - Validates Apple's exchanged id_token (`iss`, `aud`, and `sub === caller.appleSub`) before revoking.
//
// Secrets (set with `supabase secrets set`): APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY (the text
// of the Sign in with Apple .p8 key) and APPLE_CLIENT_ID (the app's bundle id). Until they are set the
// function answers 503 and the app goes on to delete the account.
// Tested by scripts/dbtest/apple_revoke_function.sh.

import { drainResponse, readBoundedText } from '../_shared/http.ts'

const TEAM_ID = Deno.env.get('APPLE_TEAM_ID') ?? ''
const KEY_ID = Deno.env.get('APPLE_KEY_ID') ?? ''
const PRIVATE_KEY = Deno.env.get('APPLE_PRIVATE_KEY') ?? ''
const CLIENT_ID = Deno.env.get('APPLE_CLIENT_ID') ?? ''
const APPLE_URL = Deno.env.get('APPLE_ID_URL') ?? 'https://appleid.apple.com'
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const CLIENT_SECRET_LIFETIME_SECONDS = 5 * 60
const MAX_BODY_BYTES = 4096
const MAX_REVOKES_PER_HOUR = positiveInt(Deno.env.get('APPLE_REVOKE_MAX_PER_HOUR'), 5)
const RATE_LIMIT_WINDOW_SECONDS = 3600

function positiveInt(value: string | undefined, fallback: number): number {
  const parsed = Number.parseInt(value ?? '', 10)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback
}

const answer = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

const base64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
const text = (value: string) => new TextEncoder().encode(value)

/// The client secret Apple asks for: a JWT signed with the Sign in with Apple key (ES256), naming the
/// team as issuer and the app as subject. Made for each request and valid for five minutes.
async function clientSecret(now = Math.floor(Date.now() / 1000)): Promise<string> {
  const pem = PRIVATE_KEY.replace(/\\n/g, '\n')
  const der = Uint8Array.from(atob(pem.replace(/-----[A-Z ]+-----/g, '').replace(/\s+/g, '')), (c) => c.charCodeAt(0))
  const key = await crypto.subtle.importKey('pkcs8', der, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'])
  const header = base64url(text(JSON.stringify({ alg: 'ES256', kid: KEY_ID })))
  const claims = base64url(text(JSON.stringify({
    iss: TEAM_ID, iat: now, exp: now + CLIENT_SECRET_LIFETIME_SECONDS, aud: 'https://appleid.apple.com', sub: CLIENT_ID,
  })))
  const signature = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, text(`${header}.${claims}`))
  return `${header}.${claims}.${base64url(new Uint8Array(signature))}`
}

const form = (fields: Record<string, string>) => ({
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams(fields).toString(),
  signal: AbortSignal.timeout(10_000),
})

// MARK: Per-user rate limit (DB-backed via consume_rate_limit RPC with bounded in-memory fallback)

const localLimits = new Map<string, { count: number; resetAt: number }>()
const LOCAL_LIMIT_MAX_KEYS = 2_000

function consumeLocalRateLimit(userId: string): boolean {
  const now = Date.now()
  if (localLimits.size >= LOCAL_LIMIT_MAX_KEYS) {
    for (const [k, v] of localLimits) {
      if (now > v.resetAt) localLimits.delete(k)
    }
    while (localLimits.size >= LOCAL_LIMIT_MAX_KEYS) {
      const oldest = localLimits.keys().next().value
      if (oldest === undefined) break
      localLimits.delete(oldest)
    }
  }
  const entry = localLimits.get(userId)
  if (!entry || now > entry.resetAt) {
    localLimits.set(userId, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_SECONDS * 1000 })
    return true
  }
  if (entry.count >= MAX_REVOKES_PER_HOUR) return false
  entry.count++
  return true
}

async function allowRevokeForUser(userId: string): Promise<boolean> {
  if (SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY) {
    try {
      const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/consume_rate_limit`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        },
        signal: AbortSignal.timeout(5_000),
        body: JSON.stringify({
          p_key: `apple-revoke:${userId}`,
          p_max_hits: MAX_REVOKES_PER_HOUR,
          p_window_seconds: RATE_LIMIT_WINDOW_SECONDS,
        }),
      })
      if (res.ok) {
        const allowed = await res.json()
        return allowed === true
      }
      await drainResponse(res)
    } catch {
      // Fall back to isolate-local throttle on transient RPC failure rather than blocking legitimate deletion.
    }
  }
  return consumeLocalRateLimit(userId)
}

interface VerifiedCaller {
  userId: string
  appleSub: string | null
  hasAppleIdentity: boolean
}

/// Returns the caller's verified Supabase account and Sign in with Apple subject, or null if not signed in.
async function verifiedCaller(request: Request): Promise<VerifiedCaller | null> {
  const authorization = request.headers.get('Authorization') ?? ''
  if (!authorization.toLowerCase().startsWith('bearer ') || !SUPABASE_URL) return null
  try {
    const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { Authorization: authorization, apikey: SUPABASE_ANON_KEY },
      signal: AbortSignal.timeout(10_000),
    })
    if (!response.ok) {
      await drainResponse(response)
      return null
    }
    const user = await response.json()
    if (typeof user?.id !== 'string' || user.id.length === 0) return null
    const identities = Array.isArray(user.identities) ? user.identities : []
    const apple = identities.find((i: Record<string, unknown>) => i?.provider === 'apple') as Record<string, unknown> | undefined
    const identityData = apple?.identity_data as Record<string, unknown> | undefined
    const appleSub = typeof apple?.id === 'string' && apple.id.length > 0
      ? apple.id
      : (typeof identityData?.sub === 'string' && identityData.sub.length > 0
        ? identityData.sub
        : null)
    return {
      userId: user.id,
      appleSub,
      hasAppleIdentity: apple !== undefined,
    }
  } catch {
    return null
  }
}

function validatedAppleIdTokenSub(token: unknown, expectedClientId: string): string | null {
  if (typeof token !== 'string') return null
  const parts = token.split('.')
  if (parts.length !== 3) return null
  try {
    const norm = parts[1].replace(/-/g, '+').replace(/_/g, '/')
    const pad = norm.length % 4 === 0 ? '' : '='.repeat(4 - (norm.length % 4))
    const payload = JSON.parse(atob(norm + pad))
    if (!payload || typeof payload !== 'object') return null
    if (payload.iss !== 'https://appleid.apple.com') return null
    const aud = payload.aud
    const audMatches = aud === expectedClientId || (Array.isArray(aud) && aud.includes(expectedClientId))
    if (!audMatches) return null
    return typeof payload.sub === 'string' && payload.sub.length > 0 ? payload.sub : null
  } catch {
    return null
  }
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return answer(405, { error: 'method_not_allowed' })
  const caller = await verifiedCaller(request)
  if (!caller) return answer(401, { error: 'not_signed_in' })

  // Fail closed: require an explicit Sign in with Apple identity and non-empty Apple subject.
  if (!caller.hasAppleIdentity || !caller.appleSub) {
    return answer(403, { error: 'not_apple_account' })
  }

  const rawBody = await readBoundedText(request, MAX_BODY_BYTES)
  if (rawBody === null) return answer(413, { error: 'payload_too_large' })

  let code: unknown
  try {
    code = JSON.parse(rawBody)?.code
  } catch {
    return answer(400, { error: 'bad_request' })
  }
  if (typeof code !== 'string' || code.length === 0 || code.length > 2048) return answer(400, { error: 'bad_request' })
  if (!TEAM_ID || !KEY_ID || !PRIVATE_KEY || !CLIENT_ID) return answer(503, { error: 'not_configured' })

  if (!(await allowRevokeForUser(caller.userId))) {
    return answer(429, { error: 'rate_limited' })
  }

  try {
    const secret = await clientSecret()
    const exchange = await fetch(`${APPLE_URL}/auth/token`, form({
      client_id: CLIENT_ID, client_secret: secret, code, grant_type: 'authorization_code',
    }))
    if (!exchange.ok) {
      await drainResponse(exchange)
      console.error(`apple-revoke: the code was not accepted (${exchange.status})`)
      return answer(502, { error: 'code_not_accepted' })
    }
    const tokenPayload = await exchange.json()
    const refreshToken = tokenPayload?.refresh_token
    if (typeof refreshToken !== 'string' || refreshToken.length === 0) return answer(502, { error: 'no_token' })

    // Bind the exchanged Apple id_token issuer, audience, and subject strictly to the caller's Apple identity.
    const exchangedSub = validatedAppleIdTokenSub(tokenPayload?.id_token, CLIENT_ID)
    if (!exchangedSub || exchangedSub !== caller.appleSub) {
      return answer(403, { error: 'identity_mismatch' })
    }

    const revoke = await fetch(`${APPLE_URL}/auth/revoke`, form({
      client_id: CLIENT_ID, client_secret: secret, token: refreshToken, token_type_hint: 'refresh_token',
    }))
    await drainResponse(revoke)
    if (!revoke.ok) {
      console.error(`apple-revoke: the token was not revoked (${revoke.status})`)
      return answer(502, { error: 'not_revoked' })
    }
    return answer(200, { revoked: true })
  } catch (error) {
    console.error(`apple-revoke: ${error instanceof Error ? error.name : 'error'}`)
    return answer(502, { error: 'failed' })
  }
})
