#!/bin/bash
# Runs supabase/functions/auth-email in a Deno container against a stand-in for the mail provider,
# and checks honest, localized, email_change double-confirm, and hostile requests.
#
#   bash scripts/dbtest/auth_email_function.sh
#
# No real project is touched and no mail is sent. Needs Docker (Colima is fine). Exits 1 on a failure.
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
mkdir -p "$WORK/_shared" "$WORK/auth-email"
cp "$ROOT/supabase/functions/_shared/http.ts" "$WORK/_shared/http.ts"
cp "${FUNCTION_FILE:-$ROOT/supabase/functions/auth-email/index.ts}" "$WORK/auth-email/index.ts"

# ---- a stand-in for the mail provider ----
cat > "$WORK/mock.ts" <<'EOF'
const sent: Record<string, unknown>[] = []
Deno.serve({ port: 54322, onListen() {} }, async (req) => {
  const url = new URL(req.url)
  if (url.pathname === '/__sent') return Response.json(sent)
  if (url.pathname === '/__clear') { sent.length = 0; return new Response('ok') }
  if (url.pathname === '/emails' && req.method === 'POST') {
    const email = await req.json()
    if (String(email.to).includes('refused')) return Response.json({ message: 'domain is not verified' }, { status: 403 })
    sent.push({ ...email, authorization: req.headers.get('authorization') })
    return Response.json({ id: crypto.randomUUID() })
  }
  return new Response('not found', { status: 404 })
})
EOF

# ---- the checks ----
cat > "$WORK/client.ts" <<'EOF'
const FUNCTION = 'http://127.0.0.1:8000'
const PROVIDER = 'http://127.0.0.1:54322'
const SECRET = Deno.env.get('TEST_SECRET')!
const phase = Deno.args[0] ?? 'main'
let failed = 0

function check(label: string, ok: boolean, detail = '') {
  if (ok) console.log(`    pass  ${label}`)
  else { failed++; console.log(`    FAIL  ${label}\n          ${detail}`) }
}

async function sign(id: string, timestamp: string, body: string, secret = SECRET): Promise<string> {
  const key = await crypto.subtle.importKey('raw', Uint8Array.from(atob(secret), (c) => c.charCodeAt(0)),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const mac = new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${id}.${timestamp}.${body}`)))
  return 'v1,' + btoa(String.fromCharCode(...mac))
}

async function hookRaw(body: string, options: { secret?: string; age?: number; unsigned?: boolean; extraSig?: string } = {}) {
  const id = 'msg_' + crypto.randomUUID()
  const timestamp = String(Math.floor(Date.now() / 1000) - (options.age ?? 0))
  const headers: Record<string, string> = { 'Content-Type': 'application/json' }
  if (!options.unsigned) {
    const sig = await sign(id, timestamp, body, options.secret)
    headers['webhook-id'] = id
    headers['webhook-timestamp'] = timestamp
    headers['webhook-signature'] = options.extraSig ? `${options.extraSig} ${sig}` : sig
  }
  const response = await fetch(FUNCTION, { method: 'POST', headers, body })
  return { status: response.status, text: await response.text() }
}
const hook = (payload: unknown, options: { secret?: string; age?: number; unsigned?: boolean; extraSig?: string } = {}) =>
  hookRaw(JSON.stringify(payload), options)

const sent = async (): Promise<Record<string, unknown>[]> => await (await fetch(`${PROVIDER}/__sent`)).json()
const clear = async () => { await (await fetch(`${PROVIDER}/__clear`)).text() }
const email = (address: string, purpose: string, token = '482913', locale?: string) => ({
  user: { id: crypto.randomUUID(), email: address, ...(locale ? { user_metadata: { locale } } : {}) },
  email_data: { token, token_hash: 'abc', email_action_type: purpose, redirect_to: 'pausely://auth/confirm', site_url: 'https://pausely.pro' },
})

await clear()

if (phase === 'main') {
  let answer = await hook(email('new.person@example.test', 'signup'))
  let outbox = await sent()
  check('a signed request for a new sign-up is accepted', answer.status === 200, `${answer.status} ${answer.text}`)
  check('one email goes to that address, from Pausely', outbox.length === 1 && String(outbox[0].to) === 'new.person@example.test' && String(outbox[0].from).includes('hello@pausely.pro'), JSON.stringify(outbox).slice(0, 200))
  check('the subject carries the code', outbox[0]?.subject === 'Your Pausely code: 482913', String(outbox[0]?.subject))
  check('the page carries the code and the sign-up sentence', String(outbox[0]?.html).includes('482913') && String(outbox[0]?.html).includes('finish creating your account'))
  check('the page has no link, image or leftover placeholder', !/href=|<img|\{\{|SENTENCE/.test(String(outbox[0]?.html)))
  check('a plain-text copy carries the code too', String(outbox[0]?.text).includes('482913'))
  check("the mail provider is given the key from the function's own settings", outbox[0]?.authorization === 'Bearer test-mail-key')

  await clear()
  await hook(email('back.again@example.test', 'magiclink'))
  await hook(email('forgot@example.test', 'recovery'))
  await hook(email('other@example.test', 'something_new'))
  await hook(email('proto@example.test', 'toString'))
  outbox = await sent()
  check('a sign-in email says so', String(outbox[0]?.html).includes('Enter it in Pausely to sign in.'))
  check('a reset email says so', String(outbox[1]?.html).includes('choose a new password'))
  check('a purpose this function has never heard of still gets its code', outbox.length === 4 && String(outbox[2]?.html).includes('482913') && String(outbox[2]?.html).includes('to continue'))
  check('a prototype property purpose falls back safely without leaking Object.prototype', String(outbox[3]?.html).includes('to continue') && !String(outbox[3]?.html).includes('[native code]'))

  // Multi-signature rotation header ("v1,old v1,current")
  await clear()
  answer = await hook(email('rotated@example.test', 'signup'), { extraSig: 'v1,invalidoldsignature==' })
  check('multi-signature rotation header accepts valid signature alongside rotated one', answer.status === 200 && (await sent()).length === 1, `${answer.status} ${answer.text}`)

  // Double-confirm email_change (sends token -> current email, token_new -> new_email)
  await clear()
  answer = await hook({
    user: { id: crypto.randomUUID(), email: 'old@example.test', new_email: 'new@example.test' },
    email_data: { token: '111222', token_new: '333444', email_action_type: 'email_change' },
  })
  outbox = await sent()
  check('double-confirm email_change sends both OTP emails to old and new addresses',
    answer.status === 200 && outbox.length === 2
    && String(outbox[0].to) === 'old@example.test' && String(outbox[0].subject).includes('111222')
    && String(outbox[1].to) === 'new@example.test' && String(outbox[1].subject).includes('333444'),
    JSON.stringify(outbox).slice(0, 300))

  // Single-confirm email_change (only new_email + token)
  await clear()
  answer = await hook({
    user: { id: crypto.randomUUID(), email: 'old@example.test', new_email: 'solo@example.test' },
    email_data: { token: '555666', email_action_type: 'email_change' },
  })
  outbox = await sent()
  check('single-confirm email_change sends OTP to new_email', answer.status === 200 && outbox.length === 1 && String(outbox[0].to) === 'solo@example.test' && String(outbox[0].subject).includes('555666'), JSON.stringify(outbox).slice(0, 200))

  // Localization across shipped languages (including RTL Arabic)
  await clear()
  await hook(email('de@example.test', 'signup', '654321', 'de-DE'))
  await hook(email('ar@example.test', 'magiclink', '777888', 'ar'))
  await hook(email('ja@example.test', 'recovery', '999000', 'ja_JP'))
  outbox = await sent()
  check('localized OTP emails render German, RTL Arabic, and Japanese cleanly',
    outbox.length === 3
    && String(outbox[0].subject) === 'Dein Pausely-Code: 654321'
    && String(outbox[1].html).includes('dir="rtl"') && String(outbox[1].html).includes('777888')
    && String(outbox[2].subject).includes('Pauselyの確認コード: 999000'),
    JSON.stringify(outbox.map((m) => m.subject)))

  // Security & negative checks
  await clear()
  answer = await hook(email('forged@example.test', 'signup'), { secret: btoa('some-other-secret-entirely') })
  check('a request signed with another secret is refused', answer.status === 401, `got ${answer.status}`)
  answer = await hook(email('unsigned@example.test', 'signup'), { unsigned: true })
  check('an unsigned request is refused', answer.status === 401, `got ${answer.status}`)
  answer = await hook(email('replayed@example.test', 'signup'), { age: 3600 })
  check('a correctly signed request from an hour ago is refused', answer.status === 401, `got ${answer.status}`)
  answer = await hook(email('future@example.test', 'signup'), { age: -3600 })
  check('a correctly signed request stamped an hour in the future is refused', answer.status === 401, `got ${answer.status}`)
  answer = await hookRaw('not-valid-json')
  check('a signed malformed JSON body is refused with 400', answer.status === 400, `got ${answer.status}`)
  answer = await hookRaw('x'.repeat(40_000))
  check('an oversized body (>32KB) is rejected with 413', answer.status === 413, `got ${answer.status}`)
  answer = await hook(email('bad\r\ninject@example.test', 'signup'))
  check('an email with CRLF control chars is rejected with 400', answer.status === 400, `got ${answer.status}`)
  answer = await hook({ user: { email: 'nocode@example.test' }, email_data: { email_action_type: 'signup' } })
  check('a request without a code is refused', answer.status === 400, `got ${answer.status}`)
  answer = await hook(email('letters@example.test', 'signup', '12ab56'))
  check('a code that is not digits is refused', answer.status === 400, `got ${answer.status}`)
  const viaGet = await fetch(FUNCTION)
  await viaGet.text()
  check('only POST is accepted', viaGet.status === 405, `got ${viaGet.status}`)
  check('none of the refused requests sent an email', (await sent()).length === 0, JSON.stringify(await sent()).slice(0, 200))

  answer = await hook(email('refused@example.test', 'signup'))
  check('when the mail provider refuses, Supabase Auth is told the email was not sent', answer.status === 502 && answer.text.includes('"http_code":502'), `${answer.status} ${answer.text}`)
}

if (phase === 'plain-whsec') {
  const answer = await hook(email('plain.whsec@example.test', 'signup'))
  check('SEND_EMAIL_HOOK_SECRET using plain whsec_<b64> (without v1,) is accepted', answer.status === 200 && (await sent()).length === 1, `${answer.status} ${answer.text}`)
}

if (phase === 'no-mail-key') {
  const answer = await hook(email('nokey@example.test', 'signup'))
  check('missing RESEND_API_KEY returns 503', answer.status === 503 && answer.text.includes('"http_code":503'), `${answer.status} ${answer.text}`)
}

Deno.exit(failed === 0 ? 0 : 1)
EOF

cat > "$WORK/inside.sh" <<'EOF'
cd /work
export TEST_SECRET="$(printf 'a-test-secret-of-32-bytes-or-more!' | base64)"
deno run --quiet --allow-net mock.ts &

start_fn() {
  env RESEND_API_URL=http://127.0.0.1:54322 "$@" \
    deno run --quiet --allow-net --allow-env auth-email/index.ts >> /work/function.log 2>&1 &
  FN_PID=$!
  for _ in $(seq 1 240); do
    if deno eval --quiet "try { await (await fetch('http://127.0.0.1:8000')).text() } catch { Deno.exit(1) }" 2>/dev/null; then return 0; fi
    sleep 0.5
  done
  echo "The function did not start:"; cat /work/function.log; exit 1
}
stop_fn() { kill "$FN_PID" 2>/dev/null; wait "$FN_PID" 2>/dev/null; }

failures=0
deno check --quiet auth-email/index.ts && echo "    pass  the function type-checks" || { echo "    FAIL  the function type-checks"; failures=1; }

echo "  v1,whsec_ secret + localization + email_change"
start_fn RESEND_API_KEY=test-mail-key SEND_EMAIL_HOOK_SECRET="v1,whsec_$TEST_SECRET"
deno run --quiet --allow-net --allow-env client.ts main || failures=1
stop_fn

echo "  plain whsec_ secret (no v1, prefix)"
start_fn RESEND_API_KEY=test-mail-key SEND_EMAIL_HOOK_SECRET="whsec_$TEST_SECRET"
deno run --quiet --allow-net --allow-env client.ts plain-whsec || failures=1
stop_fn

echo "  missing RESEND_API_KEY"
start_fn RESEND_API_KEY="" SEND_EMAIL_HOOK_SECRET="v1,whsec_$TEST_SECRET"
deno run --quiet --allow-net --allow-env client.ts no-mail-key || failures=1
stop_fn

if grep -qE '@example\.test' /work/function.log; then
  echo "    FAIL  the function's log holds no email address"; failures=1
else
  echo "    pass  the function's log holds no email address"
fi
exit "$failures"
EOF

tar -C "$WORK" -cf - . | docker run --rm -i "$IMAGE" sh -c 'mkdir -p /work && tar -xf - -C /work && sh /work/inside.sh'
code=$?
[ "$code" -eq 0 ] && echo "account-email function: all checks passed" || echo "account-email function: some checks FAILED"
exit "$code"
