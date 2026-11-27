#!/bin/bash
# Runs supabase/functions/waitlist-signup in a Deno container against 100% local stand-ins for
# Postgres RPC (`join_waitlist`), Resend (`/emails`), and Cloudflare Turnstile (`/siteverify`).
# Completely offline, deterministic, and tests email sending, CAPTCHA, CORS, errors, and rate limits.
#
#   bash scripts/dbtest/waitlist_function.sh
#
# No real project is touched and no mail is sent. Needs Docker (Colima is fine). Exits 1 if any check fails.
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
mkdir -p "$WORK/_shared" "$WORK/waitlist-signup"
cp "$ROOT/supabase/functions/_shared/http.ts" "$WORK/_shared/http.ts"
cp "${FUNCTION_FILE:-$ROOT/supabase/functions/waitlist-signup/index.ts}" "$WORK/waitlist-signup/index.ts"

# ---- local stand-in for PostgREST RPC, Resend, and Cloudflare Turnstile ----
cat > "$WORK/mock.ts" <<'EOF'
type Row = { id: string; email: string; source: string; created_at: string }
const rows: Row[] = []
const sentEmails: Record<string, unknown>[] = []

Deno.serve({ port: 54321, onListen() {} }, async (req) => {
  const url = new URL(req.url)
  if (url.pathname === '/__rows') return Response.json(rows)
  if (url.pathname === '/__emails') return Response.json(sentEmails)
  if (url.pathname === '/__clear') { rows.length = 0; sentEmails.length = 0; return new Response('ok') }
  if (url.pathname === '/__fill') {
    const count = Number(url.searchParams.get('n') ?? '0')
    for (let i = 0; i < count; i++) {
      rows.push({ id: crypto.randomUUID(), email: `filler-${rows.length}@example.test`, source: 'other', created_at: new Date().toISOString() })
    }
    return new Response('ok')
  }

  // Atomic Postgres RPC stand-in
  if (url.pathname === '/rest/v1/rpc/join_waitlist' && req.method === 'POST') {
    const body = await req.json()
    const email = String(body.p_email)
    const source = String(body.p_source)
    const maxPerHour = Number(body.p_max_per_hour ?? 200)
    if (email === 'db-error@example.test') {
      return Response.json({ message: 'simulated database outage' }, { status: 500 })
    }
    const cutoff = new Date(Date.now() - 3600_000).toISOString()
    const recent = rows.filter((r) => r.created_at > cutoff).length
    if (recent >= maxPerHour) {
      return Response.json('rate_limited')
    }
    if (rows.some((r) => r.email === email)) {
      return Response.json('existing')
    }
    rows.push({ id: crypto.randomUUID(), email, source, created_at: new Date().toISOString() })
    return Response.json('inserted')
  }

  // Resend API stand-in
  if (url.pathname === '/emails' && req.method === 'POST') {
    const mail = await req.json()
    sentEmails.push({ ...mail, authorization: req.headers.get('authorization') })
    return Response.json({ id: crypto.randomUUID() })
  }

  // Cloudflare Turnstile stand-in
  if (url.pathname === '/siteverify' && req.method === 'POST') {
    const fields = Object.fromEntries(new URLSearchParams(await req.text()))
    if (fields.response === 'upstream-error') return new Response('bad gateway', { status: 502 })
    if (fields.secret === 'turnstile-secret' && fields.response === 'valid-token') {
      return Response.json({ success: true })
    }
    return Response.json({ success: false })
  }

  return new Response('not found', { status: 404 })
})
EOF

# ---- the checks ----
cat > "$WORK/client.ts" <<'EOF'
const FUNCTION = 'http://127.0.0.1:8000'
const STAND_IN = 'http://127.0.0.1:54321'
let failed = 0
let caller = 0

function check(label: string, ok: boolean, detail = '') {
  if (ok) console.log(`    pass  ${label}`)
  else { failed++; console.log(`    FAIL  ${label}\n          ${detail}`) }
}

async function post(body: unknown, headers: Record<string, string> = {}) {
  const response = await fetch(FUNCTION, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'cf-connecting-ip': `10.0.0.${++caller}`, ...headers },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  })
  const text = await response.text()
  let json: Record<string, unknown> | null = null
  try { json = JSON.parse(text) } catch { /* not JSON */ }
  return { status: response.status, text, json, headers: response.headers }
}
const stored = async (): Promise<{ email: string; source: string }[]> => await (await fetch(`${STAND_IN}/__rows`)).json()
const sent = async (): Promise<Record<string, unknown>[]> => await (await fetch(`${STAND_IN}/__emails`)).json()
const clear = async () => { await (await fetch(`${STAND_IN}/__clear`)).text() }
const fill = async (count: number) => { await (await fetch(`${STAND_IN}/__fill?n=${count}`)).text() }

const phase = Deno.args[0]
await clear()

if (phase === 'basics') {
  const preflight = await fetch(FUNCTION, { method: 'OPTIONS' })
  await preflight.text()
  check('OPTIONS CORS preflight returns 200 with expected origin header',
    preflight.status === 200 && preflight.headers.get('access-control-allow-origin') === 'https://pausely.pro',
    `${preflight.status} ${preflight.headers.get('access-control-allow-origin')}`)

  let answer = await post({ email: 'not-an-email' })
  check('a malformed address is refused', answer.status === 400, `got ${answer.status}`)
  answer = await post({ email: { nested: true } })
  check('an address that is not text is refused instead of crashing', answer.status === 400, `got ${answer.status}`)
  answer = await post('this is not json')
  check('a body that is not JSON is refused', answer.status === 400, `got ${answer.status}`)
  answer = await post({ email: 'a'.repeat(250) + '@example.test' })
  check('an over-long address is refused', answer.status === 400, `got ${answer.status}`)
  answer = await post({ email: 'a'.repeat(65) + '@example.test' })
  check('a >64-char local part is refused', answer.status === 400, `got ${answer.status}`)
  answer = await post({ email: 'a@b..com' })
  check('consecutive dots in email are refused', answer.status === 400, `got ${answer.status}`)
  answer = await post({ email: 'bad\x07ctrl@example.test' })
  check('control characters in email are refused', answer.status === 400, `got ${answer.status}`)
  answer = await post({ email: 'bad<script>@example.test' })
  check('an address with angle brackets is refused', answer.status === 400, `got ${answer.status}`)
  answer = await post({ email: 'a@example.test', pad: 'x'.repeat(5000) })
  check('an oversized body (>4KB) is refused with 413', answer.status === 413, `got ${answer.status}`)
  const viaGet = await fetch(FUNCTION)
  await viaGet.text()
  check('only POST is accepted', viaGet.status === 405, `got ${viaGet.status}`)
  check('the refused requests stored nothing and sent no email', (await stored()).length === 0 && (await sent()).length === 0)

  const first = await post({ email: '  New.Person@Example.test ', source: 'TikTok' })
  let rows = await stored()
  let mails = await sent()
  check('a new address joins', first.status === 200 && first.json?.success === true && first.json?.email_sent === true, first.text)
  check('it is stored trimmed and lower-cased, with its source',
    rows.length === 1 && rows[0].email === 'new.person@example.test' && rows[0].source === 'tiktok', JSON.stringify(rows))
  check('one confirmation email is sent via Resend with pausely@proton.me reply_to',
    mails.length === 1 && mails[0].to === 'new.person@example.test' && mails[0].reply_to === 'pausely@proton.me'
    && mails[0].authorization === 'Bearer test-resend-key'
    && String(mails[0].html).includes('Besides this confirmation, that launch note is the only email'),
    JSON.stringify(mails).slice(0, 300))

  const again = await post({ email: 'new.person@example.test' })
  check('the same address again gets the identical reply', again.status === first.status && again.text === first.text, again.text)
  check('and is neither stored twice nor emailed twice', (await stored()).length === 1 && (await sent()).length === 1)
  check('the reply does not say whether the address was known',
    again.json !== null && !('already_exists' in again.json) && !('provider' in again.json), again.text)

  await post({ email: 'odd.source@example.test', source: '<script>alert(1)</script>' })
  rows = await stored()
  check('an unknown source is stored as "other"', rows.find((row) => row.email === 'odd.source@example.test')?.source === 'other', JSON.stringify(rows))

  answer = await post({ email: 'db-error@example.test' })
  check('database RPC outage returns 500 cleanly', answer.status === 500, `${answer.status} ${answer.text}`)

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

if (phase === 'captcha') {
  let answer = await post({ email: 'no.token@example.test' })
  check('with CAPTCHA on, a request without a token is refused', answer.status === 403, `got ${answer.status}`)
  answer = await post({ email: 'bad.token@example.test', captcha_token: 'bad-token' })
  check('with CAPTCHA on, a rejected token is refused', answer.status === 403, `got ${answer.status}`)
  answer = await post({ email: 'upstream.err@example.test', captcha_token: 'upstream-error' })
  check('with CAPTCHA on, a non-200 Turnstile outage fails closed with 403', answer.status === 403, `got ${answer.status}`)
  check('and nothing was stored for refused CAPTCHA attempts', (await stored()).length === 0)
  answer = await post({ email: 'with.token@example.test', captcha_token: 'valid-token' })
  check('a request Turnstile accepts goes through', answer.status === 200, `got ${answer.status} ${answer.text}`)
  check('and is stored', (await stored()).some((row) => row.email === 'with.token@example.test'))
}

if (phase === 'unconfigured') {
  const answer = await post({ email: 'someone@example.test' })
  check('missing SUPABASE_URL / service key returns 503 cleanly', answer.status === 503, `${answer.status} ${answer.text}`)
}

Deno.exit(failed === 0 ? 0 : 1)
EOF

cat > "$WORK/inside.sh" <<'EOF'
cd /work
deno run --quiet --allow-net mock.ts &

start_function() {
  env "$@" deno run --quiet --allow-net --allow-env waitlist-signup/index.ts >> /work/function.log 2>&1 &
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
deno check --quiet waitlist-signup/index.ts && echo "    pass  the function type-checks" || { echo "    FAIL  the function type-checks"; failures=1; }

echo "  ordinary settings + Resend email verification (ceiling of 3/hour)"
start_function SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_SERVICE_ROLE_KEY=local-test RESEND_API_URL=http://127.0.0.1:54321 RESEND_API_KEY=test-resend-key WAITLIST_MAX_PER_HOUR=3
deno run --quiet --allow-net client.ts basics || failures=1
stop_function

echo "  CAPTCHA on (100% offline deterministic Turnstile stand-in)"
start_function SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_SERVICE_ROLE_KEY=local-test TURNSTILE_SECRET_KEY=turnstile-secret TURNSTILE_VERIFY_URL=http://127.0.0.1:54321/siteverify
deno run --quiet --allow-net client.ts captcha || failures=1
stop_function

echo "  missing Supabase configuration"
start_function SUPABASE_URL="" SUPABASE_SERVICE_ROLE_KEY=""
deno run --quiet --allow-net client.ts unconfigured || failures=1
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
