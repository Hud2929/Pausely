// Waitlist Signup + Welcome Email Edge Function
// Supports high-volume email via AWS SES ($0.10 per 1,000) or Resend (easier setup)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { AwsClient } from 'https://esm.sh/aws4fetch@1.0.17'

// Email provider selection
const USE_AWS_SES = !!Deno.env.get('AWS_ACCESS_KEY_ID')
const AWS_REGION = Deno.env.get('AWS_REGION') || 'us-east-1'
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email, source } = await req.json()

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    if (!email || !emailRegex.test(email)) {
      return new Response(
        JSON.stringify({ error: 'Invalid email address' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const normalizedEmail = email.toLowerCase().trim()

    const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!, {
      auth: { autoRefreshToken: false, persistSession: false }
    })

    const { data: existing } = await supabase
      .from('waitlist')
      .select('id')
      .eq('email', normalizedEmail)
      .single()

    if (existing) {
      return new Response(
        JSON.stringify({ success: true, message: 'Already on the list!', already_exists: true }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { error: insertError } = await supabase
      .from('waitlist')
      .insert({
        email: normalizedEmail,
        source: source || 'waitlist'
      })

    if (insertError) {
      console.error('Waitlist insert error:', insertError)
      return new Response(
        JSON.stringify({ error: 'Failed to join waitlist' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let emailSent = false
    let provider = 'none'
    const htmlBody = getWelcomeEmailHTML(normalizedEmail)

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
            Destination: { ToAddresses: [normalizedEmail] },
            FromEmailAddress: Deno.env.get('SES_FROM_EMAIL') || 'hello@pausely.app',
            ReplyToAddresses: [Deno.env.get('SES_REPLY_TO') || 'support@pausely.app']
          })
        })

        if (response.status === 200) {
          emailSent = true
          provider = 'aws_ses'
          console.log(`[AWS SES] Welcome email sent to ${normalizedEmail}`)
        } else {
          const errorText = await response.text()
          console.error('[AWS SES] Error:', errorText)
        }
      } catch (sesErr) {
        console.error('[AWS SES] Failed:', sesErr)
      }
    } else if (RESEND_API_KEY && !RESEND_API_KEY.includes('YOUR_RESEND')) {
      try {
        const response = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${RESEND_API_KEY}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            from: 'Pausely <onboarding@resend.dev>',
            to: normalizedEmail,
            subject: "You're on the Pausely waitlist!",
            html: htmlBody
          })
        })

        if (response.ok) {
          emailSent = true
          provider = 'resend'
          console.log(`[Resend] Welcome email sent to ${normalizedEmail}`)
        } else {
          const errorText = await response.text()
          console.error('[Resend] Error:', errorText)
        }
      } catch (resendErr) {
        console.error('[Resend] Failed:', resendErr)
      }
    } else {
      console.log(`[DEBUG MODE] Would send welcome email to: ${normalizedEmail}`)
      console.log('[DEBUG MODE] Set AWS SES credentials OR RESEND_API_KEY to send real emails')
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Welcome to the waitlist! Check your email.",
        email_sent: emailSent,
        provider: provider
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Edge function error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
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
                    <a href="https://pausely.app" style="display:inline-block;padding:14px 32px;background-color:#111827;color:#FFFFFF;text-decoration:none;border-radius:10px;font-size:15px;font-weight:600;">
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
                <a href="https://pausely.app/support" style="color:#6B7280;text-decoration:underline;">Support</a>
                &nbsp;&middot;&nbsp;
                <a href="https://pausely.app/privacy" style="color:#6B7280;text-decoration:underline;">Privacy</a>
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
