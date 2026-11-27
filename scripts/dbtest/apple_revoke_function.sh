#!/bin/bash
# Runs supabase/functions/apple-revoke in a Deno container against stand-ins for the account service,
# the Postgres rate-limit RPC, and Apple's two endpoints (token exchange and revocation), and checks
# honest and hostile requests.
#
#   bash scripts/dbtest/apple_revoke_function.sh
#
# No real project and no Apple server is touched. Needs Docker (Colima is fine). Exits 1 if a check fails.
set -uo pipefail

if ! command -v docker >/dev/null 2>&1 && [ -x "$HOME/.local/bin/docker" ]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IMAGE=denoland/deno:alpine

if [ -z "${DOCKER_HOST:-}" ] && [ -S "$HOME/.colima/default/docker.sock" ]; then
  export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/_shared" "$WORK/apple-revoke"
cp "$ROOT/supabase/functions/_shared/http.ts" "$WORK/_shared/http.ts"
cp "${FUNCTION_FILE:-$ROOT/supabase/functions/apple-revoke/index.ts}" "$WORK/apple-revoke/index.ts"

# ---- a key pair for this run: the private half for the function, the public half for the stand-in ----
cat > "$WORK/keys.ts" <<'EOF'
const pair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify'])
const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', pair.privateKey))
const body = btoa(String.fromCharCode(...der)).replace(/(.{64})/g, '$1\n')
await Deno.writeTextFile('/work/key.pem', `-----BEGIN PRIVATE KEY-----\n${body}\n-----END PRIVATE KEY-----\n`)
await Deno.writeTextFile('/work/public.json', JSON.stringify(await crypto.subtle.exportKey('jwk', pair.publicKey)))
EOF

# ---- a stand-in for Auth (/auth/v1/user), RPC (/rest/v1/rpc/consume_rate_limit), and Apple (/auth/token, /auth/revoke) ----
cat > "$WORK/mock.ts" <<'EOF'
const publicKey = await crypto.subtle.importKey('jwk', JSON.parse(await Deno.readTextFile('/work/public.json')),
  { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify'])
const fromBase64url = (value: string) =>
  Uint8Array.from(atob(value.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0))
const decode = (part: string) => JSON.parse(new TextDecoder().decode(fromBase64url(part)))
const b64url = (obj: unknown) =>
  btoa(JSON.stringify(obj)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')

type Seen = { path: string; fields: Record<string, string>; secret?: { header: unknown; claims: unknown; signed: boolean } }
let seen: Seen[] = []
let revoked: string[] = []
let failRevoke = false
const rateHits = new Map<string, number>()

async function read(req: Request): Promise<Seen> {
  const fields = Object.fromEntries(new URLSearchParams(await req.text()))
  const entry: Seen = { path: new URL(req.url).pathname, fields }
  const [header, claims, signature] = (fields.client_secret ?? '').split('.')
  if (header && claims && signature) {
    const signed = await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, publicKey,
      fromBase64url(signature), new TextEncoder().encode(`${header}.${claims}`))
    entry.secret = { header: decode(header), claims: decode(claims), signed }
  }
  seen.push(entry)
  return entry
}

Deno.serve({ port: 54321, onListen() {} }, async (req) => {
  const url = new URL(req.url)
  if (url.pathname === '/__seen') return Response.json({ seen, revoked })
  if (url.pathname === '/__reset') {
    seen = []; revoked = []; rateHits.clear()
    failRevoke = url.searchParams.get('failRevoke') === '1'
    return new Response('ok')
  }

  if (url.pathname === '/rest/v1/rpc/consume_rate_limit' && req.method === 'POST') {
    const body = await req.json()
    const key = String(body.p_key)
    const max = Number(body.p_max_hits ?? 5)
    const next = (rateHits.get(key) ?? 0) + 1
    rateHits.set(key, next)
    return Response.json(next <= max)
  }

  if (url.pathname === '/auth/v1/user') {
    const auth = req.headers.get('Authorization')
    if (auth === 'Bearer a-signed-in-session') {
      return Response.json({ id: '5f0c3a0e-0000-4000-8000-000000000001', identities: [{ provider: 'apple', id: 'apple-sub-1' }] })
    }
    if (auth === 'Bearer identity-data-sub-session') {
      return Response.json({ id: '5f0c3a0e-0000-4000-8000-000000000005', identities: [{ provider: 'apple', identity_data: { sub: 'apple-sub-5' } }] })
    }
    if (auth === 'Bearer an-email-only-session') {
      return Response.json({ id: '5f0c3a0e-0000-4000-8000-000000000002', identities: [{ provider: 'email', id: 'email-1' }] })
    }
    if (auth === 'Bearer missing-identities-session') {
      return Response.json({ id: '5f0c3a0e-0000-4000-8000-000000000003' })
    }
    if (auth === 'Bearer apple-missing-sub-session') {
      return Response.json({ id: '5f0c3a0e-0000-4000-8000-000000000004', identities: [{ provider: 'apple' }] })
    }
    return Response.json({ msg: 'invalid JWT' }, { status: 401 })
  }

  if (url.pathname === '/auth/token' && req.method === 'POST') {
    const entry = await read(req)
    if (!entry.secret?.signed) return Response.json({ error: 'invalid_grant' }, { status: 400 })
    const makeIdToken = (claims: Record<string, unknown>) => `eyJhbGciOiJSUzI1NiJ9.${b64url(claims)}.sig`

    if (entry.fields.code === 'a-code-for-someone-else') {
      return Response.json({
        access_token: 'access-2', token_type: 'Bearer', expires_in: 3600, refresh_token: 'refresh-other',
        id_token: makeIdToken({ iss: 'https://appleid.apple.com', aud: 'com.example.app', sub: 'apple-sub-other' }),
      })
    }
    if (entry.fields.code === 'a-code-wrong-aud') {
      return Response.json({
        access_token: 'access-3', token_type: 'Bearer', expires_in: 3600, refresh_token: 'refresh-3',
        id_token: makeIdToken({ iss: 'https://appleid.apple.com', aud: 'com.evil.other', sub: 'apple-sub-1' }),
      })
    }
    if (entry.fields.code === 'a-code-wrong-iss') {
      return Response.json({
        access_token: 'access-4', token_type: 'Bearer', expires_in: 3600, refresh_token: 'refresh-4',
        id_token: makeIdToken({ iss: 'https://evil.example', aud: 'com.example.app', sub: 'apple-sub-1' }),
      })
    }
    if (entry.fields.code === 'a-code-no-refresh-token') {
      return Response.json({ access_token: 'access-5', token_type: 'Bearer', expires_in: 3600 })
    }
    if (entry.fields.code === 'a-code-for-sub-5') {
      return Response.json({
        access_token: 'access-5', token_type: 'Bearer', expires_in: 3600, refresh_token: 'refresh-for-sub-5',
        id_token: makeIdToken({ iss: 'https://appleid.apple.com', aud: 'com.example.app', sub: 'apple-sub-5' }),
      })
    }
    if (entry.fields.code !== 'a-code-apple-issued') {
      return Response.json({ error: 'invalid_grant' }, { status: 400 })
    }
    return Response.json({
      access_token: 'access-1', token_type: 'Bearer', expires_in: 3600, refresh_token: 'refresh-for-this-person',
      id_token: makeIdToken({ iss: 'https://appleid.apple.com', aud: 'com.example.app', sub: 'apple-sub-1' }),
    })
  }

  if (url.pathname === '/auth/revoke' && req.method === 'POST') {
    const entry = await read(req)
    if (failRevoke || !entry.secret?.signed) return Response.json({ error: 'invalid_client' }, { status: 400 })
    revoked.push(entry.fields.token)
    return new Response(null, { status: 200 })
  }
  return new Response('not found', { status: 404 })
})
EOF

# ---- the checks ----
cat > "$WORK/client.ts" <<'EOF'
const FUNCTION = 'http://127.0.0.1:8000'
const STAND_IN = 'http://127.0.0.1:54321'
let failed = 0

function check(label: string, ok: boolean, detail = '') {
  if (ok) console.log(`    pass  ${label}`)
  else { failed++; console.log(`    FAIL  ${label}\n          ${detail}`) }
}
async function post(body: unknown, authorization: string | null = 'Bearer a-signed-in-session') {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' }
  if (authorization) headers.Authorization = authorization
  const response = await fetch(FUNCTION, { method: 'POST', headers, body: typeof body === 'string' ? body : JSON.stringify(body) })
  const text = await response.text()
  let json: Record<string, unknown> | null = null
  try { json = JSON.parse(text) } catch { /* not JSON */ }
  return { status: response.status, text, json }
}
const seen = async () => await (await fetch(`${STAND_IN}/__seen`)).json()
const reset = async (query = '') => { await (await fetch(`${STAND_IN}/__reset${query}`)).text() }

const phase = Deno.args[0]
await reset()

if (phase === 'configured') {
  const viaGet = await fetch(FUNCTION); await viaGet.text()
  check('only POST is accepted', viaGet.status === 405, `got ${viaGet.status}`)

  let answer = await post({ code: 'a-code-apple-issued' }, null)
  check('a caller with no session is refused', answer.status === 401, `got ${answer.status}`)
  answer = await post({ code: 'a-code-apple-issued' }, 'Bearer the-projects-public-key')
  check("a caller holding only the project's public key is refused", answer.status === 401, `got ${answer.status}`)
  answer = await post({ code: 'a-code-apple-issued' }, 'Bearer an-email-only-session')
  check('an email-only account cannot call apple-revoke', answer.status === 403 && answer.json?.error === 'not_apple_account', answer.text)
  answer = await post({ code: 'a-code-apple-issued' }, 'Bearer missing-identities-session')
  check('a user payload omitting identities fails closed with 403', answer.status === 403 && answer.json?.error === 'not_apple_account', answer.text)
  answer = await post({ code: 'a-code-apple-issued' }, 'Bearer apple-missing-sub-session')
  check('an Apple identity missing sub fails closed with 403', answer.status === 403 && answer.json?.error === 'not_apple_account', answer.text)
  answer = await post({ code: 'x'.repeat(5000) })
  check('an oversized body (>4KB) is rejected with 413', answer.status === 413, `got ${answer.status}`)
  check('and Apple was asked nothing', (await seen()).seen.length === 0)

  answer = await post('this is not json')
  check('a body that is not JSON is refused', answer.status === 400, `got ${answer.status}`)
  answer = await post({})
  check('a request without a code is refused', answer.status === 400, `got ${answer.status}`)
  answer = await post({ code: 'x'.repeat(3000) })
  check('an over-long code is refused', answer.status === 400, `got ${answer.status}`)
  check('and Apple was still asked nothing', (await seen()).seen.length === 0)

  answer = await post({ code: 'a-code-apple-issued' })
  let record = await seen()
  check('a signed-in person with a code Apple issued gets the tokens revoked', answer.status === 200 && answer.json?.revoked === true, answer.text)
  check('the code was exchanged once and one token revoked', record.seen.length === 2 && record.seen[0].path === '/auth/token' && record.seen[1].path === '/auth/revoke', JSON.stringify(record.seen.map((s: { path: string }) => s.path)))
  check('what was revoked is the refresh token Apple returned for that code', JSON.stringify(record.revoked) === '["refresh-for-this-person"]' && record.seen[1].fields.token_type_hint === 'refresh_token', JSON.stringify(record.revoked))
  const exchange = record.seen[0]
  check('the exchange names the app and asks for an authorization-code grant', exchange.fields.client_id === 'com.example.app' && exchange.fields.grant_type === 'authorization_code', JSON.stringify(exchange.fields.client_id))
  const secret = exchange.secret
  check("the client secret is signed with the team's key (verified with its public half)", secret?.signed === true)
  check('its header is ES256 with the key id', secret?.header?.alg === 'ES256' && secret?.header?.kid === 'KEYID12345', JSON.stringify(secret?.header))
  const claims = secret?.claims ?? {}
  check('it names the team as issuer, the app as subject and Apple as audience', claims.iss === 'TEAMID1234' && claims.sub === 'com.example.app' && claims.aud === 'https://appleid.apple.com', JSON.stringify(claims))
  check('and lasts five minutes (Apple allows at most six months)', claims.exp - claims.iat === 300 && Math.abs(claims.iat - Date.now() / 1000) < 60, JSON.stringify(claims))

  await reset()
  answer = await post({ code: 'a-code-for-sub-5' }, 'Bearer identity-data-sub-session')
  record = await seen()
  check('identity_data.sub fallback works when top-level identity.id is absent', answer.status === 200 && answer.json?.revoked === true && JSON.stringify(record.revoked) === '["refresh-for-sub-5"]', answer.text)

  await reset()
  answer = await post({ code: 'a-code-for-someone-else' })
  record = await seen()
  check('a code whose Apple sub does not match the caller is refused without revoking', answer.status === 403 && answer.json?.error === 'identity_mismatch' && record.revoked.length === 0, answer.text)

  await reset()
  answer = await post({ code: 'a-code-wrong-aud' })
  record = await seen()
  check('an id_token with wrong aud is refused without revoking', answer.status === 403 && answer.json?.error === 'identity_mismatch' && record.revoked.length === 0, answer.text)

  await reset()
  answer = await post({ code: 'a-code-wrong-iss' })
  record = await seen()
  check('an id_token with wrong iss is refused without revoking', answer.status === 403 && answer.json?.error === 'identity_mismatch' && record.revoked.length === 0, answer.text)

  await reset()
  answer = await post({ code: 'a-code-no-refresh-token' })
  check('missing refresh_token returns 502 no_token', answer.status === 502 && answer.json?.error === 'no_token', answer.text)

  await reset()
  answer = await post({ code: 'a-code-someone-made-up' })
  record = await seen()
  check('a code Apple does not accept revokes nothing', answer.status === 502 && answer.json?.error === 'code_not_accepted' && record.revoked.length === 0, answer.text)

  await reset('?failRevoke=1')
  answer = await post({ code: 'a-code-apple-issued' })
  check('if Apple refuses the revocation the app is told so', answer.status === 502 && answer.json?.error === 'not_revoked', answer.text)
}

if (phase === 'rate-limit') {
  const first = await post({ code: 'a-code-apple-issued' })
  const second = await post({ code: 'a-code-apple-issued' })
  const third = await post({ code: 'a-code-apple-issued' })
  check('per-user rate limit allows hits up to ceiling and returns 429 afterwards', first.status === 200 && second.status === 200 && third.status === 429 && third.json?.error === 'rate_limited', `${first.status}/${second.status}/${third.status} ${third.text}`)
}

if (phase === 'not-configured') {
  const answer = await post({ code: 'a-code-apple-issued' })
  check("without Apple's key the function says it is not set up", answer.status === 503 && answer.json?.error === 'not_configured', answer.text)
  check('and Apple is asked nothing', (await seen()).seen.length === 0)
  const stranger = await post({ code: 'a-code-apple-issued' }, null)
  check('a caller with no session is still refused first', stranger.status === 401, `got ${stranger.status}`)
}

Deno.exit(failed === 0 ? 0 : 1)
EOF

# ---- inside the container ----
cat > "$WORK/inside.sh" <<'EOF'
cd /work
deno run --quiet --allow-write keys.ts
deno run --quiet --allow-net --allow-read mock.ts &

start_function() {
  env SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_ANON_KEY=the-projects-public-key SUPABASE_SERVICE_ROLE_KEY=service-role-key APPLE_ID_URL=http://127.0.0.1:54321 "$@" \
    deno run --quiet --allow-net --allow-env apple-revoke/index.ts >> /work/function.log 2>&1 &
  FUNCTION_PID=$!
  for _ in $(seq 1 240); do
    if deno eval --quiet "try { await (await fetch('http://127.0.0.1:8000', { method: 'OPTIONS' })).text() } catch { Deno.exit(1) }" 2>/dev/null; then
      return 0
    fi
    sleep 0.5
  done
  echo "The function did not start:"; cat /work/function.log; exit 1
}
stop_function() { kill "$FUNCTION_PID" 2>/dev/null; wait "$FUNCTION_PID" 2>/dev/null; }

failures=0
deno check --quiet apple-revoke/index.ts && echo "    pass  the function type-checks" || { echo "    FAIL  the function type-checks"; failures=1; }

echo "  with Apple's key set"
start_function APPLE_TEAM_ID=TEAMID1234 APPLE_KEY_ID=KEYID12345 APPLE_CLIENT_ID=com.example.app APPLE_PRIVATE_KEY="$(cat /work/key.pem)" APPLE_REVOKE_MAX_PER_HOUR=20
deno run --quiet --allow-net client.ts configured || failures=1
stop_function

echo "  per-user rate limiting (ceiling of 2/hour)"
start_function APPLE_TEAM_ID=TEAMID1234 APPLE_KEY_ID=KEYID12345 APPLE_CLIENT_ID=com.example.app APPLE_PRIVATE_KEY="$(cat /work/key.pem)" APPLE_REVOKE_MAX_PER_HOUR=2
deno run --quiet --allow-net client.ts rate-limit || failures=1
stop_function

echo "  with no key set"
start_function
deno run --quiet --allow-net client.ts not-configured || failures=1
stop_function

if grep -qE 'a-code-apple-issued|refresh-for-this-person|a-code-someone-made-up' /work/function.log; then
  echo "    FAIL  the function's log holds neither a code nor a token"; failures=1
else
  echo "    pass  the function's log holds neither a code nor a token"
fi
exit "$failures"
EOF

tar -C "$WORK" -cf - . | docker run --rm -i "$IMAGE" sh -c 'mkdir -p /work && tar -xf - -C /work && sh /work/inside.sh'
code=$?
if [ "$code" -eq 0 ]; then echo "apple-revoke: every check passed"; else echo "apple-revoke: FAILED"; fi
exit "$code"
