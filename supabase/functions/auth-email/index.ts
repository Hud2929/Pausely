// Account emails: the code for a new sign-up, a sign-in, a password reset, and email changes.
//
// Supabase Auth calls this function instead of sending the email itself (its "send email" hook), and
// the function sends Pausely's own page through Resend. Without it the project's built-in mailer is
// used, which delivers only to members of the project, two emails an hour, so nobody else could sign up.
//
// Security & Reliability:
// - Every request is verified with Standard Webhooks HMAC-SHA256 (`SEND_EMAIL_HOOK_SECRET`, accepting
//   both `v1,whsec_<b64>` and `whsec_<b64>`, supporting multi-signature rotation and 5-minute replay bounds).
// - Supports `email_change` double confirmation (`double_confirm_changes = true`), sending `token` to
//   `user.email` and `token_new` to `user.new_email`.
// - Localizes OTP emails in all 6 languages Pausely ships (`en`, `ar`, `de`, `es`, `fr`, `ja`) based on
//   `user.user_metadata.locale`, with RTL layout for Arabic (`ar`).
// - Carries the code and no link, so there is nothing for a mail scanner to "click".
// - Never logs any email address.
// Tested by scripts/dbtest/auth_email_function.sh.

import { drainResponse, readBoundedText } from '../_shared/http.ts'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? ''
const RESEND_API_URL = Deno.env.get('RESEND_API_URL') ?? 'https://api.resend.com'
const HOOK_SECRET = (Deno.env.get('SEND_EMAIL_HOOK_SECRET') ?? '').replace(/^(?:v1,)?whsec_/, '')
const FROM = Deno.env.get('AUTH_EMAIL_FROM') ?? 'Pausely <hello@pausely.pro>'
const SIGNATURE_AGE_LIMIT_SECONDS = 5 * 60
const MAX_BODY_BYTES = 32 * 1024
const OTP_PATTERN = /^[0-9]{6,10}$/
const EMAIL_PATTERN = /^[^\s@<>,;"\\]+@[^\s@<>,;"\\]+\.[^\s@<>,;"\\]{2,}$/

type Lang = 'en' | 'ar' | 'de' | 'es' | 'fr' | 'ja'

interface CopyPack {
  dir: 'ltr' | 'rtl'
  subjectPrefix: string
  title: string
  yourCode: string
  sentences: Record<string, string>
  fallbackSentence: string
  useOnce: string
  ignoreNote: string
}

const COPY: Record<Lang, CopyPack> = {
  en: {
    dir: 'ltr',
    subjectPrefix: 'Your Pausely code',
    title: 'Your Pausely code',
    yourCode: 'Your code',
    sentences: {
      signup: 'Enter it in Pausely to finish creating your account.',
      magiclink: 'Enter it in Pausely to sign in.',
      recovery: 'Enter it in Pausely to choose a new password.',
      email_change: 'Enter it in Pausely to confirm your new email address.',
      email_change_current: 'Enter it in Pausely to confirm changing your email address.',
      reauthentication: 'Enter it in Pausely to confirm it is you.',
    },
    fallbackSentence: 'Enter it in Pausely to continue.',
    useOnce: 'It can be used once.',
    ignoreNote: "If you didn't ask for this, you can ignore this email.",
  },
  es: {
    dir: 'ltr',
    subjectPrefix: 'Tu código de Pausely',
    title: 'Tu código de Pausely',
    yourCode: 'Tu código',
    sentences: {
      signup: 'Introdúcelo en Pausely para terminar de crear tu cuenta.',
      magiclink: 'Introdúcelo en Pausely para iniciar sesión.',
      recovery: 'Introdúcelo en Pausely para elegir una nueva contraseña.',
      email_change: 'Introdúcelo en Pausely para confirmar tu nuevo correo electrónico.',
      email_change_current: 'Introdúcelo en Pausely para confirmar el cambio de correo electrónico.',
      reauthentication: 'Introdúcelo en Pausely para confirmar tu identidad.',
    },
    fallbackSentence: 'Introdúcelo en Pausely para continuar.',
    useOnce: 'Solo se puede usar una vez.',
    ignoreNote: 'Si no solicitaste esto, puedes ignorar este correo.',
  },
  fr: {
    dir: 'ltr',
    subjectPrefix: 'Votre code Pausely',
    title: 'Votre code Pausely',
    yourCode: 'Votre code',
    sentences: {
      signup: 'Saisissez-le dans Pausely pour terminer la création de votre compte.',
      magiclink: 'Saisissez-le dans Pausely pour vous connecter.',
      recovery: 'Saisissez-le dans Pausely pour choisir un nouveau mot de passe.',
      email_change: 'Saisissez-le dans Pausely pour confirmer votre nouvelle adresse e-mail.',
      email_change_current: 'Saisissez-le dans Pausely pour confirmer le changement d’adresse e-mail.',
      reauthentication: 'Saisissez-le dans Pausely pour confirmer votre identité.',
    },
    fallbackSentence: 'Saisissez-le dans Pausely pour continuer.',
    useOnce: 'Il ne peut être utilisé qu’une seule fois.',
    ignoreNote: 'Si vous n’avez pas demandé ce code, vous pouvez ignorer cet e-mail.',
  },
  de: {
    dir: 'ltr',
    subjectPrefix: 'Dein Pausely-Code',
    title: 'Dein Pausely-Code',
    yourCode: 'Dein Code',
    sentences: {
      signup: 'Gib ihn in Pausely ein, um dein Konto fertig einzurichten.',
      magiclink: 'Gib ihn in Pausely ein, um dich anzumelden.',
      recovery: 'Gib ihn in Pausely ein, um ein neues Passwort zu wählen.',
      email_change: 'Gib ihn in Pausely ein, um deine neue E-Mail-Adresse zu bestätigen.',
      email_change_current: 'Gib ihn in Pausely ein, um die Änderung deiner E-Mail-Adresse zu bestätigen.',
      reauthentication: 'Gib ihn in Pausely ein, um deine Identität zu bestätigen.',
    },
    fallbackSentence: 'Gib ihn in Pausely ein, um fortzufahren.',
    useOnce: 'Er kann nur einmal verwendet werden.',
    ignoreNote: 'Wenn du das nicht angefordert hast, kannst du diese E-Mail ignorieren.',
  },
  ja: {
    dir: 'ltr',
    subjectPrefix: 'Pauselyの確認コード',
    title: 'Pauselyの確認コード',
    yourCode: '確認コード',
    sentences: {
      signup: 'アカウント作成を完了するには、Pauselyでこのコードを入力してください。',
      magiclink: 'サインインするには、Pauselyでこのコードを入力してください。',
      recovery: '新しいパスワードを設定するには、Pauselyでこのコードを入力してください。',
      email_change: '新しいメールアドレスを確認するには、Pauselyでこのコードを入力してください。',
      email_change_current: 'メールアドレスの変更を確認するには、Pauselyでこのコードを入力してください。',
      reauthentication: '本人確認のため、Pauselyでこのコードを入力してください。',
    },
    fallbackSentence: '続行するには、Pauselyでこのコードを入力してください。',
    useOnce: 'このコードは1回のみ有効です。',
    ignoreNote: 'お心当たりがない場合は、このメールを無視してください。',
  },
  ar: {
    dir: 'rtl',
    subjectPrefix: 'رمز Pausely الخاص بك',
    title: 'رمز Pausely الخاص بك',
    yourCode: 'رمزك',
    sentences: {
      signup: 'أدخله في Pausely لإكمال إنشاء حسابك.',
      magiclink: 'أدخله في Pausely لتسجيل الدخول.',
      recovery: 'أدخله في Pausely لاختيار كلمة مرور جديدة.',
      email_change: 'أدخله في Pausely لتأكيد عنوان بريدك الإلكتروني الجديد.',
      email_change_current: 'أدخله في Pausely لتأكيد تغيير عنوان بريدك الإلكتروني.',
      reauthentication: 'أدخله في Pausely لتأكيد هويتك.',
    },
    fallbackSentence: 'أدخله في Pausely للمتابعة.',
    useOnce: 'يمكن استخدامه مرة واحدة فقط.',
    ignoreNote: 'إذا لم تطلب هذا الرمز، يمكنك تجاهل هذه الرسالة.',
  },
}

function resolveLang(rawLocale: unknown): Lang {
  if (typeof rawLocale !== 'string' || rawLocale.trim().length === 0) return 'en'
  const base = rawLocale.trim().toLowerCase().split(/[-_]/)[0]
  return Object.hasOwn(COPY, base) ? (base as Lang) : 'en'
}

function isValidEmail(value: unknown): value is string {
  if (typeof value !== 'string') return false
  if (value.length < 3 || value.length > 254) return false
  if (/[\x00-\x20\x7f]/.test(value)) return false
  return EMAIL_PATTERN.test(value)
}

function renderHtml(lang: Lang, pack: CopyPack, code: string, sentence: string): string {
  const align = pack.dir === 'rtl' ? 'right' : 'left'
  return `<!DOCTYPE html>
<html lang="${lang}" dir="${pack.dir}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="supported-color-schemes" content="dark">
  <title>${pack.title}</title>
</head>
<body style="margin:0; padding:0; background-color:#0A0B0D;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#0A0B0D;">
    <tr>
      <td align="center" style="padding:40px 20px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:440px; text-align:${align};">
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
                    ${pack.yourCode}
                  </td>
                </tr>
                <tr>
                  <td dir="ltr" style="font-family:ui-monospace,Menlo,Consolas,'Courier New',monospace; font-size:38px; font-weight:bold; letter-spacing:6px; color:#1A1A17; padding-bottom:16px; text-align:${align};">
                    ${code}
                  </td>
                </tr>
                <tr>
                  <td style="border-top:1px dashed #B9B3A4; padding-top:16px; font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:15px; line-height:22px; color:#1A1A17;">
                    ${sentence} ${pack.useOnce}
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:13px; line-height:20px; color:#A6A8AD; padding-top:24px;">
              ${pack.ignoreNote}
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`
}

function refuse(status: number, message: string): Response {
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

async function sendCodeEmail(to: string, code: string, purposeKey: string, lang: Lang): Promise<boolean> {
  const pack = COPY[lang]
  const sentence = Object.hasOwn(pack.sentences, purposeKey) ? pack.sentences[purposeKey] : pack.fallbackSentence
  let response: Response
  try {
    response = await fetch(`${RESEND_API_URL}/emails`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      signal: AbortSignal.timeout(10_000),
      body: JSON.stringify({
        from: FROM,
        to: [to],
        subject: `${pack.subjectPrefix}: ${code}`,
        html: renderHtml(lang, pack, code, sentence),
        text: `${pack.subjectPrefix}: ${code}\n\n${sentence} ${pack.useOnce}\n\n${pack.ignoreNote}`,
      }),
    })
  } catch {
    console.error('The mail provider could not be reached')
    return false
  }
  await drainResponse(response)
  if (!response.ok) {
    console.error('The mail provider refused the email: HTTP', response.status)
    return false
  }
  return true
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return refuse(405, 'Method not allowed')

  const body = await readBoundedText(req, MAX_BODY_BYTES)
  if (body === null) return refuse(413, 'Payload too large')
  if (!(await signedBySupabaseAuth(body, req.headers))) return refuse(401, 'Invalid signature')

  let payload: {
    user?: { email?: unknown; new_email?: unknown; user_metadata?: Record<string, unknown> }
    email_data?: { token?: unknown; token_new?: unknown; email_action_type?: unknown }
  }
  try {
    const parsed = JSON.parse(body)
    if (!parsed || typeof parsed !== 'object') return refuse(400, 'Invalid payload')
    payload = parsed
  } catch {
    return refuse(400, 'Invalid payload')
  }

  const purpose = typeof payload.email_data?.email_action_type === 'string'
    ? payload.email_data.email_action_type
    : ''
  const token = payload.email_data?.token
  const tokenNew = payload.email_data?.token_new
  const currentEmail = payload.user?.email
  const newEmail = payload.user?.new_email
  const lang = resolveLang(payload.user?.user_metadata?.locale)

  interface OutboundMessage {
    to: string
    code: string
    purposeKey: string
  }
  const messages: OutboundMessage[] = []

  if (purpose === 'email_change') {
    const hasCurrentToken = typeof token === 'string' && OTP_PATTERN.test(token)
    const hasNewToken = typeof tokenNew === 'string' && OTP_PATTERN.test(tokenNew)

    if (hasCurrentToken && hasNewToken) {
      // Double confirm (`double_confirm_changes = true`): `token` goes to current email, `token_new` goes to new email.
      if (!isValidEmail(currentEmail) || !isValidEmail(newEmail)) return refuse(400, 'Invalid payload')
      messages.push({ to: currentEmail, code: token, purposeKey: 'email_change_current' })
      messages.push({ to: newEmail, code: tokenNew, purposeKey: 'email_change' })
    } else {
      // Single confirm: send the provided token to `new_email` (falling back to `email`).
      const target = isValidEmail(newEmail) ? newEmail : (isValidEmail(currentEmail) ? currentEmail : null)
      const singleCode = hasCurrentToken ? token : (hasNewToken ? tokenNew : null)
      if (!target || !singleCode) return refuse(400, 'Invalid payload')
      messages.push({ to: target, code: singleCode, purposeKey: 'email_change' })
    }
  } else {
    if (!isValidEmail(currentEmail) || typeof token !== 'string' || !OTP_PATTERN.test(token)) {
      return refuse(400, 'Invalid payload')
    }
    messages.push({ to: currentEmail, code: token, purposeKey: purpose })
  }

  if (!RESEND_API_KEY) {
    return refuse(503, 'Mail provider not configured')
  }

  for (const msg of messages) {
    const sent = await sendCodeEmail(msg.to, msg.code, msg.purposeKey, lang)
    if (!sent) return refuse(502, 'The email could not be sent')
  }

  return new Response('{}', { status: 200, headers: { 'Content-Type': 'application/json' } })
})
