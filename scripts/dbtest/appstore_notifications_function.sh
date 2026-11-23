#!/bin/bash
# Runs supabase/functions/appstore-notifications in a Deno container against a stand-in PostgREST
# server and checks honest and hostile App Store Server Notifications v2 requests.
#
#   bash scripts/dbtest/appstore_notifications_function.sh
#
# No real project and no Apple server is touched. Needs Docker (Colima is fine). Exits 1 if a check fails.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IMAGE=denoland/deno:alpine

if [ -z "${DOCKER_HOST:-}" ] && [ -S "$HOME/.colima/default/docker.sock" ]; then
  export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "${FUNCTION_FILE:-$ROOT/supabase/functions/appstore-notifications/index.ts}" "$WORK/index.ts"

# ---- stand-in Supabase REST server capturing upserts into app_store_entitlements ----
cat > "$WORK/mock.ts" <<'EOF'
let rows: Record<string, Record<string, unknown>> = {}

Deno.serve({ port: 54321, onListen() {} }, async (req) => {
  const url = new URL(req.url)
  if (url.pathname === '/__rows') return Response.json(rows)
  if (url.pathname === '/__reset') { rows = {}; return new Response('ok') }

  if (url.pathname === '/rest/v1/app_store_entitlements' && req.method === 'POST') {
    if (req.headers.get('apikey') !== 'service-role-key') {
      return Response.json({ message: 'unauthorized' }, { status: 401 })
    }
    const body = await req.json()
    const items = Array.isArray(body) ? body : [body]
    for (const item of items) {
      rows[String(item.original_transaction_id)] = item
    }
    return Response.json(items, { status: 201 })
  }
  return new Response('not found', { status: 404 })
})
EOF

# ---- test client ----
cat > "$WORK/client.ts" <<'EOF'
const FUNCTION = 'http://127.0.0.1:8000'
const STAND_IN = 'http://127.0.0.1:54321'
let failed = 0

function check(label: string, ok: boolean, detail = '') {
  if (ok) console.log(`    pass  ${label}`)
  else { failed++; console.log(`    FAIL  ${label}\n          ${detail}`) }
}

const b64url = (value: unknown) =>
  btoa(JSON.stringify(value)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')

function makeJWS(payload: Record<string, unknown>, header: Record<string, unknown> = { alg: 'ES256', x5c: ['cert'] }) {
  return `${b64url(header)}.${b64url(payload)}.ZmFrZS1zaWc`
}

async function post(body: unknown) {
  const response = await fetch(FUNCTION, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  })
  const text = await response.text()
  let json: Record<string, unknown> | null = null
  try { json = JSON.parse(text) } catch { /* not JSON */ }
  return { status: response.status, text, json }
}

const rows = async () => await (await fetch(`${STAND_IN}/__rows`)).json()
const reset = async () => { await (await fetch(`${STAND_IN}/__reset`)).text() }

await reset()

const viaGet = await fetch(FUNCTION); await viaGet.text()
check('only POST is accepted', viaGet.status === 405, `got ${viaGet.status}`)

let ans = await post('not-json')
check('non-JSON body is refused', ans.status === 400, `got ${ans.status}`)

ans = await post({ signedPayload: 'not-a-jws' })
check('malformed JWS is refused', ans.status === 400, `got ${ans.status}`)

ans = await post({ signedPayload: makeJWS({ notificationType: 'SUBSCRIBED', data: {} }, { alg: 'HS256', x5c: ['c'] }) })
check('non-ES256 JWS is refused', ans.status === 400, `got ${ans.status}`)

ans = await post({ signedPayload: makeJWS({ notificationType: 'TEST', data: {} }) })
check('Apple TEST notification succeeds without touching the database', ans.status === 200 && ans.json?.test === true && Object.keys(await rows()).length === 0, ans.text)

const txAnnual = makeJWS({
  originalTransactionId: '10000001',
  productId: 'com.pausely.premium.annual',
  offerType: 1,
  expiresDate: Date.UTC(2026, 11, 1),
  appAccountToken: 'AAAAAAAA-0000-4000-8000-000000000001',
})
const renewOn = makeJWS({ autoRenewStatus: 1 })

ans = await post({
  signedPayload: makeJWS({
    notificationType: 'SUBSCRIBED',
    subtype: 'INITIAL_BUY',
    data: { bundleId: 'com.evil.other', environment: 'Production', signedTransactionInfo: txAnnual },
  }),
})
check('wrong bundle id is refused with 403', ans.status === 403, ans.text)

const txUnknown = makeJWS({ originalTransactionId: '10000002', productId: 'com.pausely.fake' })
ans = await post({
  signedPayload: makeJWS({
    notificationType: 'SUBSCRIBED',
    data: { bundleId: 'com.pausely.app.Pausely', environment: 'Production', signedTransactionInfo: txUnknown },
  }),
})
check('unknown product id is refused', ans.status === 400, ans.text)

ans = await post({
  signedPayload: makeJWS({
    notificationType: 'SUBSCRIBED',
    subtype: 'INITIAL_BUY',
    data: { bundleId: 'com.pausely.app.Pausely', environment: 'Production', signedTransactionInfo: txAnnual, signedRenewalInfo: renewOn },
  }),
})
let stored = await rows()
check('a free-trial signup is recorded as trial with lowercased user_id', ans.status === 200 && stored['10000001']?.status === 'trial' && stored['10000001']?.user_id === 'aaaaaaaa-0000-4000-8000-000000000001' && stored['10000001']?.will_auto_renew === true, JSON.stringify(stored))

ans = await post({
  signedPayload: makeJWS({
    notificationType: 'DID_FAIL_TO_RENEW',
    subtype: 'GRACE_PERIOD',
    data: { bundleId: 'com.pausely.app.Pausely', environment: 'Production', signedTransactionInfo: txAnnual },
  }),
})
stored = await rows()
check('billing failure in grace period updates status to grace_period', ans.status === 200 && stored['10000001']?.status === 'grace_period', JSON.stringify(stored))

ans = await post({
  signedPayload: makeJWS({
    notificationType: 'REFUND',
    data: { bundleId: 'com.pausely.app.Pausely', environment: 'Production', signedTransactionInfo: txAnnual },
  }),
})
stored = await rows()
check('refund updates status to refunded', ans.status === 200 && stored['10000001']?.status === 'refunded', JSON.stringify(stored))

Deno.exit(failed === 0 ? 0 : 1)
EOF

cat > "$WORK/inside.sh" <<'EOF'
cd /work
deno run --quiet --allow-net mock.ts &
env SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_SERVICE_ROLE_KEY=service-role-key APP_STORE_BUNDLE_ID=com.pausely.app.Pausely \
  deno run --quiet --allow-net --allow-env index.ts >> /work/function.log 2>&1 &
FUNCTION_PID=$!
for _ in $(seq 1 240); do
  if deno eval --quiet "try { await (await fetch('http://127.0.0.1:8000')).text() } catch { Deno.exit(1) }" 2>/dev/null; then
    break
  fi
  sleep 0.5
done
deno run --quiet --allow-net client.ts
status=$?
kill "$FUNCTION_PID" 2>/dev/null; wait "$FUNCTION_PID" 2>/dev/null
exit "$status"
EOF

tar -C "$WORK" -cf - . | docker run --rm -i "$IMAGE" sh -c 'mkdir -p /work && tar -xf - -C /work && sh /work/inside.sh'
code=$?
if [ "$code" -eq 0 ]; then echo "appstore-notifications: every check passed"; else echo "appstore-notifications: FAILED"; fi
exit "$code"
