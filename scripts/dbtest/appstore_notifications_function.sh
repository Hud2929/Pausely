#!/bin/bash
# Runs supabase/functions/appstore-notifications in a Deno container against a stand-in PostgREST
# server with REAL cryptographic ES256 JWS + 3-cert X.509 chains matching Apple's production PKI:
#   P-384 / SHA-384 Root CA -> P-256 WWDR Intermediate (OID + CA + keyCertSign) -> P-256 Leaf (OID)
# Tests honest, edge-case, concurrent, and hostile App Store Server Notifications v2 requests.
#
#   bash scripts/dbtest/appstore_notifications_function.sh
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
mkdir -p "$WORK/_shared" "$WORK/appstore-notifications"
cp "$ROOT/supabase/functions/_shared/http.ts" "$WORK/_shared/http.ts"
cp "${FUNCTION_FILE:-$ROOT/supabase/functions/appstore-notifications/index.ts}" "$WORK/appstore-notifications/index.ts"

# X.509 extension configs matching Apple ASSN v2 structure + hostile forged chains
cat > "$WORK/root.ext" <<'EOF'
basicConstraints=critical,CA:TRUE
keyUsage=critical,keyCertSign,cRLSign
EOF

cat > "$WORK/inter.ext" <<'EOF'
basicConstraints=critical,CA:TRUE
keyUsage=critical,keyCertSign,cRLSign
1.2.840.113635.100.6.2.1=ASN1:NULL
EOF

cat > "$WORK/inter_no_oid.ext" <<'EOF'
basicConstraints=critical,CA:TRUE
keyUsage=critical,keyCertSign,cRLSign
EOF

cat > "$WORK/inter_not_ca.ext" <<'EOF'
basicConstraints=critical,CA:FALSE
1.2.840.113635.100.6.2.1=ASN1:NULL
EOF

cat > "$WORK/inter_no_keycertsign.ext" <<'EOF'
basicConstraints=critical,CA:TRUE
keyUsage=critical,digitalSignature
1.2.840.113635.100.6.2.1=ASN1:NULL
EOF

cat > "$WORK/leaf.ext" <<'EOF'
basicConstraints=critical,CA:FALSE
1.2.840.113635.100.6.11.1=ASN1:NULL
EOF

cat > "$WORK/leaf_no_oid.ext" <<'EOF'
basicConstraints=critical,CA:FALSE
EOF

# 1. Trusted Root CA (P-384 + SHA-384, matching real Apple Root CA - G3!)
openssl ecparam -name secp384r1 -genkey -noout -out "$WORK/root.key" 2>/dev/null
openssl req -new -key "$WORK/root.key" -subj "/CN=Pausely Test Apple Root CA G3 P384" -out "$WORK/root.csr" 2>/dev/null
openssl x509 -req -in "$WORK/root.csr" -signkey "$WORK/root.key" -sha384 -days 2 -extfile "$WORK/root.ext" -out "$WORK/root.pem" 2>/dev/null
openssl x509 -in "$WORK/root.pem" -outform der -out "$WORK/root.der" 2>/dev/null
ROOT_SHA256=$(openssl dgst -sha256 -hex "$WORK/root.der" | awk '{print $NF}')

# 2. Trusted WWDR Intermediate (P-384, signed with Root CA's P-384/SHA-384 — 1:1 parity with AppleWWDRCAG6.cer!)
openssl ecparam -name secp384r1 -genkey -noout -out "$WORK/inter.key" 2>/dev/null
openssl req -new -key "$WORK/inter.key" -subj "/CN=Pausely Test WWDR Intermediate P384" -out "$WORK/inter.csr" 2>/dev/null
openssl x509 -req -in "$WORK/inter.csr" -CA "$WORK/root.pem" -CAkey "$WORK/root.key" -CAcreateserial -sha384 -days 2 -extfile "$WORK/inter.ext" -out "$WORK/inter.pem" 2>/dev/null
openssl x509 -in "$WORK/inter.pem" -outform der -out "$WORK/inter.der" 2>/dev/null
openssl pkcs8 -topk8 -nocrypt -in "$WORK/inter.key" -outform der -out "$WORK/inter.pkcs8" 2>/dev/null

# 3. Trusted App Store Leaf (P-256, signed with P-384 WWDR Intermediate SHA-384, CA=FALSE + OID 1.2.840.113635.100.6.11.1)
openssl ecparam -name prime256v1 -genkey -noout -out "$WORK/leaf.key" 2>/dev/null
openssl req -new -key "$WORK/leaf.key" -subj "/CN=Pausely Test App Store Leaf" -out "$WORK/leaf.csr" 2>/dev/null
openssl x509 -req -in "$WORK/leaf.csr" -CA "$WORK/inter.pem" -CAkey "$WORK/inter.key" -CAcreateserial -sha384 -days 2 -extfile "$WORK/leaf.ext" -out "$WORK/leaf.pem" 2>/dev/null
openssl x509 -in "$WORK/leaf.pem" -outform der -out "$WORK/leaf.der" 2>/dev/null
openssl pkcs8 -topk8 -nocrypt -in "$WORK/leaf.key" -outform der -out "$WORK/leaf.pkcs8" 2>/dev/null

# Hostile A: Developer leaf under trusted WWDR intermediate WITHOUT App Store leaf OID
openssl ecparam -name prime256v1 -genkey -noout -out "$WORK/devleaf.key" 2>/dev/null
openssl req -new -key "$WORK/devleaf.key" -subj "/CN=Random Developer Cert" -out "$WORK/devleaf.csr" 2>/dev/null
openssl x509 -req -in "$WORK/devleaf.csr" -CA "$WORK/inter.pem" -CAkey "$WORK/inter.key" -CAcreateserial -sha384 -days 2 -extfile "$WORK/leaf_no_oid.ext" -out "$WORK/devleaf.pem" 2>/dev/null
openssl x509 -in "$WORK/devleaf.pem" -outform der -out "$WORK/devleaf.der" 2>/dev/null
openssl pkcs8 -topk8 -nocrypt -in "$WORK/devleaf.key" -outform der -out "$WORK/devleaf.pkcs8" 2>/dev/null

# Hostile B: Intermediate WITHOUT WWDR OID
openssl ecparam -name prime256v1 -genkey -noout -out "$WORK/badinter.key" 2>/dev/null
openssl req -new -key "$WORK/badinter.key" -subj "/CN=Non-WWDR Intermediate" -out "$WORK/badinter.csr" 2>/dev/null
openssl x509 -req -in "$WORK/badinter.csr" -CA "$WORK/root.pem" -CAkey "$WORK/root.key" -CAcreateserial -sha384 -days 2 -extfile "$WORK/inter_no_oid.ext" -out "$WORK/badinter.pem" 2>/dev/null
openssl x509 -in "$WORK/badinter.pem" -outform der -out "$WORK/badinter.der" 2>/dev/null
openssl x509 -req -in "$WORK/leaf.csr" -CA "$WORK/badinter.pem" -CAkey "$WORK/badinter.key" -CAcreateserial -sha256 -days 2 -extfile "$WORK/leaf.ext" -out "$WORK/leaf_badinter.pem" 2>/dev/null
openssl x509 -in "$WORK/leaf_badinter.pem" -outform der -out "$WORK/leaf_badinter.der" 2>/dev/null

# Hostile C: Non-CA cert acting as intermediate
openssl ecparam -name prime256v1 -genkey -noout -out "$WORK/notca.key" 2>/dev/null
openssl req -new -key "$WORK/notca.key" -subj "/CN=Non-CA Impersonator" -out "$WORK/notca.csr" 2>/dev/null
openssl x509 -req -in "$WORK/notca.csr" -CA "$WORK/root.pem" -CAkey "$WORK/root.key" -CAcreateserial -sha384 -days 2 -extfile "$WORK/inter_not_ca.ext" -out "$WORK/notca.pem" 2>/dev/null
openssl x509 -in "$WORK/notca.pem" -outform der -out "$WORK/notca.der" 2>/dev/null
openssl x509 -req -in "$WORK/leaf.csr" -CA "$WORK/notca.pem" -CAkey "$WORK/notca.key" -CAcreateserial -sha256 -days 2 -extfile "$WORK/leaf.ext" -out "$WORK/leaf_notca.pem" 2>/dev/null
openssl x509 -in "$WORK/leaf_notca.pem" -outform der -out "$WORK/leaf_notca.der" 2>/dev/null

# Hostile D: CA intermediate missing keyCertSign in KeyUsage
openssl ecparam -name prime256v1 -genkey -noout -out "$WORK/nokcs.key" 2>/dev/null
openssl req -new -key "$WORK/nokcs.key" -subj "/CN=No KeyCertSign Intermediate" -out "$WORK/nokcs.csr" 2>/dev/null
openssl x509 -req -in "$WORK/nokcs.csr" -CA "$WORK/root.pem" -CAkey "$WORK/root.key" -CAcreateserial -sha384 -days 2 -extfile "$WORK/inter_no_keycertsign.ext" -out "$WORK/nokcs.pem" 2>/dev/null
openssl x509 -in "$WORK/nokcs.pem" -outform der -out "$WORK/nokcs.der" 2>/dev/null
openssl x509 -req -in "$WORK/leaf.csr" -CA "$WORK/nokcs.pem" -CAkey "$WORK/nokcs.key" -CAcreateserial -sha256 -days 2 -extfile "$WORK/leaf.ext" -out "$WORK/leaf_nokcs.pem" 2>/dev/null
openssl x509 -in "$WORK/leaf_nokcs.pem" -outform der -out "$WORK/leaf_nokcs.der" 2>/dev/null

# Hostile E: Completely untrusted rogue 3-cert chain
openssl ecparam -name secp384r1 -genkey -noout -out "$WORK/rogue.key" 2>/dev/null
openssl req -new -key "$WORK/rogue.key" -subj "/CN=Rogue Attacker CA" -out "$WORK/rogue.csr" 2>/dev/null
openssl x509 -req -in "$WORK/rogue.csr" -signkey "$WORK/rogue.key" -sha384 -days 2 -extfile "$WORK/root.ext" -out "$WORK/rogue.pem" 2>/dev/null
openssl x509 -in "$WORK/rogue.pem" -outform der -out "$WORK/rogue.der" 2>/dev/null
openssl x509 -req -in "$WORK/inter.csr" -CA "$WORK/rogue.pem" -CAkey "$WORK/rogue.key" -CAcreateserial -sha384 -days 2 -extfile "$WORK/inter.ext" -out "$WORK/rogue_inter.pem" 2>/dev/null
openssl x509 -in "$WORK/rogue_inter.pem" -outform der -out "$WORK/rogue_inter.der" 2>/dev/null
openssl x509 -req -in "$WORK/leaf.csr" -CA "$WORK/rogue_inter.pem" -CAkey "$WORK/inter.key" -CAcreateserial -sha256 -days 2 -extfile "$WORK/leaf.ext" -out "$WORK/rogue_leaf.pem" 2>/dev/null
openssl x509 -in "$WORK/rogue_leaf.pem" -outform der -out "$WORK/rogue_leaf.der" 2>/dev/null

printf '%s' "$ROOT_SHA256" > "$WORK/root_sha256.txt"

# ---- stand-in PostgREST RPC mirroring atomic `public.upsert_app_store_entitlement` ----
cat > "$WORK/mock.ts" <<'EOF'
const KNOWN_USERS = new Set(['aaaaaaaa-0000-4000-8000-000000000001'])
let rows: Record<string, Record<string, unknown>> = {}

Deno.serve({ port: 54321, onListen() {} }, async (req) => {
  const url = new URL(req.url)
  if (url.pathname === '/__rows') return Response.json(rows)
  if (url.pathname === '/__reset') { rows = {}; return new Response('ok') }

  if (url.pathname === '/rest/v1/rpc/upsert_app_store_entitlement' && req.method === 'POST') {
    if (req.headers.get('apikey') !== 'service-role-key') {
      return Response.json({ message: 'unauthorized' }, { status: 401 })
    }
    const body = await req.json()
    const txId = String(body.p_original_transaction_id)
    if (txId === 'tx-db-error') {
      return Response.json({ message: 'simulated db outage' }, { status: 500 })
    }
    const existing = rows[txId]
    const incomingMs = Date.parse(String(body.p_last_signed_date))
    const prevMs = existing?.last_signed_date ? Date.parse(String(existing.last_signed_date)) : NaN
    if (existing && !Number.isNaN(prevMs) && incomingMs <= prevMs) {
      return Response.json([{ applied: false, current_status: existing.status }])
    }

    let userId: string | null = body.p_user_id ? String(body.p_user_id) : null
    if (userId && !KNOWN_USERS.has(userId)) {
      // Mirrors Postgres FK 23503 fallback inside the atomic RPC.
      userId = null
    }
    const resolvedUserId = userId ?? (existing?.user_id ?? null)
    const terminalAutoRenew = (body.p_status === 'refunded' || body.p_status === 'revoked' || body.p_status === 'expired') ? false : null
    const resolvedAutoRenew = body.p_will_auto_renew ?? terminalAutoRenew ?? (existing?.will_auto_renew ?? null)

    rows[txId] = {
      original_transaction_id: txId,
      user_id: resolvedUserId,
      product_id: body.p_product_id,
      status: body.p_status,
      environment: body.p_environment,
      will_auto_renew: resolvedAutoRenew,
      expires_at: body.p_expires_at,
      last_notification_type: body.p_last_notification_type,
      last_signed_date: body.p_last_signed_date,
    }
    return Response.json([{ applied: true, current_status: body.p_status }])
  }
  return new Response('not found', { status: 404 })
})
EOF

# ---- cryptographic test client ----
cat > "$WORK/client.ts" <<'EOF'
const FUNCTION = 'http://127.0.0.1:8000'
const STAND_IN = 'http://127.0.0.1:54321'
const APP_APPLE_ID = 6759973158
const NOW = Date.now()
const FUTURE_EXP = NOW + 30 * 86400 * 1000
const PAST_EXP = NOW - 86400 * 1000
let failed = 0

function check(label: string, ok: boolean, detail = '') {
  if (ok) console.log(`    pass  ${label}`)
  else { failed++; console.log(`    FAIL  ${label}\n          ${detail}`) }
}

const b64 = (bytes: Uint8Array) => {
  let s = ''
  for (const b of bytes) s += String.fromCharCode(b)
  return btoa(s)
}
const b64urlBytes = (bytes: Uint8Array) => b64(bytes).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
const b64urlJson = (value: unknown) => b64urlBytes(new TextEncoder().encode(JSON.stringify(value)))
const readB64 = async (p: string) => b64(await Deno.readFile(p))

const leafKey = await crypto.subtle.importKey('pkcs8', await Deno.readFile('/work/leaf.pkcs8'), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'])
const devLeafKey = await crypto.subtle.importKey('pkcs8', await Deno.readFile('/work/devleaf.pkcs8'), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'])
const interKey = await crypto.subtle.importKey('pkcs8', await Deno.readFile('/work/inter.pkcs8'), { name: 'ECDSA', namedCurve: 'P-384' }, false, ['sign'])

function derEncodeLen(len: number): Uint8Array {
  if (len < 128) return new Uint8Array([len])
  const bytes: number[] = []
  let n = len
  while (n > 0) { bytes.unshift(n & 0xff); n >>= 8 }
  return new Uint8Array([0x80 | bytes.length, ...bytes])
}
function derWrap(tag: number, content: Uint8Array): Uint8Array {
  const len = derEncodeLen(content.length)
  const out = new Uint8Array(1 + len.length + content.length)
  out[0] = tag; out.set(len, 1); out.set(content, 1 + len.length)
  return out
}
function derInt(raw: Uint8Array): Uint8Array {
  let i = 0; while (i < raw.length - 1 && raw[i] === 0) i++
  let slice = raw.subarray(i)
  if (slice[0] & 0x80) { const p = new Uint8Array(slice.length + 1); p.set(slice, 1); slice = p }
  return derWrap(0x02, slice)
}
async function makeExpiredLeafB64(): Promise<string> {
  const leafDer = new Uint8Array(await Deno.readFile('/work/leaf.der'))
  const readLen = (b: Uint8Array, o: number) => {
    const lb = b[o + 1]
    if ((lb & 0x80) === 0) return { len: lb, vs: o + 2 }
    const n = lb & 0x7f; let l = 0
    for (let i = 0; i < n; i++) l = l * 256 + b[o + 2 + i]
    return { len: l, vs: o + 2 + n }
  }
  const outer = readLen(leafDer, 0)
  const tbsHdr = readLen(leafDer, outer.vs)
  const tbsEnd = tbsHdr.vs + tbsHdr.len
  const sigAlgHdr = readLen(leafDer, tbsEnd)
  const sigAlgEnd = sigAlgHdr.vs + sigAlgHdr.len
  const tbsCopy = new Uint8Array(leafDer.subarray(outer.vs, tbsEnd))
  let replaced = 0
  const enc = new TextEncoder()
  for (let i = 0; i + 15 <= tbsCopy.length; i++) {
    if (tbsCopy[i] === 0x17 && tbsCopy[i + 1] === 0x0d && tbsCopy[i + 14] === 0x5a) {
      tbsCopy.set(enc.encode(replaced === 0 ? '200101000000Z' : '200102000000Z'), i + 2)
      replaced++
      i += 14
      if (replaced === 2) break
    }
  }
  const rawSig = new Uint8Array(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-384' }, interKey, tbsCopy))
  const r = derInt(rawSig.subarray(0, 48))
  const s = derInt(rawSig.subarray(48, 96))
  const rs = new Uint8Array(r.length + s.length); rs.set(r, 0); rs.set(s, r.length)
  const derSig = derWrap(0x30, rs)
  const bitContent = new Uint8Array(1 + derSig.length); bitContent[0] = 0x00; bitContent.set(derSig, 1)
  const bitStr = derWrap(0x03, bitContent)
  const sigAlgBytes = leafDer.subarray(tbsEnd, sigAlgEnd)
  const certBody = new Uint8Array(tbsCopy.length + sigAlgBytes.length + bitStr.length)
  certBody.set(tbsCopy, 0); certBody.set(sigAlgBytes, tbsCopy.length); certBody.set(bitStr, tbsCopy.length + sigAlgBytes.length)
  return b64(derWrap(0x30, certBody))
}

const trustedChain = [await readB64('/work/leaf.der'), await readB64('/work/inter.der'), await readB64('/work/root.der')]
const noLeafOidChain = [await readB64('/work/devleaf.der'), await readB64('/work/inter.der'), await readB64('/work/root.der')]
const noInterOidChain = [await readB64('/work/leaf_badinter.der'), await readB64('/work/badinter.der'), await readB64('/work/root.der')]
const nonCaInterChain = [await readB64('/work/leaf_notca.der'), await readB64('/work/notca.der'), await readB64('/work/root.der')]
const noKeyCertSignChain = [await readB64('/work/leaf_nokcs.der'), await readB64('/work/nokcs.der'), await readB64('/work/root.der')]
const brokenDnChain = [await readB64('/work/leaf_badinter.der'), await readB64('/work/inter.der'), await readB64('/work/root.der')]
const expiredLeafChain = [await makeExpiredLeafB64(), await readB64('/work/inter.der'), await readB64('/work/root.der')]
const rogueChain = [await readB64('/work/rogue_leaf.der'), await readB64('/work/rogue_inter.der'), await readB64('/work/rogue.der')]
const shortChain = [await readB64('/work/leaf.der'), await readB64('/work/root.der')]
const negLenCert = b64(new Uint8Array([0x30, 0x84, 0xff, 0xff, 0xff, 0xfa, 0x05, 0x00, 0x05, 0x00]))
const malformedDerChain = [negLenCert, await readB64('/work/inter.der'), await readB64('/work/root.der')]

async function signJWS(payload: Record<string, unknown>, key = leafKey, x5c = trustedChain, alg = 'ES256') {
  const header = { alg, x5c }
  const input = `${b64urlJson(header)}.${b64urlJson(payload)}`
  const sig = new Uint8Array(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, new TextEncoder().encode(input)))
  return `${input}.${b64urlBytes(sig)}`
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

const phase = Deno.args[0] ?? 'main'
await reset()

if (phase === 'main') {
  const viaGet = await fetch(FUNCTION); await viaGet.text()
  check('only POST is accepted', viaGet.status === 405, `got ${viaGet.status}`)
  let ans = await post('not-json')
  check('non-JSON body is refused', ans.status === 400, `got ${ans.status}`)
  ans = await post({ signedPayload: 'not-a-jws' })
  check('malformed JWS is refused', ans.status === 400, `got ${ans.status}`)
  ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, leafKey, trustedChain, 'HS256') })
  check('non-ES256 JWS is refused', ans.status === 400, `got ${ans.status}`)

  // Cryptographic & X.509 PKI tests (against P-384/SHA-384 Root CA!)
  const validTestJws = await signJWS({ notificationType: 'TEST', data: {} })
  const parts = validTestJws.split('.')
  ans = await post({ signedPayload: `${parts[0]}.${parts[1]}.${b64urlBytes(new Uint8Array(64).fill(7))}` })
  check('forged ES256 signature is rejected with 401', ans.status === 401, ans.text)
  ans = await post({ signedPayload: `${parts[0]}.${b64urlJson({ notificationType: 'SUBSCRIBED', data: {} })}.${parts[2]}` })
  check('tampered JWS payload is rejected with 401', ans.status === 401, ans.text)
  ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, leafKey, rogueChain) })
  check('untrusted P-384 root CA chain is rejected with 401', ans.status === 401, ans.text)
  ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, leafKey, shortChain) })
  check('2-cert chain missing intermediate is rejected with 401', ans.status === 401, ans.text)
  ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, devLeafKey, noLeafOidChain) })
  check('cert chain missing Apple App Store leaf OID is rejected with 401', ans.status === 401 && ans.json?.error === 'missing_apple_leaf_oid', ans.text)
  ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, leafKey, noInterOidChain) })
  check('cert chain missing Apple WWDR intermediate OID is rejected with 401', ans.status === 401 && ans.json?.error === 'missing_apple_intermediate_oid', ans.text)
  ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, leafKey, nonCaInterChain) })
  check('non-CA cert acting as intermediate is rejected with 401', ans.status === 401 && ans.json?.error === 'issuer_not_ca', ans.text)
  ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, leafKey, noKeyCertSignChain) })
  check('CA cert lacking KeyUsage keyCertSign is rejected with 401', ans.status === 401 && ans.json?.error === 'issuer_missing_key_cert_sign', ans.text)
  ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, leafKey, brokenDnChain) })
  check('broken DN chain is rejected with 401', ans.status === 401 && ans.json?.error === 'broken_dn_chain', ans.text)
  ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, leafKey, expiredLeafChain) })
  check('expired leaf certificate is rejected with 401', ans.status === 401 && ans.json?.error === 'expired_certificate', ans.text)
  ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, leafKey, malformedDerChain) })
  check('crafted 4-byte negative-length DER cert rejects immediately with 401', ans.status === 401 && ans.json?.error === 'invalid_x5c', ans.text)
  ans = await post('{"signedPayload":"' + 'A'.repeat(270 * 1024) + '"}')
  check('oversized body (>256KB) is rejected with 413', ans.status === 413, `got ${ans.status}`)

  // Honest signed TEST (verifies full P-384/SHA-384 Root -> P-256 Intermediate -> P-256 Leaf chain!)
  ans = await post({ signedPayload: validTestJws })
  check('signed Apple TEST notification verifies P-384/SHA-384 root chain without touching DB', ans.status === 200 && ans.json?.test === true && Object.keys(await rows()).length === 0, ans.text)

  // Non-transaction summary notification (RENEWAL_EXTENSION:SUMMARY) acknowledged cleanly with 200
  ans = await post({
    signedPayload: await signJWS({
      notificationType: 'RENEWAL_EXTENSION',
      subtype: 'SUMMARY',
      signedDate: NOW,
      data: { bundleId: 'com.pausely.app.Pausely', appAppleId: APP_APPLE_ID, environment: 'Production' },
    }),
  })
  check('RENEWAL_EXTENSION:SUMMARY (no signedTransactionInfo) is acknowledged with 200', ans.status === 200 && ans.json?.ignored === 'non_transaction_notification', ans.text)

  // Bundle ID, appAppleId, and Environment checks
  const txAnnual = await signJWS({
    originalTransactionId: '10000001',
    bundleId: 'com.pausely.app.Pausely',
    productId: 'com.pausely.premium.annual',
    environment: 'Production',
    offerType: 1,
    offerDiscountType: 'FREE_TRIAL',
    expiresDate: FUTURE_EXP,
    appAccountToken: 'AAAAAAAA-0000-4000-8000-000000000001',
    signedDate: NOW,
  })
  const renewOn = await signJWS({
    originalTransactionId: '10000001',
    environment: 'Production',
    autoRenewStatus: 1,
    signedDate: NOW,
  })

  ans = await post({
    signedPayload: await signJWS({
      notificationType: 'SUBSCRIBED',
      signedDate: NOW,
      data: { bundleId: 'com.evil.other', appAppleId: APP_APPLE_ID, environment: 'Production', signedTransactionInfo: txAnnual },
    }),
  })
  check('wrong outer bundle id is refused with 403', ans.status === 403 && ans.json?.error === 'wrong_bundle_id', ans.text)

  ans = await post({
    signedPayload: await signJWS({
      notificationType: 'SUBSCRIBED',
      signedDate: NOW,
      data: { bundleId: 'com.pausely.app.Pausely', appAppleId: 999999, environment: 'Production', signedTransactionInfo: txAnnual },
    }),
  })
  check('wrong Production appAppleId is refused with 403', ans.status === 403 && ans.json?.error === 'wrong_app_apple_id', ans.text)

  ans = await post({
    signedPayload: await signJWS({
      notificationType: 'SUBSCRIBED',
      signedDate: NOW,
      data: { bundleId: 'com.pausely.app.Pausely', appAppleId: APP_APPLE_ID, environment: 'Xcode', signedTransactionInfo: txAnnual },
    }),
  })
  check('invalid environment value is rejected with 400', ans.status === 400 && ans.json?.error === 'invalid_environment', ans.text)

  // Cross-transaction & cross-environment signedRenewalInfo tampering MUST fail!
  const renewWrongTx = await signJWS({ originalTransactionId: '99999999', environment: 'Production', autoRenewStatus: 0, signedDate: NOW })
  ans = await post({
    signedPayload: await signJWS({
      notificationType: 'SUBSCRIBED',
      signedDate: NOW,
      data: { bundleId: 'com.pausely.app.Pausely', appAppleId: APP_APPLE_ID, environment: 'Production', signedTransactionInfo: txAnnual, signedRenewalInfo: renewWrongTx },
    }),
  })
  check('signedRenewalInfo for another transaction is rejected with 400', ans.status === 400 && ans.json?.error === 'renewal_transaction_mismatch', ans.text)

  const renewWrongEnv = await signJWS({ originalTransactionId: '10000001', environment: 'Sandbox', autoRenewStatus: 0, signedDate: NOW })
  ans = await post({
    signedPayload: await signJWS({
      notificationType: 'SUBSCRIBED',
      signedDate: NOW,
      data: { bundleId: 'com.pausely.app.Pausely', appAppleId: APP_APPLE_ID, environment: 'Production', signedTransactionInfo: txAnnual, signedRenewalInfo: renewWrongEnv },
    }),
  })
  check('signedRenewalInfo for wrong environment is rejected with 400', ans.status === 400 && ans.json?.error === 'renewal_environment_mismatch', ans.text)

  // Honest free-trial signup -> trial + lowercased user_id (timestamps strictly inside newly minted cert validity window)
  const T0 = NOW + 1_000
  ans = await post({
    signedPayload: await signJWS({
      notificationType: 'SUBSCRIBED',
      subtype: 'INITIAL_BUY',
      signedDate: T0 + 1_000,
      data: { bundleId: 'com.pausely.app.Pausely', appAppleId: APP_APPLE_ID, environment: 'Production', signedTransactionInfo: txAnnual, signedRenewalInfo: renewOn },
    }),
  })
  let stored = await rows()
  check('signed free-trial signup records trial with lowercased user_id', ans.status === 200 && stored['10000001']?.status === 'trial' && stored['10000001']?.user_id === 'aaaaaaaa-0000-4000-8000-000000000001' && stored['10000001']?.will_auto_renew === true, JSON.stringify(stored))

  // Win-Back free trial (offerType=4, offerDiscountType=FREE_TRIAL) -> trial!
  const txWinBack = await signJWS({
    originalTransactionId: '10000044',
    bundleId: 'com.pausely.app.Pausely',
    productId: 'com.pausely.premium.monthly',
    environment: 'Production',
    offerType: 4,
    offerDiscountType: 'FREE_TRIAL',
    expiresDate: FUTURE_EXP,
    signedDate: T0 + 2_000,
  })
  ans = await post({
    signedPayload: await signJWS({
      notificationType: 'SUBSCRIBED',
      subtype: 'RESUBSCRIBE',
      signedDate: T0 + 2_000,
      data: { bundleId: 'com.pausely.app.Pausely', appAppleId: APP_APPLE_ID, environment: 'Production', signedTransactionInfo: txWinBack },
    }),
  })
  stored = await rows()
  check('Win-Back free trial (offerType=4, FREE_TRIAL) is recorded as trial', ans.status === 200 && stored['10000044']?.status === 'trial', JSON.stringify(stored))

  // DID_RENEW omitting appAccountToken preserves user_id
  const txRenew = await signJWS({
    originalTransactionId: '10000001',
    bundleId: 'com.pausely.app.Pausely',
    productId: 'com.pausely.premium.annual',
    environment: 'Production',
    expiresDate: FUTURE_EXP,
    signedDate: T0 + 3_000,
  })
  ans = await post({
    signedPayload: await signJWS({
      notificationType: 'DID_RENEW',
      signedDate: T0 + 3_000,
      data: { bundleId: 'com.pausely.app.Pausely', appAppleId: APP_APPLE_ID, environment: 'Production', signedTransactionInfo: txRenew },
    }),
  })
  stored = await rows()
  check('DID_RENEW omitting appAccountToken preserves user_id', ans.status === 200 && stored['10000001']?.status === 'active' && stored['10000001']?.user_id === 'aaaaaaaa-0000-4000-8000-000000000001', JSON.stringify(stored))

  // DID_FAIL_TO_RENEW (no subtype) -> billing_retry
  ans = await post({
    signedPayload: await signJWS({
      notificationType: 'DID_FAIL_TO_RENEW',
      signedDate: T0 + 4_000,
      data: { bundleId: 'com.pausely.app.Pausely', appAppleId: APP_APPLE_ID, environment: 'Production', signedTransactionInfo: txRenew },
    }),
  })
  stored = await rows()
  check('DID_FAIL_TO_RENEW without GRACE_PERIOD records billing_retry', ans.status === 200 && stored['10000001']?.status === 'billing_retry', JSON.stringify(stored))

  // DID_CHANGE_RENEWAL_STATUS during active grace period (expiresDate in past, gracePeriodExpiresDate in future) MUST stay grace_period!
  const txPastExp = await signJWS({
    originalTransactionId: '10000001',
    bundleId: 'com.pausely.app.Pausely',
    productId: 'com.pausely.premium.annual',
    environment: 'Production',
    expiresDate: PAST_EXP,
    signedDate: T0 + 5_000,
  })
  const renewInGrace = await signJWS({
    originalTransactionId: '10000001',
    environment: 'Production',
    autoRenewStatus: 0,
    gracePeriodExpiresDate: FUTURE_EXP,
    signedDate: T0 + 5_000,
  })
  ans = await post({
    signedPayload: await signJWS({
      notificationType: 'DID_CHANGE_RENEWAL_STATUS',
      subtype: 'AUTO_RENEW_DISABLED',
      signedDate: T0 + 5_000,
      data: { bundleId: 'com.pausely.app.Pausely', appAppleId: APP_APPLE_ID, environment: 'Production', signedTransactionInfo: txPastExp, signedRenewalInfo: renewInGrace },
    }),
  })
  stored = await rows()
  check('DID_CHANGE_RENEWAL_STATUS during active grace period keeps grace_period (not expired)', ans.status === 200 && stored['10000001']?.status === 'grace_period' && stored['10000001']?.will_auto_renew === false, JSON.stringify(stored))

  // GRACE_PERIOD_EXPIRED -> expired
  ans = await post({
    signedPayload: await signJWS({
      notificationType: 'GRACE_PERIOD_EXPIRED',
      signedDate: T0 + 6_000,
      data: { bundleId: 'com.pausely.app.Pausely', appAppleId: APP_APPLE_ID, environment: 'Production', signedTransactionInfo: txPastExp },
    }),
  })
  stored = await rows()
  check('GRACE_PERIOD_EXPIRED transitions status to expired', ans.status === 200 && stored['10000001']?.status === 'expired', JSON.stringify(stored))

  // Concurrent out-of-order REFUND (newer) + DID_RENEW (older) -> REFUND wins atomically!
  const refundPayload = await signJWS({
    notificationType: 'REFUND',
    signedDate: T0 + 9_000,
    data: { bundleId: 'com.pausely.app.Pausely', appAppleId: APP_APPLE_ID, environment: 'Production', signedTransactionInfo: txRenew },
  })
  const staleRenewPayload = await signJWS({
    notificationType: 'DID_RENEW',
    signedDate: T0 + 7_000,
    data: { bundleId: 'com.pausely.app.Pausely', appAppleId: APP_APPLE_ID, environment: 'Production', signedTransactionInfo: txRenew },
  })
  await Promise.all([post({ signedPayload: refundPayload }), post({ signedPayload: staleRenewPayload })])
  stored = await rows()
  check('concurrent REFUND + older DID_RENEW never reverts status away from refunded', stored['10000001']?.status === 'refunded', JSON.stringify(stored))

  // REVOKE -> revoked
  const txRevoke = await signJWS({
    originalTransactionId: '10000055',
    bundleId: 'com.pausely.app.Pausely',
    productId: 'com.pausely.premium.annual',
    environment: 'Production',
    revocationDate: T0 + 10_000,
    signedDate: T0 + 10_000,
  })
  ans = await post({
    signedPayload: await signJWS({
      notificationType: 'REVOKE',
      signedDate: T0 + 10_000,
      data: { bundleId: 'com.pausely.app.Pausely', appAppleId: APP_APPLE_ID, environment: 'Production', signedTransactionInfo: txRevoke },
    }),
  })
  stored = await rows()
  check('REVOKE updates status to revoked', ans.status === 200 && stored['10000055']?.status === 'revoked', JSON.stringify(stored))

  // Deleted-user FK fallback inside atomic RPC -> user_id = null cleanly
  const txDeleted = await signJWS({
    originalTransactionId: '10000099',
    bundleId: 'com.pausely.app.Pausely',
    productId: 'com.pausely.premium.monthly',
    environment: 'Production',
    appAccountToken: '99999999-0000-4000-8000-000000000099',
    signedDate: T0 + 11_000,
  })
  ans = await post({
    signedPayload: await signJWS({
      notificationType: 'REFUND',
      signedDate: T0 + 11_000,
      data: { bundleId: 'com.pausely.app.Pausely', appAppleId: APP_APPLE_ID, environment: 'Production', signedTransactionInfo: txDeleted },
    }),
  })
  stored = await rows()
  check('deleted-user appAccountToken stores user_id=null cleanly instead of 500', ans.status === 200 && stored['10000099']?.user_id === null && stored['10000099']?.status === 'refunded', ans.text)

  // Transient DB failure -> fails closed with 500
  const txErr = await signJWS({
    originalTransactionId: 'tx-db-error',
    bundleId: 'com.pausely.app.Pausely',
    productId: 'com.pausely.premium.annual',
    environment: 'Production',
    signedDate: T0 + 12_000,
  })
  ans = await post({
    signedPayload: await signJWS({
      notificationType: 'DID_RENEW',
      signedDate: T0 + 12_000,
      data: { bundleId: 'com.pausely.app.Pausely', appAppleId: APP_APPLE_ID, environment: 'Production', signedTransactionInfo: txErr },
    }),
  })
  check('transient DB RPC failure fails closed with 500', ans.status === 500 && ans.json?.error === 'db_error', ans.text)
}

if (phase === 'prod-only') {
  const txSandbox = await signJWS({
    originalTransactionId: '10000999',
    bundleId: 'com.pausely.app.Pausely',
    productId: 'com.pausely.premium.annual',
    environment: 'Sandbox',
    expiresDate: FUTURE_EXP,
    signedDate: NOW,
  })
  const ans = await post({
    signedPayload: await signJWS({
      notificationType: 'SUBSCRIBED',
      signedDate: NOW,
      data: { bundleId: 'com.pausely.app.Pausely', environment: 'Sandbox', signedTransactionInfo: txSandbox },
    }),
  })
  check('when APP_STORE_ALLOW_SANDBOX=false, Sandbox notifications are rejected with 403', ans.status === 403 && ans.json?.error === 'sandbox_not_allowed', ans.text)
}

Deno.exit(failed === 0 ? 0 : 1)
EOF

cat > "$WORK/inside.sh" <<'EOF'
cd /work
ROOT_HASH=$(cat /work/root_sha256.txt)
deno run --quiet --allow-net mock.ts &

start_fn() {
  env SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_SERVICE_ROLE_KEY=service-role-key APP_STORE_BUNDLE_ID=com.pausely.app.Pausely APP_STORE_APP_APPLE_ID=6759973158 APP_STORE_TEST_ROOT_SHA256="$ROOT_HASH" "$@" \
    deno run --quiet --allow-net --allow-env appstore-notifications/index.ts >> /work/function.log 2>&1 &
  FUNCTION_PID=$!
  for _ in $(seq 1 240); do
    if deno eval --quiet "try { await (await fetch('http://127.0.0.1:8000')).text() } catch { Deno.exit(1) }" 2>/dev/null; then
      return 0
    fi
    sleep 0.5
  done
  echo "The function did not start:"; cat /work/function.log; exit 1
}
stop_fn() { kill "$FUNCTION_PID" 2>/dev/null; wait "$FUNCTION_PID" 2>/dev/null; }

failures=0
deno check --quiet appstore-notifications/index.ts && echo "    pass  the function type-checks" || { echo "    FAIL  the function type-checks"; failures=1; }

echo "  production + sandbox notifications (P-384/SHA-384 root chain)"
start_fn
deno run --quiet --allow-net --allow-read client.ts main || failures=1
stop_fn

echo "  production-only isolation (APP_STORE_ALLOW_SANDBOX=false)"
start_fn APP_STORE_ALLOW_SANDBOX=false
deno run --quiet --allow-net --allow-read client.ts prod-only || failures=1
stop_fn

exit "$failures"
EOF

tar -C "$WORK" -cf - . | docker run --rm -i "$IMAGE" sh -c 'mkdir -p /work && tar -xf - -C /work && sh /work/inside.sh'
code=$?
if [ "$code" -eq 0 ]; then echo "appstore-notifications: every check passed"; else echo "appstore-notifications: FAILED"; fi
exit "$code"
