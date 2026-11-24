#!/bin/bash
# Runs supabase/functions/waitlist-signup in a Deno container against a stand-in for the database's
# REST API, and checks how it answers hostile and ordinary requests.
#
#   bash scripts/dbtest/waitlist_function.sh
#
# No real project is touched and no mail is sent. The two CAPTCHA runs call Cloudflare's public
# Turnstile test keys (one always passes, one always fails), so they need the internet.
# Needs Docker (Colima is fine). Exits 1 if any check fails.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IMAGE=denoland/deno:alpine

if [ -z "${DOCKER_HOST:-}" ] && [ -S "$HOME/.colima/default/docker.sock" ]; then
  export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "${FUNCTION_FILE:-$ROOT/supabase/functions/waitlist-signup/index.ts}" "$WORK/index.ts"

# ---- a stand-in for PostgREST: just the three calls the function makes on public.waitlist ----
cat > "$WORK/mock.ts" <<'EOF'
type Row = { id: string; email: string; source: string; created_at: string }
const rows: Row[] = []

Deno.serve({ port: 54321, onListen() {} }, async (req) => {
  const url = new URL(req.url)
  if (url.pathname === '/__rows') return Response.json(rows)
  if (url.pathname === '/__clear') { rows.length = 0; return new Response('ok') }
  if (url.pathname === '/__fill') {
    const count = Number(url.searchParams.get('n') ?? '0')
    for (let i = 0; i < count; i++) {
      rows.push({ id: crypto.randomUUID(), email: `filler-${rows.length}@example.test`, source: 'other', created_at: new Date().toISOString() })
    }
    return new Response('ok')
  }
  if (url.pathname !== '/rest/v1/waitlist') return new Response('not found', { status: 404 })

  if (req.method === 'HEAD') {  // count of rows newer than ?created_at=gt.<time>
    const since = (url.searchParams.get('created_at') ?? '').replace(/^gt\./, '')
    const count = rows.filter((row) => row.created_at > since).length
    return new Response(null, { status: 200, headers: { 'content-range': `*/${count}` } })
  }
  if (req.method === 'GET') {   // lookup by ?email=eq.<address>
    const email = (url.searchParams.get('email') ?? '').replace(/^eq\./, '')
    return Response.json(rows.filter((row) => row.email === email).map((row) => ({ id: row.id })))
  }
  if (req.method === 'POST') {  // insert, with the table's unique email
    const sent = await req.json()
    const row = Array.isArray(sent) ? sent[0] : sent
    if (rows.some((existing) => existing.email === row.email)) {
      return Response.json({ code: '23505', message: 'duplicate key value violates unique constraint' }, { status: 409 })
    }
    rows.push({ id: crypto.randomUUID(), email: row.email, source: row.source, created_at: new Date().toISOString() })
    return new Response(null, { status: 201 })
  }
  return new Response('unsupported', { status: 405 })
})
EOF

# ---- the checks ----
cat > "$WORK/client.ts" <<'EOF'
const FUNCTION = 'http://127.0.0.1:8000'
const DATABASE = 'http://127.0.0.1:54321'
let failed = 0
let caller = 0

function check(label: string, ok: boolean, detail = '') {
  if (ok) console.log(`    pass  ${label}`)
  else { failed++; console.log(`    FAIL  ${label}\n          ${detail}`) }
}

// Each request comes from a new caller unless a test says otherwise, so the per-caller limit stays out of the way.
async function post(body: unknown, headers: Record<string, string> = {}) {
  const response = await fetch(FUNCTION, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'cf-connecting-ip': `10.0.0.${++caller}`, ...headers },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  })
  const text = await response.text()
  let json: Record<string, unknown> | null = null
  try { json = JSON.parse(text) } catch { /* not JSON */ }
  return { status: response.status, text, json }
}
const stored = async (): Promise<{ email: string; source: string }[]> => await (await fetch(`${DATABASE}/__rows`)).json()
const clear = async () => { await (await fetch(`${DATABASE}/__clear`)).text() }
const fill = async (count: number) => { await (await fetch(`${DATABASE}/__fill?n=${count}`)).text() }

const phase = Deno.args[0]
await clear()

if (phase === 'basics') {  // started with a ceiling of 3 sign-ups an hour and no CAPTCHA
  let answer = await post({ email: 'not-an-email' })
  check('a malformed address is refused', answer.status === 400, `got ${answer.status}`)
  answer = await post({ email: { nested: true } })
  check('an address that is not text is refused instead of crashing', answer.status === 400, `got ${answer.status}`)
  answer = await post('this is not json')
  check('a body that is not JSON is refused', answer.status === 400, `got ${answer.status}`)
  answer = await post({ email: 'a'.repeat(250) + '@example.test' })
  check('an over-long address is refused', answer.status === 400, `got ${answer.status}`)
  const viaGet = await fetch(FUNCTION)
  await viaGet.text()
  check('only POST is accepted', viaGet.status === 405, `got ${viaGet.status}`)
  check('the refused requests stored nothing', (await stored()).length === 0)

  const first = await post({ email: '  New.Person@Example.test ', source: 'TikTok' })
  let rows = await stored()
  check('a new address joins', first.status === 200 && first.json?.success === true, first.text)
  check('it is stored trimmed and lower-cased, with its source',
    rows.length === 1 && rows[0].email === 'new.person@example.test' && rows[0].source === 'tiktok', JSON.stringify(rows))
  const again = await post({ email: 'new.person@example.test' })
  check('the same address again gets the identical reply', again.status === first.status && again.text === first.text, again.text)
  check('and is not stored twice', (await stored()).length === 1)
  check('the reply does not say whether the address was known',
    again.json !== null && !('already_exists' in again.json) && !('provider' in again.json), again.text)

  await post({ email: 'odd.source@example.test', source: '<script>alert(1)</script>' })
  rows = await stored()
  check('an unknown source is stored as "other"', rows.find((row) => row.email === 'odd.source@example.test')?.source === 'other', JSON.stringify(rows))

  await fill(1)  // three recent rows now: the ceiling
  answer = await post({ email: 'over.the.ceiling@example.test' })
  check('past the hourly ceiling a new address is turned away', answer.status === 429, `got ${answer.status}`)
  check('and is not stored', !(await stored()).some((row) => row.email === 'over.the.ceiling@example.test'))
  answer = await post({ email: 'new.person@example.test' })
  check('a known address gets the same answer at the ceiling', answer.status === 429, `got ${answer.status}`)

  await clear()
  let last = 0
  for (let attempt = 0; attempt < 6; attempt++) {
    last = (await post({ email: 'x' }, { 'cf-connecting-ip': '10.9.9.9' })).status
  }
  check('one caller is slowed after five requests in a minute', last === 429, `got ${last}`)
}

if (phase === 'captcha-pass') {  // started with Cloudflare's always-pass test key
  let answer = await post({ email: 'no.token@example.test' })
  check('with the CAPTCHA on, a request without a token is refused', answer.status === 403, `got ${answer.status}`)
  check('and nothing is stored', (await stored()).length === 0)
  answer = await post({ email: 'with.token@example.test', captcha_token: 'XXXX.DUMMY.TOKEN.XXXX' })
  check('a request Cloudflare accepts goes through', answer.status === 200, `got ${answer.status} ${answer.text}`)
  check('and is stored', (await stored()).some((row) => row.email === 'with.token@example.test'))
}

if (phase === 'captcha-fail') {  // started with Cloudflare's always-fail test key
  const answer = await post({ email: 'bad.token@example.test', captcha_token: 'XXXX.DUMMY.TOKEN.XXXX' })
  check('a request Cloudflare rejects is refused', answer.status === 403, `got ${answer.status}`)
  check('and nothing is stored', (await stored()).length === 0)
}

Deno.exit(failed === 0 ? 0 : 1)
EOF

# ---- inside the container: the stand-in, then the function three times with different settings ----
cat > "$WORK/inside.sh" <<'EOF'
cd /work
deno run --quiet --allow-net mock.ts &

start_function() {
  env SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_SERVICE_ROLE_KEY=local-test "$@" \
    deno run --quiet --allow-net --allow-env index.ts >> /work/function.log 2>&1 &
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
echo "  ordinary settings, ceiling of 3 sign-ups an hour"
start_function WAITLIST_MAX_PER_HOUR=3
deno run --quiet --allow-net client.ts basics || failures=1
stop_function

echo "  CAPTCHA on, with Cloudflare's always-pass test key"
start_function TURNSTILE_SECRET_KEY=1x0000000000000000000000000000000AA
deno run --quiet --allow-net client.ts captcha-pass || failures=1
stop_function

echo "  CAPTCHA on, with Cloudflare's always-fail test key"
start_function TURNSTILE_SECRET_KEY=2x0000000000000000000000000000000AA
deno run --quiet --allow-net client.ts captcha-fail || failures=1
stop_function

if grep -qE '@example\.test' /work/function.log; then
  echo "    FAIL  the function's log holds no email address"; failures=1
else
  echo "    pass  the function's log holds no email address"
fi
exit "$failures"
EOF

tar -C "$WORK" -cf - . | docker run --rm -i "$IMAGE" sh -c 'mkdir -p /work && tar -xf - -C /work && sh /work/inside.sh'
code=$?
[ "$code" -eq 0 ] && echo "waitlist function: all checks passed" || echo "waitlist function: some checks FAILED"
exit "$code"
