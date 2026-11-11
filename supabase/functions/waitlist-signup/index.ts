// Waitlist sign-up and welcome email (Supabase Edge Function).
// The website posts { email, source } with no key, so everything here assumes a hostile caller.
// Mail goes out through AWS SES ($0.10 per 1,000) or Resend.
//
// What limits abuse, most important first:
//   1. One welcome email per address, ever (the waitlist's unique email).
//   2. A ceiling on new sign-ups per hour, counted in the database, so it holds across cold starts
//      and across every running copy: WAITLIST_MAX_PER_HOUR (default 200).
//   3. An optional CAPTCHA: set TURNSTILE_SECRET_KEY and have the page send the widget's token as
//      captcha_token. Without the secret this step is skipped.
//   4. A per-caller limit kept in memory. It resets on a cold start and a caller can dodge it, so it
//      only slows a naive loop.
// The reply is the same whether or not the address was already on the list, and no address is logged.
// Tested by scripts/dbtest/waitlist_function.sh.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.117.3'
import { AwsClient } from 'https://esm.sh/aws4fetch@1.0.17'

const USE_AWS_SES = !!Deno.env.get('AWS_ACCESS_KEY_ID')
const AWS_REGION = Deno.env.get('AWS_REGION') || 'us-east-1'
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const USE_RESEND = !USE_AWS_SES && !!RESEND_API_KEY && !RESEND_API_KEY.includes('YOUR_RESEND')

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

const TURNSTILE_SECRET_KEY = Deno.env.get('TURNSTILE_SECRET_KEY')
const MAX_SIGNUPS_PER_HOUR = positiveInt(Deno.env.get('WAITLIST_MAX_PER_HOUR'), 200)
const MAX_EMAIL_LENGTH = 254
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const VALID_SOURCES = new Set([
  'waitlist', 'organic', 'tiktok', 'instagram', 'twitter', 'youtube',
  'friend', 'search', 'other'
])

function positiveInt(value: string | undefined, fallback: number): number {
  const parsed = Number.parseInt(value ?? '', 10)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback
}

function reply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })
}

/// The one reply for "this address is on the list", new or not.
function joined(): Response {
  return reply(200, {
    success: true,
    message: 'Welcome to the waitlist! Check your email.',
    email_sent: USE_AWS_SES || USE_RESEND
  })
}

// MARK: Per-caller limit (in memory): 5 requests a minute

const rateLimitMap = new Map<string, { count: number; resetTime: number }>()
const RATE_LIMIT_MAX = 5
const RATE_LIMIT_WINDOW_MS = 60_000
const RATE_LIMIT_MAX_KEYS = 5_000

function checkRateLimit(key: string): boolean {
  const now = Date.now()
  if (rateLimitMap.size > RATE_LIMIT_MAX_KEYS) {
    // A flood of made-up callers must not grow this map without end.
    for (const [existingKey, entry] of rateLimitMap) {
      if (now > entry.resetTime) rateLimitMap.delete(existingKey)
    }
    if (rateLimitMap.size > RATE_LIMIT_MAX_KEYS) rateLimitMap.clear()
  }
  const entry = rateLimitMap.get(key)
  if (!entry || now > entry.resetTime) {
    rateLimitMap.set(key, { count: 1, resetTime: now + RATE_LIMIT_WINDOW_MS })
    return true
  }
  if (entry.count >= RATE_LIMIT_MAX) {
    return false
  }
  entry.count++
  return true
}

/// Cloudflare's header can't be set by the caller when the request came through Cloudflare; the
/// forwarded-for list can, which is why this limit is only a courtesy.
function callerKey(req: Request): string {
  return req.headers.get('cf-connecting-ip')
    || (req.headers.get('x-forwarded-for') || '').split(',')[0].trim()
    || 'unknown'
}

// MARK: CAPTCHA (Cloudflare Turnstile), only when TURNSTILE_SECRET_KEY is set

async function passesCaptcha(token: unknown, req: Request): Promise<boolean> {
  if (typeof token !== 'string' || token.length === 0 || token.length > 2048) return false
  try {
    const form = new URLSearchParams({ secret: TURNSTILE_SECRET_KEY!, response: token })
    const callerIP = req.headers.get('cf-connecting-ip')
    if (callerIP) form.set('remoteip', callerIP)
    const response = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
      method: 'POST',
      body: form
    })
    const result = await response.json()
    return result?.success === true
  } catch {
    return false
  }
}

// MARK: Welcome email

async function sendWelcomeEmail(address: string): Promise<void> {
  const htmlBody = getWelcomeEmailHTML(address)

  if (USE_AWS_SES) {
    try {
      const aws = new AwsClient({
        accessKeyId: Deno.env.get('AWS_ACCESS_KEY_ID')!,
        secretAccessKey: Deno.env.get('AWS_SECRET_ACCESS_KEY')!,
        region: AWS_REGION
      })

      const response = await aws.fetch(`https://email.${AWS_REGION}.amazonaws.com/v2/email/outbound-emails`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          Content: {
            Simple: {
              Subject: { Data: "You're on the Pausely waitlist!", Charset: 'UTF-8' },
              Body: { Html: { Data: htmlBody, Charset: 'UTF-8' } }
            }
          },
          Destination: { ToAddresses: [address] },
          FromEmailAddress: Deno.env.get('SES_FROM_EMAIL') || 'hello@pausely.app',
          ReplyToAddresses: [Deno.env.get('SES_REPLY_TO') || 'support@pausely.app']
        })
      })

      if (response.status === 200) {
        console.log('[AWS SES] Welcome email sent')
      } else {
        console.error('[AWS SES] Error: HTTP', response.status)
      }
    } catch (sesErr) {
      console.error('[AWS SES] Failed:', sesErr instanceof Error ? sesErr.message : 'unknown error')
    }
  } else if (USE_RESEND) {
    try {
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${RESEND_API_KEY}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          from: 'Pausely <hello@pausely.pro>',
          to: address,
          subject: "You're on the Pausely waitlist!",
          html: htmlBody
        })
      })

      if (response.ok) {
        console.log('[Resend] Welcome email sent')
      } else {
        console.error('[Resend] Error: HTTP', response.status)
      }
    } catch (resendErr) {
      console.error('[Resend] Failed:', resendErr instanceof Error ? resendErr.message : 'unknown error')
    }
  } else {
    console.log('[DEBUG MODE] No mail provider is set, so no welcome email was sent')
  }
}

// MARK: The endpoint

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'POST') {
    return reply(405, { error: 'Method not allowed' })
  }
  if (!checkRateLimit(callerKey(req))) {
    return reply(429, { error: 'Rate limit exceeded. Please try again later.' })
  }

  try {
    let body: unknown
    try {
      body = await req.json()
    } catch {
      return reply(400, { error: 'Invalid request' })
    }
    const fields = (body !== null && typeof body === 'object' ? body : {}) as Record<string, unknown>

    const normalizedEmail = typeof fields.email === 'string' ? fields.email.trim().toLowerCase() : ''
    if (!normalizedEmail || normalizedEmail.length > MAX_EMAIL_LENGTH || !EMAIL_PATTERN.test(normalizedEmail)) {
      return reply(400, { error: 'Invalid email address' })
    }

    const normalizedSource = typeof fields.source === 'string' ? fields.source.toLowerCase().trim() : 'waitlist'
    const validSource = VALID_SOURCES.has(normalizedSource) ? normalizedSource : 'other'

    if (TURNSTILE_SECRET_KEY && !(await passesCaptcha(fields.captcha_token, req))) {
      return reply(403, { error: 'Please complete the check and try again.' })
    }

    const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!, {
      auth: { autoRefreshToken: false, persistSession: false }
    })

    // The hourly ceiling comes first and applies to every address, so a reply at the ceiling says
    // nothing about whether the address was already on the list.
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString()
    const { count: recentSignups, error: countError } = await supabase
      .from('waitlist')
      .select('id', { count: 'exact', head: true })
      .gt('created_at', oneHourAgo)

    if (countError) {
      console.error('Waitlist count error:', countError.message)
      return reply(500, { error: 'Failed to join waitlist' })
    }
    if ((recentSignups ?? 0) >= MAX_SIGNUPS_PER_HOUR) {
      console.warn('Waitlist hourly ceiling reached:', MAX_SIGNUPS_PER_HOUR)
      return reply(429, { error: 'The waitlist is busy right now. Please try again in an hour.' })
    }

    const { data: existing, error: lookupError } = await supabase
      .from('waitlist')
      .select('id')
      .eq('email', normalizedEmail)
      .maybeSingle()

    if (lookupError) {
      console.error('Waitlist lookup error:', lookupError.message)
      return reply(500, { error: 'Failed to join waitlist' })
    }
    if (existing) {
      return joined()
    }

    const { error: insertError } = await supabase
      .from('waitlist')
      .insert({
        email: normalizedEmail,
        source: validSource
      })

    if (insertError) {
      // Two requests for one new address can cross; the second meets the unique email.
      if (insertError.code === '23505') {
        return joined()
      }
      console.error('Waitlist insert error:', insertError.message)
      return reply(500, { error: 'Failed to join waitlist' })
    }

    await sendWelcomeEmail(normalizedEmail)
    return joined()

  } catch (error) {
    console.error('Edge function error:', error instanceof Error ? error.message : 'unknown error')
    return reply(500, { error: 'Internal server error' })
  }
})

function getWelcomeEmailHTML(email: string): string {
  const iconUrl = 'https://pausely.pro/icon-email.png'
  /* old base64 icon removed — using hosted URL above for email client compatibility */
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light">
  <meta name="supported-color-schemes" content="light">
  <title>Welcome to Pausely</title>
</head>
<body style="margin:0;padding:0;background-color:#F3F4F6;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr>
      <td align="center" style="padding:48px 16px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:520px;">

          <!-- Logo -->
          <tr>
            <td align="center" style="padding-bottom:32px;">
              <img src="${iconUrl}" alt="Pausely" width="72" height="72" style="border-radius:16px;display:block;">
            </td>
          </tr>

          <!-- Main Card -->
          <tr>
            <td style="background-color:#FFFFFF;border-radius:20px;padding:48px 40px;box-shadow:0 1px 3px rgba(0,0,0,0.08);">

              <!-- Headline -->
              <h1 style="margin:0 0 12px 0;font-size:26px;font-weight:700;color:#111827;text-align:center;letter-spacing:-0.3px;">
                You're on the list
              </h1>
              <p style="margin:0 0 40px 0;font-size:16px;color:#4B5563;text-align:center;line-height:1.6;">
                Thanks for joining the Pausely waitlist. You're first in line for early access.
              </p>

              <!-- What to expect -->
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-bottom:40px;">
                <tr>
                  <td style="background-color:#F9FAFB;border-radius:12px;padding:24px;border:1px solid #E5E7EB;">
                    <p style="margin:0 0 16px 0;font-size:13px;font-weight:600;color:#6B7280;text-transform:uppercase;letter-spacing:0.5px;">
                      What's coming
                    </p>
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td style="padding:10px 0;border-bottom:1px solid #E5E7EB;">
                          <p style="margin:0;font-size:15px;color:#111827;font-weight:600;">Early Access</p>
                          <p style="margin:4px 0 0 0;font-size:14px;color:#6B7280;">Be the first to try new features before anyone else.</p>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding:10px 0;border-bottom:1px solid #E5E7EB;">
                          <p style="margin:0;font-size:15px;color:#111827;font-weight:600;">Advanced Analytics</p>
                          <p style="margin:4px 0 0 0;font-size:14px;color:#6B7280;">Deep insights into your subscriptions and spending.</p>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding:10px 0 0 0;">
                          <p style="margin:0;font-size:15px;color:#111827;font-weight:600;">Launch Perks</p>
                          <p style="margin:4px 0 0 0;font-size:14px;color:#6B7280;">Exclusive perks for waitlist members only.</p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Message -->
              <p style="margin:0 0 32px 0;font-size:15px;color:#4B5563;text-align:center;line-height:1.6;">
                We'll email you as soon as the new version is ready. No spam — just a heads up when it's time to take control of your subscriptions.
              </p>

              <!-- CTA -->
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td align="center">
                    <a href="https://pausely.pro" style="display:inline-block;padding:14px 32px;background-color:#111827;color:#FFFFFF;text-decoration:none;border-radius:10px;font-size:15px;font-weight:600;">
                      Visit Pausely
                    </a>
                  </td>
                </tr>
              </table>

            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td align="center" style="padding-top:32px;">
              <p style="margin:0 0 8px 0;font-size:13px;color:#9CA3AF;">
                You received this because you signed up for the Pausely waitlist.
              </p>
              <p style="margin:0;font-size:13px;color:#9CA3AF;">
                &copy; 2026 Pausely. All rights reserved.
              </p>
              <p style="margin:8px 0 0 0;font-size:13px;color:#9CA3AF;">
                <a href="https://pausely.pro/support" style="color:#6B7280;text-decoration:underline;">Support</a>
                &nbsp;&middot;&nbsp;
                <a href="https://pausely.pro/privacy" style="color:#6B7280;text-decoration:underline;">Privacy</a>
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`
}
