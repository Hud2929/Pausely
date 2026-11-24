// Account emails: the code for a new sign-up, a sign-in and a password reset.
//
// Supabase Auth calls this function instead of sending the email itself (its "send email" hook), and
// the function sends Pausely's own page through Resend. Without it the project's built-in mailer is
// used, which delivers only to members of the project, two emails an hour, so nobody else could sign up.
//
// Every request is signed by Supabase Auth with SEND_EMAIL_HOOK_SECRET (Standard Webhooks: an HMAC
// over id, timestamp and body). A request with a wrong or old signature sends nothing.
// The email carries the code and no link, so there is nothing for a mail scanner to "click".
// The page below is the one in SUPABASE_EMAIL_TEMPLATES.md; change both together.
// Tested by scripts/dbtest/auth_email_function.sh.

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? ''
const RESEND_API_URL = Deno.env.get('RESEND_API_URL') ?? 'https://api.resend.com'
const HOOK_SECRET = (Deno.env.get('SEND_EMAIL_HOOK_SECRET') ?? '').replace(/^v1,whsec_/, '')
const FROM = Deno.env.get('AUTH_EMAIL_FROM') ?? 'Pausely <hello@pausely.pro>'
const SIGNATURE_AGE_LIMIT_SECONDS = 5 * 60

/// The one sentence that differs between the emails, by what Supabase Auth says the email is for.
const SENTENCES: Record<string, string> = {
  signup: 'Enter it in Pausely to finish creating your account.',
  magiclink: 'Enter it in Pausely to sign in.',
  recovery: 'Enter it in Pausely to choose a new password.',
  email_change: 'Enter it in Pausely to confirm your new email address.',
  reauthentication: 'Enter it in Pausely to confirm it is you.',
}
const ANY_OTHER_SENTENCE = 'Enter it in Pausely to continue.'

const PAGE = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="supported-color-schemes" content="dark">
  <title>Your Pausely code</title>
</head>
<body style="margin:0; padding:0; background-color:#0A0B0D;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#0A0B0D;">
    <tr>
      <td align="center" style="padding:40px 20px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:440px;">
          <tr>
            <td style="font-family:Georgia,'Times New Roman',serif; font-size:22px; font-weight:bold; color:#F5F4F0; padding-bottom:28px;">
              Pausely
            </td>
          </tr>
          <tr>
            <td style="background-color:#ECE7DC; border-radius:6px; padding:28px 24px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:13px; color:#5A574E; padding-bottom:10px;">
                    Your code
                  </td>
                </tr>
                <tr>
                  <td style="font-family:ui-monospace,Menlo,Consolas,'Courier New',monospace; font-size:38px; font-weight:bold; letter-spacing:6px; color:#1A1A17; padding-bottom:16px;">
                    {{ .Token }}
                  </td>
                </tr>
                <tr>
                  <td style="border-top:1px dashed #B9B3A4; padding-top:16px; font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:15px; line-height:22px; color:#1A1A17;">
                    SENTENCE It can be used once.
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:13px; line-height:20px; color:#A6A8AD; padding-top:24px;">
              If you didn't ask for this, you can ignore this email.
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`

function refuse(status: number, message: string): Response {
  // The shape Supabase Auth expects from a hook that failed.
  return new Response(JSON.stringify({ error: { http_code: status, message } }), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

function sameText(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let difference = 0
  for (let i = 0; i < a.length; i++) difference |= a.charCodeAt(i) ^ b.charCodeAt(i)
  return difference === 0
}

async function signedBySupabaseAuth(body: string, headers: Headers): Promise<boolean> {
  const id = headers.get('webhook-id')
  const timestamp = headers.get('webhook-timestamp')
  const signatures = headers.get('webhook-signature')
  if (!id || !timestamp || !signatures || !HOOK_SECRET) return false

  const sentAt = Number(timestamp)
  if (!Number.isFinite(sentAt) || Math.abs(Date.now() / 1000 - sentAt) > SIGNATURE_AGE_LIMIT_SECONDS) return false

  let key: CryptoKey
  try {
    key = await crypto.subtle.importKey('raw', Uint8Array.from(atob(HOOK_SECRET), (character) => character.charCodeAt(0)),
      { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  } catch {
    return false
  }
  const mac = new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${id}.${timestamp}.${body}`)))
  const expected = btoa(String.fromCharCode(...mac))

  // The header may carry several signatures ("v1,<base64> v1,<base64>") while a secret is being changed.
  return signatures.split(' ').some((entry) => {
    const [version, value] = entry.split(',')
    return version === 'v1' && value !== undefined && sameText(value, expected)
  })
}

const MAX_BODY_BYTES = 32 * 1024

async function readBoundedText(req: Request, maxBytes: number): Promise<string | null> {
  const lenHeader = req.headers.get('content-length')
  if (lenHeader !== null) {
    const declared = Number(lenHeader)
    if (Number.isFinite(declared) && declared > maxBytes) return null
  }
  if (!req.body) return ''
  const reader = req.body.getReader()
  const chunks: Uint8Array[] = []
  let total = 0
  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    total += value.byteLength
    if (total > maxBytes) {
      await reader.cancel().catch(() => {})
      return null
    }
    chunks.push(value)
  }
  const combined = new Uint8Array(total)
  let offset = 0
  for (const c of chunks) { combined.set(c, offset); offset += c.byteLength }
  return new TextDecoder().decode(combined)
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return refuse(405, 'Method not allowed')

  const body = await readBoundedText(req, MAX_BODY_BYTES)
  if (body === null) return refuse(413, 'Payload too large')
  if (!(await signedBySupabaseAuth(body, req.headers))) return refuse(401, 'Invalid signature')

  let payload: { user?: { email?: unknown }; email_data?: { token?: unknown; email_action_type?: unknown } }
  try {
    payload = JSON.parse(body)
  } catch {
    return refuse(400, 'Invalid payload')
  }
  const address = payload?.user?.email
  const code = payload?.email_data?.token
  const purpose = payload?.email_data?.email_action_type
  if (typeof address !== 'string' || !address.includes('@') || typeof code !== 'string' || !/^[0-9]{6,10}$/.test(code)) {
    return refuse(400, 'Invalid payload')
  }
  if (!RESEND_API_KEY) {
    return refuse(503, 'Mail provider not configured')
  }
  const sentence = (typeof purpose === 'string' && Object.hasOwn(SENTENCES, purpose))
    ? SENTENCES[purpose]
    : ANY_OTHER_SENTENCE

  let response: Response
  try {
    response = await fetch(`${RESEND_API_URL}/emails`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      signal: AbortSignal.timeout(10_000),
      body: JSON.stringify({
        from: FROM,
        to: [address],
        subject: `Your Pausely code: ${code}`,
        html: PAGE.replace('{{ .Token }}', code).replace('SENTENCE', sentence),
        text: `Your Pausely code: ${code}\n\n${sentence} It can be used once.\n\nIf you didn't ask for this, you can ignore this email.`,
      }),
    })
  } catch {
    console.error('The mail provider could not be reached')
    return refuse(502, 'The email could not be sent')
  }
  if (!response.ok) {
    // The address is never logged.
    console.error('The mail provider refused the email: HTTP', response.status)
    return refuse(502, 'The email could not be sent')
  }
  return new Response('{}', { status: 200, headers: { 'Content-Type': 'application/json' } })
})
