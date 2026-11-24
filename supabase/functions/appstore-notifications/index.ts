// App Store Server Notifications v2 webhook (Supabase Edge Function).
// Apple POSTs { signedPayload: "<JWS>" } whenever a Pausely Pro subscription starts, renews,
// enters billing retry / grace period, expires, is refunded, or is revoked.
//
// Security:
// - Cryptographically verifies every ES256 JWS (outer envelope, signedTransactionInfo, and
//   optional signedRenewalInfo) using WebCrypto against the leaf certificate in header.x5c.
// - Verifies every X.509 link in header.x5c (signature + validity dates) and pins the chain root
//   to Apple Root CA - G3 SHA-256 (or APP_STORE_TEST_ROOT_SHA256 strictly for local test rigs).
// - Enforces bundle ID, allowlisted product IDs, and monotonic signedDate (rejecting stale replays).
// - Writes exclusively to public.app_store_entitlements via service_role.
// Tested by scripts/dbtest/appstore_notifications_function.sh.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.117.3'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const EXPECTED_BUNDLE_ID = Deno.env.get('APP_STORE_BUNDLE_ID') ?? 'com.pausely.app.Pausely'

// Official Apple Root CA - G3 SHA-256 fingerprint (https://www.apple.com/certificateauthority/).
const APPLE_ROOT_CA_G3_SHA256 = '63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179'
const TEST_ROOT_SHA256 = (Deno.env.get('APP_STORE_TEST_ROOT_SHA256') ?? '').trim().toLowerCase()
const TRUSTED_ROOTS = new Set(
  TEST_ROOT_SHA256 ? [APPLE_ROOT_CA_G3_SHA256, TEST_ROOT_SHA256] : [APPLE_ROOT_CA_G3_SHA256],
)

const ALLOWED_PRODUCT_IDS = new Set([
  'com.pausely.premium.monthly',
  'com.pausely.premium.annual',
])

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

// MARK: - Base64 / Hex Helpers

function decodeBase64(b64: string): Uint8Array | null {
  try {
    const clean = b64.replace(/\s+/g, '')
    const binary = atob(clean)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
    return bytes
  } catch {
    return null
  }
}

function decodeBase64Url(segment: string): Uint8Array | null {
  const padded = segment.replace(/-/g, '+').replace(/_/g, '/')
    .padEnd(Math.ceil(segment.length / 4) * 4, '=')
  return decodeBase64(padded)
}

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))
  return Array.from(digest).map((b) => b.toString(16).padStart(2, '0')).join('')
}

function bytesContain(haystack: Uint8Array, needle: number[]): boolean {
  outer: for (let i = 0; i <= haystack.length - needle.length; i++) {
    for (let j = 0; j < needle.length; j++) {
      if (haystack[i + j] !== needle[j]) continue outer
    }
    return true
  }
  return false
}

// MARK: - Minimal ASN.1 / DER X.509 Certificate Parser & Chain Verifier

interface TLV {
  tag: number
  start: number
  valueStart: number
  length: number
  end: number
}

function readTLV(bytes: Uint8Array, offset: number, limit: number = bytes.length): TLV | null {
  if (offset < 0 || limit > bytes.length || offset + 2 > limit) return null
  const tag = bytes[offset]
  const lenByte = bytes[offset + 1]
  let length = 0
  let valueStart = offset + 2
  if ((lenByte & 0x80) === 0) {
    length = lenByte
  } else {
    const numOctets = lenByte & 0x7f
    // Cap at 3 length octets (16 MiB) and use unsigned arithmetic so crafted 4-byte lengths
    // can never wrap negative via signed 32-bit bitwise shifts and stall ASN.1 loops.
    if (numOctets === 0 || numOctets > 3 || offset + 2 + numOctets > limit) return null
    for (let i = 0; i < numOctets; i++) {
      length = length * 256 + bytes[offset + 2 + i]
    }
    valueStart = offset + 2 + numOctets
  }
  const end = valueStart + length
  if (length < 0 || end < valueStart || end > limit) return null
  return { tag, start: offset, valueStart, length, end }
}

function parseAsn1Time(bytes: Uint8Array, tlv: TLV): Date | null {
  const text = new TextDecoder().decode(bytes.subarray(tlv.valueStart, tlv.end))
  if (tlv.tag === 0x17 && text.length === 13 && text.endsWith('Z')) {
    const yy = Number(text.slice(0, 2))
    const year = yy >= 50 ? 1900 + yy : 2000 + yy
    const iso = `${year}-${text.slice(2, 4)}-${text.slice(4, 6)}T${text.slice(6, 8)}:${text.slice(8, 10)}:${text.slice(10, 12)}Z`
    const d = new Date(iso)
    return Number.isNaN(d.getTime()) ? null : d
  }
  if (tlv.tag === 0x18 && text.length === 15 && text.endsWith('Z')) {
    const iso = `${text.slice(0, 4)}-${text.slice(4, 6)}-${text.slice(6, 8)}T${text.slice(8, 10)}:${text.slice(10, 12)}:${text.slice(12, 14)}Z`
    const d = new Date(iso)
    return Number.isNaN(d.getTime()) ? null : d
  }
  return null
}

// OIDs in DER form
const OID_P256 = [0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07]
const OID_P384 = [0x06, 0x05, 0x2b, 0x81, 0x04, 0x00, 0x22]
const OID_ECDSA_SHA256 = [0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x04, 0x03, 0x02]
const OID_ECDSA_SHA384 = [0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x04, 0x03, 0x03]
const OID_BASIC_CONSTRAINTS = [0x06, 0x03, 0x55, 0x1d, 0x13]
// Apple App Store Server Notifications v2 certificate extension OIDs (Apple App Store Server Library spec):
// Leaf: 1.2.840.113635.100.6.11.1 | WWDR Intermediate: 1.2.840.113635.100.6.2.1
const OID_APPLE_APPSTORE_LEAF = [0x06, 0x0a, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x06, 0x0b, 0x01]
const OID_APPLE_WWDR_INTERMEDIATE = [0x06, 0x0a, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x06, 0x02, 0x01]

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false
  return true
}

function derMatches(bytes: Uint8Array, tlv: TLV, expected: number[]): boolean {
  if (tlv.end - tlv.start !== expected.length) return false
  for (let i = 0; i < expected.length; i++) {
    if (bytes[tlv.start + i] !== expected[i]) return false
  }
  return true
}

interface ParsedCert {
  der: Uint8Array
  tbsBytes: Uint8Array
  issuerBytes: Uint8Array
  subjectBytes: Uint8Array
  sigAlgHash: 'SHA-256' | 'SHA-384'
  sigDer: Uint8Array
  spkiBytes: Uint8Array
  namedCurve: 'P-256' | 'P-384'
  notBefore: Date
  notAfter: Date
  isCA: boolean
  hasAppleLeafOID: boolean
  hasAppleIntermediateOID: boolean
}

function parseX509Cert(der: Uint8Array): ParsedCert | null {
  const certSeq = readTLV(der, 0, der.length)
  if (!certSeq || certSeq.tag !== 0x30) return null

  const tbs = readTLV(der, certSeq.valueStart, certSeq.end)
  if (!tbs || tbs.tag !== 0x30) return null
  const sigAlg = readTLV(der, tbs.end, certSeq.end)
  if (!sigAlg || sigAlg.tag !== 0x30) return null
  const sigBitString = readTLV(der, sigAlg.end, certSeq.end)
  if (!sigBitString || sigBitString.tag !== 0x03 || sigBitString.length < 2) return null
  if (der[sigBitString.valueStart] !== 0x00) return null

  const sigAlgBytes = der.subarray(sigAlg.start, sigAlg.end)
  let sigAlgHash: 'SHA-256' | 'SHA-384' | null = null
  if (bytesContain(sigAlgBytes, OID_ECDSA_SHA256)) sigAlgHash = 'SHA-256'
  else if (bytesContain(sigAlgBytes, OID_ECDSA_SHA384)) sigAlgHash = 'SHA-384'
  if (!sigAlgHash) return null

  // Walk TBSCertificate children strictly inside tbs.end: [version?], serial, sig, issuer, validity, subject, spki, [extensions?]
  let pos = tbs.valueStart
  const first = readTLV(der, pos, tbs.end)
  if (!first) return null
  if (first.tag === 0xa0) pos = first.end // optional v3 version wrapper

  const serial = readTLV(der, pos, tbs.end); if (!serial) return null; pos = serial.end
  const innerSig = readTLV(der, pos, tbs.end); if (!innerSig) return null; pos = innerSig.end
  const issuer = readTLV(der, pos, tbs.end); if (!issuer || issuer.tag !== 0x30) return null; pos = issuer.end
  const validity = readTLV(der, pos, tbs.end); if (!validity || validity.tag !== 0x30) return null; pos = validity.end
  const subject = readTLV(der, pos, tbs.end); if (!subject || subject.tag !== 0x30) return null; pos = subject.end
  const spki = readTLV(der, pos, tbs.end); if (!spki || spki.tag !== 0x30) return null; pos = spki.end

  const notBeforeTlv = readTLV(der, validity.valueStart, validity.end)
  if (!notBeforeTlv) return null
  const notAfterTlv = readTLV(der, notBeforeTlv.end, validity.end)
  if (!notAfterTlv) return null
  const notBefore = parseAsn1Time(der, notBeforeTlv)
  const notAfter = parseAsn1Time(der, notAfterTlv)
  if (!notBefore || !notAfter) return null

  const spkiBytes = der.subarray(spki.start, spki.end)
  let namedCurve: 'P-256' | 'P-384' | null = null
  if (bytesContain(spkiBytes, OID_P256)) namedCurve = 'P-256'
  else if (bytesContain(spkiBytes, OID_P384)) namedCurve = 'P-384'
  if (!namedCurve) return null

  let isCA = false
  let hasAppleLeafOID = false
  let hasAppleIntermediateOID = false

  // Parse optional trailing fields in TBSCertificate until [3] extensions (0xa3), bounded at every level
  while (pos < tbs.end) {
    const field = readTLV(der, pos, tbs.end)
    if (!field || field.end <= pos) return null
    pos = field.end
    if (field.tag === 0xa3) {
      const extSeq = readTLV(der, field.valueStart, field.end)
      if (!extSeq || extSeq.tag !== 0x30) return null
      let ePos = extSeq.valueStart
      while (ePos < extSeq.end) {
        const ext = readTLV(der, ePos, extSeq.end)
        if (!ext || ext.tag !== 0x30 || ext.end <= ePos) return null
        ePos = ext.end
        const oid = readTLV(der, ext.valueStart, ext.end)
        if (!oid || oid.tag !== 0x06) continue
        if (derMatches(der, oid, OID_APPLE_APPSTORE_LEAF)) hasAppleLeafOID = true
        if (derMatches(der, oid, OID_APPLE_WWDR_INTERMEDIATE)) hasAppleIntermediateOID = true
        if (derMatches(der, oid, OID_BASIC_CONSTRAINTS)) {
          let next = readTLV(der, oid.end, ext.end)
          if (next && next.tag === 0x01) next = readTLV(der, next.end, ext.end) // skip optional critical BOOLEAN
          if (next && next.tag === 0x04) {
            const bcSeq = readTLV(der, next.valueStart, next.end)
            if (bcSeq && bcSeq.tag === 0x30 && bcSeq.length > 0) {
              const caBool = readTLV(der, bcSeq.valueStart, bcSeq.end)
              if (caBool && caBool.tag === 0x01 && caBool.length === 1 && der[caBool.valueStart] !== 0x00) {
                isCA = true
              }
            }
          }
        }
      }
    }
  }

  return {
    der,
    tbsBytes: der.subarray(tbs.start, tbs.end),
    issuerBytes: der.subarray(issuer.start, issuer.end),
    subjectBytes: der.subarray(subject.start, subject.end),
    sigAlgHash,
    sigDer: der.subarray(sigBitString.valueStart + 1, sigBitString.end),
    spkiBytes,
    namedCurve,
    notBefore,
    notAfter,
    isCA,
    hasAppleLeafOID,
    hasAppleIntermediateOID,
  }
}

function derEcdsaSigToRaw(sigDer: Uint8Array, coordLen: number): Uint8Array | null {
  const seq = readTLV(sigDer, 0)
  if (!seq || seq.tag !== 0x30) return null
  const rTlv = readTLV(sigDer, seq.valueStart)
  if (!rTlv || rTlv.tag !== 0x02) return null
  const sTlv = readTLV(sigDer, rTlv.end)
  if (!sTlv || sTlv.tag !== 0x02) return null

  const copyInt = (tlv: TLV, out: Uint8Array, offset: number): boolean => {
    let raw = sigDer.subarray(tlv.valueStart, tlv.end)
    while (raw.length > 0 && raw[0] === 0x00) raw = raw.subarray(1)
    if (raw.length > coordLen) return false
    out.set(raw, offset + (coordLen - raw.length))
    return true
  }

  const out = new Uint8Array(coordLen * 2)
  if (!copyInt(rTlv, out, 0) || !copyInt(sTlv, out, coordLen)) return null
  return out
}

async function importCertKey(cert: ParsedCert): Promise<CryptoKey | null> {
  try {
    return await crypto.subtle.importKey(
      'spki',
      cert.spkiBytes,
      { name: 'ECDSA', namedCurve: cert.namedCurve },
      false,
      ['verify'],
    )
  } catch {
    return null
  }
}

interface VerifiedJWS {
  header: Record<string, unknown>
  payload: Record<string, unknown>
}

async function verifyAppleJWS(token: unknown): Promise<{ ok: true; jws: VerifiedJWS } | { ok: false; status: 400 | 401; error: string }> {
  if (typeof token !== 'string' || token.length < 16 || token.length > 65_536) {
    return { ok: false, status: 400, error: 'invalid_jws' }
  }
  const parts = token.split('.')
  if (parts.length !== 3) return { ok: false, status: 400, error: 'invalid_jws' }

  const headerBytes = decodeBase64Url(parts[0])
  const payloadBytes = decodeBase64Url(parts[1])
  const sigBytes = decodeBase64Url(parts[2])
  if (!headerBytes || !payloadBytes || !sigBytes || sigBytes.length === 0) {
    return { ok: false, status: 400, error: 'invalid_jws' }
  }

  let header: Record<string, unknown>
  let payload: Record<string, unknown>
  try {
    const h = JSON.parse(new TextDecoder().decode(headerBytes))
    const p = JSON.parse(new TextDecoder().decode(payloadBytes))
    if (!h || typeof h !== 'object' || !p || typeof p !== 'object') {
      return { ok: false, status: 400, error: 'invalid_jws' }
    }
    header = h as Record<string, unknown>
    payload = p as Record<string, unknown>
  } catch {
    return { ok: false, status: 400, error: 'invalid_jws' }
  }

  if (header.alg !== 'ES256') return { ok: false, status: 400, error: 'unsupported_alg' }
  if (!Array.isArray(header.x5c) || header.x5c.length < 3 || header.x5c.length > 6) {
    return { ok: false, status: 401, error: 'invalid_x5c_length' }
  }

  const now = new Date()
  const certs: ParsedCert[] = []
  for (const entry of header.x5c) {
    if (typeof entry !== 'string') return { ok: false, status: 401, error: 'invalid_x5c' }
    const der = decodeBase64(entry)
    if (!der) return { ok: false, status: 401, error: 'invalid_x5c' }
    const parsed = parseX509Cert(der)
    if (!parsed) return { ok: false, status: 401, error: 'invalid_x5c' }
    if (now < parsed.notBefore || now > parsed.notAfter) {
      return { ok: false, status: 401, error: 'expired_certificate' }
    }
    certs.push(parsed)
  }

  // 1. Verify Apple ASSN v2 leaf & WWDR intermediate OIDs so non-App-Store certs under Apple Root CA - G3 cannot forge webhooks.
  const leaf = certs[0]
  const intermediate = certs[1]
  if (!leaf.hasAppleLeafOID) return { ok: false, status: 401, error: 'missing_apple_leaf_oid' }
  if (!intermediate.hasAppleIntermediateOID) return { ok: false, status: 401, error: 'missing_apple_intermediate_oid' }

  // 2. Verify the root certificate matches a pinned trusted Apple Root CA (or explicit test root).
  const root = certs[certs.length - 1]
  const rootHash = await sha256Hex(root.der)
  if (!TRUSTED_ROOTS.has(rootHash)) {
    return { ok: false, status: 401, error: 'untrusted_root_ca' }
  }

  // 3. Verify every certificate link: issuer has BasicConstraints CA=TRUE, DN chains cleanly, and signature verifies.
  for (let i = 0; i < certs.length - 1; i++) {
    const child = certs[i]
    const issuer = certs[i + 1]
    if (!issuer.isCA) return { ok: false, status: 401, error: 'issuer_not_ca' }
    if (!bytesEqual(child.issuerBytes, issuer.subjectBytes)) {
      return { ok: false, status: 401, error: 'broken_dn_chain' }
    }
    const issuerKey = await importCertKey(issuer)
    if (!issuerKey) return { ok: false, status: 401, error: 'invalid_issuer_key' }
    const coordLen = issuer.namedCurve === 'P-384' ? 48 : 32
    const rawSig = derEcdsaSigToRaw(child.sigDer, coordLen)
    if (!rawSig) return { ok: false, status: 401, error: 'invalid_cert_signature' }
    const validLink = await crypto.subtle.verify(
      { name: 'ECDSA', hash: child.sigAlgHash },
      issuerKey,
      rawSig,
      child.tbsBytes,
    )
    if (!validLink) return { ok: false, status: 401, error: 'broken_cert_chain' }
  }

  // 4. Verify the JWS ES256 signature against the leaf certificate's P-256 public key.
  if (leaf.namedCurve !== 'P-256' || sigBytes.length !== 64) {
    return { ok: false, status: 401, error: 'invalid_jws_signature' }
  }
  const leafKey = await importCertKey(leaf)
  if (!leafKey) return { ok: false, status: 401, error: 'invalid_leaf_key' }
  const signingInput = new TextEncoder().encode(`${parts[0]}.${parts[1]}`)
  const validSig = await crypto.subtle.verify(
    { name: 'ECDSA', hash: 'SHA-256' },
    leafKey,
    sigBytes,
    signingInput,
  )
  if (!validSig) return { ok: false, status: 401, error: 'invalid_jws_signature' }

  return { ok: true, jws: { header, payload } }
}

// MARK: - Notification Derivation

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

  const envelopeRes = await verifyAppleJWS(body.signedPayload)
  if (!envelopeRes.ok) return json(envelopeRes.status, { error: envelopeRes.error })
  const envelope = envelopeRes.jws

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

  const txRes = await verifyAppleJWS(data.signedTransactionInfo)
  if (!txRes.ok) return json(txRes.status, { error: txRes.error })
  const tx = txRes.jws.payload

  if (tx.bundleId !== EXPECTED_BUNDLE_ID) {
    return json(403, { error: 'wrong_transaction_bundle_id' })
  }

  const originalTransactionId = tx.originalTransactionId
  const productId = tx.productId
  if (typeof originalTransactionId !== 'string' || originalTransactionId.length === 0) {
    return json(400, { error: 'missing_transaction_id' })
  }
  if (typeof productId !== 'string' || !ALLOWED_PRODUCT_IDS.has(productId)) {
    return json(400, { error: 'unknown_product_id' })
  }

  // If Apple included signedRenewalInfo, it MUST verify cleanly — never silently swallow tampering.
  let willAutoRenew: boolean | null = null
  if (data.signedRenewalInfo !== undefined && data.signedRenewalInfo !== null) {
    const renewalRes = await verifyAppleJWS(data.signedRenewalInfo)
    if (!renewalRes.ok) return json(renewalRes.status, { error: 'invalid_renewal_jws' })
    const autoRenewStatus = renewalRes.jws.payload.autoRenewStatus
    willAutoRenew = typeof autoRenewStatus === 'number' ? autoRenewStatus === 1 : null
  }

  const rawEnv = typeof data.environment === 'string' ? data.environment : 'Production'
  const environment = rawEnv === 'Sandbox' ? 'Sandbox' : 'Production'

  const MAX_DATE_MS = 8.64e15
  const expiresMs = typeof tx.expiresDate === 'number' ? tx.expiresDate : null
  const expiresAt = (expiresMs !== null && Number.isFinite(expiresMs) && expiresMs > 0 && expiresMs <= MAX_DATE_MS)
    ? new Date(expiresMs).toISOString()
    : null

  const rawSignedMs = typeof envelope.payload.signedDate === 'number'
    ? envelope.payload.signedDate
    : (typeof tx.signedDate === 'number' ? tx.signedDate : null)
  if (rawSignedMs === null || !Number.isFinite(rawSignedMs) || rawSignedMs <= 0 || rawSignedMs > MAX_DATE_MS) {
    return json(400, { error: 'missing_signed_date' })
  }
  const signedMs = rawSignedMs
  const signedIso = new Date(signedMs).toISOString()

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

  // Out-of-order replay protection + preserve existing user_id when follow-up events omit appAccountToken.
  // Never ignore a read error: failing closed with 500 asks Apple to retry instead of bypassing replay protection.
  const { data: existing, error: selectError } = await supabase
    .from('app_store_entitlements')
    .select('last_signed_date, user_id')
    .eq('original_transaction_id', originalTransactionId)
    .maybeSingle()

  if (selectError) {
    console.error('appstore-notifications select error:', selectError.message)
    return json(500, { error: 'db_error' })
  }

  if (existing?.last_signed_date) {
    const prevMs = Date.parse(String(existing.last_signed_date))
    if (!Number.isNaN(prevMs) && signedMs < prevMs) {
      return json(200, { ok: true, ignored: 'stale', originalTransactionId })
    }
  }

  const resolvedUserId = appAccountToken ?? (typeof existing?.user_id === 'string' ? existing.user_id : null)

  const buildRow = (userId: string | null) => ({
    original_transaction_id: originalTransactionId,
    user_id: userId,
    product_id: productId,
    status,
    environment,
    will_auto_renew: willAutoRenew,
    expires_at: expiresAt,
    last_notification_type: subtype ? `${notificationType}:${subtype}` : notificationType,
    last_signed_date: signedIso,
    last_event_at: new Date().toISOString(),
  })

  let { error } = await supabase
    .from('app_store_entitlements')
    .upsert(buildRow(resolvedUserId), { onConflict: 'original_transaction_id' })

  // If the account has already been deleted (FK violation 23503 on user_id), record the
  // entitlement cleanly with user_id = null instead of returning 500 and triggering Apple retries.
  if (error && resolvedUserId && (error.code === '23503' || error.message.toLowerCase().includes('foreign key'))) {
    const retry = await supabase
      .from('app_store_entitlements')
      .upsert(buildRow(null), { onConflict: 'original_transaction_id' })
    error = retry.error
  }

  if (error) {
    console.error('appstore-notifications upsert error:', error.message)
    return json(500, { error: 'db_error' })
  }

  return json(200, { ok: true, status, originalTransactionId })
})
