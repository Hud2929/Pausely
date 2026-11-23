#!/bin/bash
# Runs supabase/functions/appstore-notifications in a Deno container against a stand-in PostgREST
# server with REAL cryptographic ES256 JWS + 3-cert X.509 certificate chains (Root CA -> WWDR
# Intermediate -> App Store Leaf with Apple OIDs & BasicConstraints) and tests both honest and
# hostile App Store Server Notifications v2 requests.
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

cat > "$WORK/leaf.ext" <<'EOF'
basicConstraints=critical,CA:FALSE
1.2.840.113635.100.6.11.1=ASN1:NULL
EOF

cat > "$WORK/leaf_no_oid.ext" <<'EOF'
basicConstraints=critical,CA:FALSE
EOF

# 1. Trusted Root CA (P-256, CA=TRUE) — two-step CSR + x509 -req works on both macOS LibreSSL and OpenSSL 3
openssl ecparam -name prime256v1 -genkey -noout -out "$WORK/root.key" 2>/dev/null
openssl req -new -key "$WORK/root.key" -subj "/CN=Pausely Test Apple Root CA G3" -out "$WORK/root.csr" 2>/dev/null
openssl x509 -req -in "$WORK/root.csr" -signkey "$WORK/root.key" -sha256 -days 2 -extfile "$WORK/root.ext" -out "$WORK/root.pem" 2>/dev/null
openssl x509 -in "$WORK/root.pem" -outform der -out "$WORK/root.der" 2>/dev/null
ROOT_SHA256=$(openssl dgst -sha256 -hex "$WORK/root.der" | awk '{print $NF}')

# 2. Trusted WWDR Intermediate (CA=TRUE + OID 1.2.840.113635.100.6.2.1)
openssl ecparam -name prime256v1 -genkey -noout -out "$WORK/inter.key" 2>/dev/null
openssl req -new -key "$WORK/inter.key" -subj "/CN=Pausely Test WWDR Intermediate" -out "$WORK/inter.csr" 2>/dev/null
openssl x509 -req -in "$WORK/inter.csr" -CA "$WORK/root.pem" -CAkey "$WORK/root.key" -CAcreateserial -sha256 -days 2 -extfile "$WORK/inter.ext" -out "$WORK/inter.pem" 2>/dev/null
openssl x509 -in "$WORK/inter.pem" -outform der -out "$WORK/inter.der" 2>/dev/null
openssl pkcs8 -topk8 -nocrypt -in "$WORK/inter.key" -outform der -out "$WORK/inter.pkcs8" 2>/dev/null

# 3. Trusted App Store Leaf (CA=FALSE + OID 1.2.840.113635.100.6.11.1)
openssl ecparam -name prime256v1 -genkey -noout -out "$WORK/leaf.key" 2>/dev/null
openssl req -new -key "$WORK/leaf.key" -subj "/CN=Pausely Test App Store Leaf" -out "$WORK/leaf.csr" 2>/dev/null
openssl x509 -req -in "$WORK/leaf.csr" -CA "$WORK/inter.pem" -CAkey "$WORK/inter.key" -CAcreateserial -sha256 -days 2 -extfile "$WORK/leaf.ext" -out "$WORK/leaf.pem" 2>/dev/null
openssl x509 -in "$WORK/leaf.pem" -outform der -out "$WORK/leaf.der" 2>/dev/null
openssl pkcs8 -topk8 -nocrypt -in "$WORK/leaf.key" -outform der -out "$WORK/leaf.pkcs8" 2>/dev/null

# Hostile A: Developer leaf under trusted WWDR intermediate WITHOUT App Store leaf OID
openssl ecparam -name prime256v1 -genkey -noout -out "$WORK/devleaf.key" 2>/dev/null
openssl req -new -key "$WORK/devleaf.key" -subj "/CN=Random Developer Cert" -out "$WORK/devleaf.csr" 2>/dev/null
openssl x509 -req -in "$WORK/devleaf.csr" -CA "$WORK/inter.pem" -CAkey "$WORK/inter.key" -CAcreateserial -sha256 -days 2 -extfile "$WORK/leaf_no_oid.ext" -out "$WORK/devleaf.pem" 2>/dev/null
openssl x509 -in "$WORK/devleaf.pem" -outform der -out "$WORK/devleaf.der" 2>/dev/null
openssl pkcs8 -topk8 -nocrypt -in "$WORK/devleaf.key" -outform der -out "$WORK/devleaf.pkcs8" 2>/dev/null

# Hostile B: Intermediate WITHOUT WWDR OID + leaf with App Store OID
openssl ecparam -name prime256v1 -genkey -noout -out "$WORK/badinter.key" 2>/dev/null
openssl req -new -key "$WORK/badinter.key" -subj "/CN=Non-WWDR Intermediate" -out "$WORK/badinter.csr" 2>/dev/null
openssl x509 -req -in "$WORK/badinter.csr" -CA "$WORK/root.pem" -CAkey "$WORK/root.key" -CAcreateserial -sha256 -days 2 -extfile "$WORK/inter_no_oid.ext" -out "$WORK/badinter.pem" 2>/dev/null
openssl x509 -in "$WORK/badinter.pem" -outform der -out "$WORK/badinter.der" 2>/dev/null
openssl x509 -req -in "$WORK/leaf.csr" -CA "$WORK/badinter.pem" -CAkey "$WORK/badinter.key" -CAcreateserial -sha256 -days 2 -extfile "$WORK/leaf.ext" -out "$WORK/leaf_badinter.pem" 2>/dev/null
openssl x509 -in "$WORK/leaf_badinter.pem" -outform der -out "$WORK/leaf_badinter.der" 2>/dev/null

# Hostile C: Non-CA cert (CA:FALSE) acting as intermediate to sign a leaf
openssl ecparam -name prime256v1 -genkey -noout -out "$WORK/notca.key" 2>/dev/null
openssl req -new -key "$WORK/notca.key" -subj "/CN=Non-CA Impersonator" -out "$WORK/notca.csr" 2>/dev/null
openssl x509 -req -in "$WORK/notca.csr" -CA "$WORK/root.pem" -CAkey "$WORK/root.key" -CAcreateserial -sha256 -days 2 -extfile "$WORK/inter_not_ca.ext" -out "$WORK/notca.pem" 2>/dev/null
openssl x509 -in "$WORK/notca.pem" -outform der -out "$WORK/notca.der" 2>/dev/null
openssl x509 -req -in "$WORK/leaf.csr" -CA "$WORK/notca.pem" -CAkey "$WORK/notca.key" -CAcreateserial -sha256 -days 2 -extfile "$WORK/leaf.ext" -out "$WORK/leaf_notca.pem" 2>/dev/null
openssl x509 -in "$WORK/leaf_notca.pem" -outform der -out "$WORK/leaf_notca.der" 2>/dev/null

# Hostile D: Completely untrusted rogue 3-cert chain
openssl ecparam -name prime256v1 -genkey -noout -out "$WORK/rogue.key" 2>/dev/null
openssl req -new -key "$WORK/rogue.key" -subj "/CN=Rogue Attacker CA" -out "$WORK/rogue.csr" 2>/dev/null
openssl x509 -req -in "$WORK/rogue.csr" -signkey "$WORK/rogue.key" -sha256 -days 2 -extfile "$WORK/root.ext" -out "$WORK/rogue.pem" 2>/dev/null
openssl x509 -in "$WORK/rogue.pem" -outform der -out "$WORK/rogue.der" 2>/dev/null
openssl x509 -req -in "$WORK/inter.csr" -CA "$WORK/rogue.pem" -CAkey "$WORK/rogue.key" -CAcreateserial -sha256 -days 2 -extfile "$WORK/inter.ext" -out "$WORK/rogue_inter.pem" 2>/dev/null
openssl x509 -in "$WORK/rogue_inter.pem" -outform der -out "$WORK/rogue_inter.der" 2>/dev/null
openssl x509 -req -in "$WORK/leaf.csr" -CA "$WORK/rogue_inter.pem" -CAkey "$WORK/inter.key" -CAcreateserial -sha256 -days 2 -extfile "$WORK/leaf.ext" -out "$WORK/rogue_leaf.pem" 2>/dev/null
openssl x509 -in "$WORK/rogue_leaf.pem" -outform der -out "$WORK/rogue_leaf.der" 2>/dev/null

printf '%s' "$ROOT_SHA256" > "$WORK/root_sha256.txt"

# ---- stand-in Supabase REST server capturing upserts + reads + FK simulation ----
cat > "$WORK/mock.ts" <<'EOF'
const KNOWN_USERS = new Set(['aaaaaaaa-0000-4000-8000-000000000001'])
let rows: Record<string, Record<string, unknown>> = {}

Deno.serve({ port: 54321, onListen() {} }, async (req) => {
  const url = new URL(req.url)
  if (url.pathname === '/__rows') return Response.json(rows)
  if (url.pathname === '/__reset') { rows = {}; return new Response('ok') }

  if (url.pathname === '/rest/v1/app_store_entitlements') {
    if (req.headers.get('apikey') !== 'service-role-key') {
      return Response.json({ message: 'unauthorized' }, { status: 401 })
    }
    if (req.method === 'GET') {
      const filter = url.searchParams.get('original_transaction_id') ?? ''
      const txId = filter.replace(/^eq\./, '')
      if (txId === 'tx-select-error') {
        return Response.json({ message: 'simulated db outage' }, { status: 500 })
      }
      const found = rows[txId]
      const accept = req.headers.get('accept') ?? ''
      if (accept.includes('application/vnd.pgrst.object+json')) {
        return found ? Response.json(found) : new Response(null, { status: 406 })
      }
      return Response.json(found ? [found] : [])
    }
    if (req.method === 'POST') {
      const body = await req.json()
      const items = Array.isArray(body) ? body : [body]
      for (const item of items) {
        if (item.user_id && !KNOWN_USERS.has(String(item.user_id))) {
          return Response.json(
            { code: '23503', message: 'insert or update on table "app_store_entitlements" violates foreign key constraint' },
            { status: 409 },
          )
        }
        rows[String(item.original_transaction_id)] = item
      }
      return Response.json(items, { status: 201 })
    }
  }
  return new Response('not found', { status: 404 })
})
EOF

# ---- cryptographic test client ----
cat > "$WORK/client.ts" <<'EOF'
const FUNCTION = 'http://127.0.0.1:8000'
const STAND_IN = 'http://127.0.0.1:54321'
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
const interKey = await crypto.subtle.importKey('pkcs8', await Deno.readFile('/work/inter.pkcs8'), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'])

// Helper: re-sign a modified leaf TBSCertificate with trusted WWDR intermediate to build a real expired cert.
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
  // Locate outer SEQUENCE -> TBSCertificate -> sigAlg -> sigBitString
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
  // Replace the two 13-byte UTCTime entries (tag 0x17, len 0x0d, ...'Z') with expired 2020 dates
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
  const rawSig = new Uint8Array(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, interKey, tbsCopy))
  const r = derInt(rawSig.subarray(0, 32))
  const s = derInt(rawSig.subarray(32, 64))
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
const brokenDnChain = [await readB64('/work/leaf_badinter.der'), await readB64('/work/inter.der'), await readB64('/work/root.der')]
const expiredLeafChain = [await makeExpiredLeafB64(), await readB64('/work/inter.der'), await readB64('/work/root.der')]
const rogueChain = [await readB64('/work/rogue_leaf.der'), await readB64('/work/rogue_inter.der'), await readB64('/work/rogue.der')]
const shortChain = [await readB64('/work/leaf.der'), await readB64('/work/root.der')]
// Crafted 4-byte length with bit 31 set (0x84 0xff 0xff 0xff 0xfa) both at top level AND inside TBSCertificate trailing loop
const negLenCert = b64(new Uint8Array([0x30, 0x84, 0xff, 0xff, 0xff, 0xfa, 0x05, 0x00, 0x05, 0x00]))
const malformedDerChain = [negLenCert, await readB64('/work/inter.der'), await readB64('/work/root.der')]
async function makeNegativeLenTbsLoopCertB64(): Promise<string> {
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
  const tbsInner = leafDer.subarray(tbsHdr.vs, tbsEnd)
  // Append a crafted negative-length TLV (tag 0xa3, 4-byte signed -6) inside TBSCertificate trailing loop
  const poison = new Uint8Array([0xa3, 0x84, 0xff, 0xff, 0xff, 0xfa])
  const newTbsInner = new Uint8Array(tbsInner.length + poison.length)
  newTbsInner.set(tbsInner, 0); newTbsInner.set(poison, tbsInner.length)
  const newTbs = derWrap(0x30, newTbsInner)
  const tail = leafDer.subarray(tbsEnd, outer.vs + outer.len)
  const certBody = new Uint8Array(newTbs.length + tail.length)
  certBody.set(newTbs, 0); certBody.set(tail, newTbs.length)
  return b64(derWrap(0x30, certBody))
}
const negLenTbsLoopChain = [await makeNegativeLenTbsLoopCertB64(), await readB64('/work/inter.der'), await readB64('/work/root.der')]

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

await reset()

const viaGet = await fetch(FUNCTION); await viaGet.text()
check('only POST is accepted', viaGet.status === 405, `got ${viaGet.status}`)

let ans = await post('not-json')
check('non-JSON body is refused', ans.status === 400, `got ${ans.status}`)

ans = await post({ signedPayload: 'not-a-jws' })
check('malformed JWS is refused', ans.status === 400, `got ${ans.status}`)

ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, leafKey, trustedChain, 'HS256') })
check('non-ES256 JWS is refused', ans.status === 400, `got ${ans.status}`)

// Security: forged signature over trusted cert chain MUST fail with 401
const validTestJws = await signJWS({ notificationType: 'TEST', data: {} })
const parts = validTestJws.split('.')
const forgedSig = `${parts[0]}.${parts[1]}.${b64urlBytes(new Uint8Array(64).fill(7))}`
ans = await post({ signedPayload: forgedSig })
check('forged ES256 signature is rejected with 401', ans.status === 401, ans.text)

// Security: tampered payload after signing MUST fail with 401
const tampered = `${parts[0]}.${b64urlJson({ notificationType: 'SUBSCRIBED', data: {} })}.${parts[2]}`
ans = await post({ signedPayload: tampered })
check('tampered JWS payload is rejected with 401', ans.status === 401, ans.text)

// Security: untrusted root CA chain MUST fail with 401
ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, leafKey, rogueChain) })
check('untrusted root CA chain is rejected with 401', ans.status === 401, ans.text)

// Security: 2-cert chain missing intermediate is rejected with 401
ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, leafKey, shortChain) })
check('2-cert chain missing intermediate is rejected with 401', ans.status === 401, ans.text)

// Security: developer cert under trusted WWDR intermediate missing Apple leaf OID MUST fail with 401
ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, devLeafKey, noLeafOidChain) })
check('cert chain missing Apple App Store leaf OID is rejected with 401', ans.status === 401 && ans.json?.error === 'missing_apple_leaf_oid', ans.text)

// Security: non-WWDR intermediate missing WWDR OID MUST fail with 401
ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, leafKey, noInterOidChain) })
check('cert chain missing Apple WWDR intermediate OID is rejected with 401', ans.status === 401 && ans.json?.error === 'missing_apple_intermediate_oid', ans.text)

// Security: non-CA cert (BasicConstraints CA:FALSE) acting as intermediate MUST fail with 401
ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, leafKey, nonCaInterChain) })
check('non-CA cert acting as intermediate is rejected with 401', ans.status === 401 && ans.json?.error === 'issuer_not_ca', ans.text)

// Security: broken RFC 5280 issuer/subject DN chain MUST fail with 401
ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, leafKey, brokenDnChain) })
check('broken DN chain is rejected with 401', ans.status === 401 && ans.json?.error === 'broken_dn_chain', ans.text)

// Security: expired leaf certificate under trusted WWDR intermediate MUST fail with 401
ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, leafKey, expiredLeafChain) })
check('expired leaf certificate is rejected with 401', ans.status === 401 && ans.json?.error === 'expired_certificate', ans.text)

// Security: crafted 4-byte negative-length ASN.1 DER cert MUST reject cleanly with 401 (zero DoS loop)
ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, leafKey, malformedDerChain) })
check('crafted 4-byte negative-length DER cert rejects immediately with 401', ans.status === 401 && ans.json?.error === 'invalid_x5c', ans.text)

// Security: crafted 4-byte negative-length TLV inside TBSCertificate trailing loop MUST reject cleanly with 401 (zero infinite loop)
ans = await post({ signedPayload: await signJWS({ notificationType: 'TEST', data: {} }, leafKey, negLenTbsLoopChain) })
check('crafted negative-length TLV inside TBSCertificate loop rejects immediately with 401', ans.status === 401 && ans.json?.error === 'invalid_x5c', ans.text)

// Honest signed TEST notification
ans = await post({ signedPayload: validTestJws })
check('signed Apple TEST notification succeeds without touching database', ans.status === 200 && ans.json?.test === true && Object.keys(await rows()).length === 0, ans.text)

const txAnnual = await signJWS({
  originalTransactionId: '10000001',
  bundleId: 'com.pausely.app.Pausely',
  productId: 'com.pausely.premium.annual',
  offerType: 1,
  expiresDate: Date.UTC(2026, 11, 1),
  appAccountToken: 'AAAAAAAA-0000-4000-8000-000000000001',
})
const renewOn = await signJWS({ autoRenewStatus: 1 })

ans = await post({
  signedPayload: await signJWS({
    notificationType: 'SUBSCRIBED',
    subtype: 'INITIAL_BUY',
    signedDate: 1_760_000_000_000,
    data: { bundleId: 'com.evil.other', environment: 'Production', signedTransactionInfo: txAnnual },
  }),
})
check('wrong outer bundle id is refused with 403', ans.status === 403, ans.text)

const txWrongBundle = await signJWS({
  originalTransactionId: '10000001',
  bundleId: 'com.evil.other',
  productId: 'com.pausely.premium.annual',
})
ans = await post({
  signedPayload: await signJWS({
    notificationType: 'SUBSCRIBED',
    signedDate: 1_760_000_000_000,
    data: { bundleId: 'com.pausely.app.Pausely', environment: 'Production', signedTransactionInfo: txWrongBundle },
  }),
})
check('wrong inner transaction bundle id is refused with 403', ans.status === 403 && ans.json?.error === 'wrong_transaction_bundle_id', ans.text)

const txMissingBundle = await signJWS({
  originalTransactionId: '10000001',
  productId: 'com.pausely.premium.annual',
})
ans = await post({
  signedPayload: await signJWS({
    notificationType: 'SUBSCRIBED',
    signedDate: 1_760_000_000_000,
    data: { bundleId: 'com.pausely.app.Pausely', environment: 'Production', signedTransactionInfo: txMissingBundle },
  }),
})
check('missing inner transaction bundle id is refused with 403', ans.status === 403 && ans.json?.error === 'wrong_transaction_bundle_id', ans.text)

// Out-of-range signedDate (> 8.64e15) MUST return 400 cleanly instead of throwing RangeError
ans = await post({
  signedPayload: await signJWS({
    notificationType: 'SUBSCRIBED',
    signedDate: 1e20,
    data: { bundleId: 'com.pausely.app.Pausely', environment: 'Production', signedTransactionInfo: txAnnual },
  }),
})
check('out-of-range signedDate is refused with 400', ans.status === 400 && ans.json?.error === 'missing_signed_date', ans.text)

// Missing signedDate MUST fail with 400 (never silently default to Date.now())
ans = await post({
  signedPayload: await signJWS({
    notificationType: 'SUBSCRIBED',
    data: { bundleId: 'com.pausely.app.Pausely', environment: 'Production', signedTransactionInfo: txAnnual },
  }),
})
check('missing signedDate is refused with 400', ans.status === 400 && ans.json?.error === 'missing_signed_date', ans.text)

const txUnknown = await signJWS({ originalTransactionId: '10000002', bundleId: 'com.pausely.app.Pausely', productId: 'com.pausely.fake' })
ans = await post({
  signedPayload: await signJWS({
    notificationType: 'SUBSCRIBED',
    signedDate: 1_760_000_000_000,
    data: { bundleId: 'com.pausely.app.Pausely', environment: 'Production', signedTransactionInfo: txUnknown },
  }),
})
check('unknown product id is refused', ans.status === 400, ans.text)

// Malformed signedRenewalInfo MUST fail, never silently swallow as null
ans = await post({
  signedPayload: await signJWS({
    notificationType: 'SUBSCRIBED',
    signedDate: 1_760_000_000_000,
    data: { bundleId: 'com.pausely.app.Pausely', environment: 'Production', signedTransactionInfo: txAnnual, signedRenewalInfo: 'corrupted.jws.here' },
  }),
})
check('malformed signedRenewalInfo is rejected instead of swallowed', ans.status === 400 || ans.status === 401, ans.text)

// Honest free-trial signup
ans = await post({
  signedPayload: await signJWS({
    notificationType: 'SUBSCRIBED',
    subtype: 'INITIAL_BUY',
    signedDate: 1_760_000_001_000,
    data: { bundleId: 'com.pausely.app.Pausely', environment: 'Production', signedTransactionInfo: txAnnual, signedRenewalInfo: renewOn },
  }),
})
let stored = await rows()
check('signed free-trial signup is recorded as trial with lowercased user_id', ans.status === 200 && stored['10000001']?.status === 'trial' && stored['10000001']?.user_id === 'aaaaaaaa-0000-4000-8000-000000000001' && stored['10000001']?.will_auto_renew === true, JSON.stringify(stored))

// Follow-up DID_RENEW omitting appAccountToken MUST preserve existing user_id
const txRenewNoToken = await signJWS({
  originalTransactionId: '10000001',
  bundleId: 'com.pausely.app.Pausely',
  productId: 'com.pausely.premium.annual',
  expiresDate: Date.UTC(2027, 11, 1),
})
ans = await post({
  signedPayload: await signJWS({
    notificationType: 'DID_RENEW',
    signedDate: 1_760_000_003_000,
    data: { bundleId: 'com.pausely.app.Pausely', environment: 'Production', signedTransactionInfo: txRenewNoToken },
  }),
})
stored = await rows()
check('follow-up event omitting appAccountToken preserves existing user_id', ans.status === 200 && stored['10000001']?.status === 'active' && stored['10000001']?.user_id === 'aaaaaaaa-0000-4000-8000-000000000001', JSON.stringify(stored))

// Newer billing failure updates status
ans = await post({
  signedPayload: await signJWS({
    notificationType: 'DID_FAIL_TO_RENEW',
    subtype: 'GRACE_PERIOD',
    signedDate: 1_760_000_005_000,
    data: { bundleId: 'com.pausely.app.Pausely', environment: 'Production', signedTransactionInfo: txAnnual },
  }),
})
stored = await rows()
check('billing failure in grace period updates status to grace_period', ans.status === 200 && stored['10000001']?.status === 'grace_period', JSON.stringify(stored))

// Stale out-of-order notification MUST NOT overwrite newer status
ans = await post({
  signedPayload: await signJWS({
    notificationType: 'SUBSCRIBED',
    signedDate: 1_760_000_002_000,
    data: { bundleId: 'com.pausely.app.Pausely', environment: 'Production', signedTransactionInfo: txAnnual },
  }),
})
stored = await rows()
check('stale out-of-order notification is ignored without overwriting newer state', ans.status === 200 && ans.json?.ignored === 'stale' && stored['10000001']?.status === 'grace_period', ans.text)

// Newer refund updates status
ans = await post({
  signedPayload: await signJWS({
    notificationType: 'REFUND',
    signedDate: 1_760_000_009_000,
    data: { bundleId: 'com.pausely.app.Pausely', environment: 'Production', signedTransactionInfo: txAnnual },
  }),
})
stored = await rows()
check('refund updates status to refunded', ans.status === 200 && stored['10000001']?.status === 'refunded', JSON.stringify(stored))

// Deleted-user appAccountToken falls back cleanly to user_id = null (no 500 retry storm)
const txDeletedUser = await signJWS({
  originalTransactionId: '10000099',
  bundleId: 'com.pausely.app.Pausely',
  productId: 'com.pausely.premium.monthly',
  appAccountToken: '99999999-0000-4000-8000-000000000099',
})
ans = await post({
  signedPayload: await signJWS({
    notificationType: 'REFUND',
    signedDate: 1_760_000_010_000,
    data: { bundleId: 'com.pausely.app.Pausely', environment: 'Production', signedTransactionInfo: txDeletedUser },
  }),
})
stored = await rows()
check('deleted-user appAccountToken stores user_id=null cleanly instead of 500', ans.status === 200 && stored['10000099']?.user_id === null && stored['10000099']?.status === 'refunded', ans.text)

// Transient DB SELECT failure MUST fail closed with 500 so Apple retries instead of bypassing stale/user_id preservation
const txSelectErr = await signJWS({
  originalTransactionId: 'tx-select-error',
  bundleId: 'com.pausely.app.Pausely',
  productId: 'com.pausely.premium.annual',
})
ans = await post({
  signedPayload: await signJWS({
    notificationType: 'DID_RENEW',
    signedDate: 1_760_000_011_000,
    data: { bundleId: 'com.pausely.app.Pausely', environment: 'Production', signedTransactionInfo: txSelectErr },
  }),
})
check('transient DB SELECT failure fails closed with 500', ans.status === 500 && ans.json?.error === 'db_error', ans.text)

Deno.exit(failed === 0 ? 0 : 1)
EOF

cat > "$WORK/inside.sh" <<'EOF'
cd /work
ROOT_HASH=$(cat /work/root_sha256.txt)
deno run --quiet --allow-net mock.ts &
env SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_SERVICE_ROLE_KEY=service-role-key APP_STORE_BUNDLE_ID=com.pausely.app.Pausely APP_STORE_TEST_ROOT_SHA256="$ROOT_HASH" \
  deno run --quiet --allow-net --allow-env index.ts >> /work/function.log 2>&1 &
FUNCTION_PID=$!
for _ in $(seq 1 240); do
  if deno eval --quiet "try { await (await fetch('http://127.0.0.1:8000')).text() } catch { Deno.exit(1) }" 2>/dev/null; then
    break
  fi
  sleep 0.5
done
deno run --quiet --allow-net --allow-read client.ts
status=$?
kill "$FUNCTION_PID" 2>/dev/null; wait "$FUNCTION_PID" 2>/dev/null
exit "$status"
EOF

tar -C "$WORK" -cf - . | docker run --rm -i "$IMAGE" sh -c 'mkdir -p /work && tar -xf - -C /work && sh /work/inside.sh'
code=$?
if [ "$code" -eq 0 ]; then echo "appstore-notifications: every check passed"; else echo "appstore-notifications: FAILED"; fi
exit "$code"
