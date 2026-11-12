// Revokes the tokens Apple issued to Pausely for a person who is deleting their account.
//
// Apple asks apps that offer Sign in with Apple to do this when an account is deleted
// (developer.apple.com/support/offering-account-deletion-in-your-app). The app has the person confirm
// with Apple, which yields a one-time authorization code (valid five minutes). This function exchanges
// that code for a refresh token and revokes it at once. Nothing is stored, and nothing is logged but
// the kind of failure.
//
// Only a signed-in person can call it: the caller's session is checked with the account service before
// Apple is asked anything, so the function cannot be used to try codes.
//
// Secrets (set with `supabase secrets set`): APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY (the text
// of the Sign in with Apple .p8 key) and APPLE_CLIENT_ID (the app's bundle id). Until they are set the
// function answers 503 and the app goes on to delete the account.
// Tested by scripts/dbtest/apple_revoke_function.sh.

const TEAM_ID = Deno.env.get('APPLE_TEAM_ID') ?? ''
const KEY_ID = Deno.env.get('APPLE_KEY_ID') ?? ''
const PRIVATE_KEY = Deno.env.get('APPLE_PRIVATE_KEY') ?? ''
const CLIENT_ID = Deno.env.get('APPLE_CLIENT_ID') ?? ''
const APPLE_URL = Deno.env.get('APPLE_ID_URL') ?? 'https://appleid.apple.com'
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
const CLIENT_SECRET_LIFETIME_SECONDS = 5 * 60

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
})

/// True when the caller holds a session of this project (not merely its public key).
async function isSignedIn(request: Request): Promise<boolean> {
  const authorization = request.headers.get('Authorization') ?? ''
  if (!authorization.toLowerCase().startsWith('bearer ') || !SUPABASE_URL) return false
  try {
    const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { Authorization: authorization, apikey: SUPABASE_ANON_KEY },
    })
    if (!response.ok) return false
    const user = await response.json()
    return typeof user?.id === 'string' && user.id.length > 0
  } catch {
    return false
  }
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return answer(405, { error: 'method_not_allowed' })
  if (!(await isSignedIn(request))) return answer(401, { error: 'not_signed_in' })

  let code: unknown
  try {
    code = (await request.json())?.code
  } catch {
    return answer(400, { error: 'bad_request' })
  }
  if (typeof code !== 'string' || code.length === 0 || code.length > 2048) return answer(400, { error: 'bad_request' })
  if (!TEAM_ID || !KEY_ID || !PRIVATE_KEY || !CLIENT_ID) return answer(503, { error: 'not_configured' })

  try {
    const secret = await clientSecret()
    const exchange = await fetch(`${APPLE_URL}/auth/token`, form({
      client_id: CLIENT_ID, client_secret: secret, code, grant_type: 'authorization_code',
    }))
    if (!exchange.ok) {
      console.error(`apple-revoke: the code was not accepted (${exchange.status})`)
      return answer(502, { error: 'code_not_accepted' })
    }
    const refreshToken = (await exchange.json())?.refresh_token
    if (typeof refreshToken !== 'string' || refreshToken.length === 0) return answer(502, { error: 'no_token' })

    const revoke = await fetch(`${APPLE_URL}/auth/revoke`, form({
      client_id: CLIENT_ID, client_secret: secret, token: refreshToken, token_type_hint: 'refresh_token',
    }))
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
