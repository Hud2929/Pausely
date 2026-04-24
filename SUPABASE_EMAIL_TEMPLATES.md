# Supabase Email Templates — Pausely

Copy these templates into your Supabase Dashboard:
**Project Settings > Auth > Email Templates**

Each template uses Handlebars syntax. The `{{ .Token }}` variable auto-injects the 6-digit OTP code.

---

## 1. Confirm Signup (OTP)

**Subject:** `Welcome to Pausely — Your verification code is {{ .Token }}`

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Welcome to Pausely</title>
  <style>
    @media only screen and (max-width: 600px) {
      .container { width: 100% !important; padding: 20px !important; }
      .code { font-size: 36px !important; letter-spacing: 12px !important; }
      .headline { font-size: 24px !important; }
    }
  </style>
</head>
<body style="margin:0; padding:0; background-color:#0B0B14; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background-color:#0B0B14;">
    <tr>
      <td align="center" style="padding:40px 0;">
        <table role="presentation" cellpadding="0" cellspacing="0" width="480" class="container" style="max-width:480px; width:100%; background:linear-gradient(145deg, #1A1A2E 0%, #131328 100%); border-radius:24px; border:1px solid rgba(255,255,255,0.06); overflow:hidden;">
          <!-- Header Glow -->
          <tr>
            <td style="background:linear-gradient(135deg, #8B5CF6 0%, #EC4899 50%, #6366F1 100%); height:4px;"></td>
          </tr>
          <!-- Logo -->
          <tr>
            <td align="center" style="padding:40px 40px 24px;">
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="width:64px; height:64px; background:linear-gradient(135deg, #8B5CF6, #6366F1); border-radius:50%; text-align:center; vertical-align:middle;">
                    <span style="color:#ffffff; font-size:32px; line-height:64px;">&#9208;</span>
                  </td>
                </tr>
              </table>
              <h1 style="margin:20px 0 0; color:#ffffff; font-size:28px; font-weight:700; letter-spacing:-0.5px;" class="headline">Welcome to Pausely</h1>
              <p style="margin:8px 0 0; color:rgba(255,255,255,0.55); font-size:16px; line-height:1.5;">The subscription manager that puts you in control.</p>
            </td>
          </tr>
          <!-- Divider -->
          <tr>
            <td style="padding:0 40px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr><td style="border-top:1px solid rgba(255,255,255,0.08);"></td></tr>
              </table>
            </td>
          </tr>
          <!-- OTP Code -->
          <tr>
            <td align="center" style="padding:32px 40px;">
              <p style="margin:0 0 16px; color:rgba(255,255,255,0.45); font-size:13px; text-transform:uppercase; letter-spacing:1.5px; font-weight:600;">Your Verification Code</p>
              <table role="presentation" cellpadding="0" cellspacing="0" style="background:rgba(139,92,246,0.12); border:1px solid rgba(139,92,246,0.25); border-radius:16px; padding:24px 40px;">
                <tr>
                  <td style="text-align:center;">
                    <span style="color:#ffffff; font-size:44px; font-weight:800; letter-spacing:16px; font-family:'SF Mono',Monaco,Consolas,'Liberation Mono','Courier New',monospace;" class="code">{{ .Token }}</span>
                  </td>
                </tr>
              </table>
              <p style="margin:16px 0 0; color:rgba(255,255,255,0.35); font-size:14px;">Enter this code in the Pausely app to verify your email.</p>
            </td>
          </tr>
          <!-- Divider -->
          <tr>
            <td style="padding:0 40px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr><td style="border-top:1px solid rgba(255,255,255,0.08);"></td></tr>
              </table>
            </td>
          </tr>
          <!-- Tips -->
          <tr>
            <td style="padding:24px 40px 32px;">
              <p style="margin:0 0 12px; color:rgba(255,255,255,0.45); font-size:13px; text-transform:uppercase; letter-spacing:1px; font-weight:600;">Quick Tips</p>
              <table role="presentation" cellpadding="0" cellspacing="0" width="100%">
                <tr>
                  <td style="padding:8px 0; vertical-align:top; width:24px;">
                    <span style="color:#8B5CF6; font-size:16px;">&#10003;</span>
                  </td>
                  <td style="padding:8px 0; color:rgba(255,255,255,0.6); font-size:14px; line-height:1.5;">Code expires in 1 hour</td>
                </tr>
                <tr>
                  <td style="padding:8px 0; vertical-align:top; width:24px;">
                    <span style="color:#8B5CF6; font-size:16px;">&#10003;</span>
                  </td>
                  <td style="padding:8px 0; color:rgba(255,255,255,0.6); font-size:14px; line-height:1.5;">Never share this code with anyone</td>
                </tr>
                <tr>
                  <td style="padding:8px 0; vertical-align:top; width:24px;">
                    <span style="color:#8B5CF6; font-size:16px;">&#10003;</span>
                  </td>
                  <td style="padding:8px 0; color:rgba(255,255,255,0.6); font-size:14px; line-height:1.5;">Didn't request this? You can safely ignore it</td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="padding:0 40px 32px; text-align:center;">
              <p style="margin:0; color:rgba(255,255,255,0.3); font-size:12px; line-height:1.6;">
                Sent to {{ .Email }}<br>
                Pausely &mdash; Smart Subscription Manager
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
```

---

## 2. Magic Link

**Subject:** `Your Pausely magic link`

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Your Pausely Magic Link</title>
  <style>
    @media only screen and (max-width: 600px) {
      .container { width: 100% !important; padding: 20px !important; }
      .headline { font-size: 24px !important; }
    }
  </style>
</head>
<body style="margin:0; padding:0; background-color:#0B0B14; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background-color:#0B0B14;">
    <tr>
      <td align="center" style="padding:40px 0;">
        <table role="presentation" cellpadding="0" cellspacing="0" width="480" class="container" style="max-width:480px; width:100%; background:linear-gradient(145deg, #1A1A2E 0%, #131328 100%); border-radius:24px; border:1px solid rgba(255,255,255,0.06); overflow:hidden;">
          <tr>
            <td style="background:linear-gradient(135deg, #8B5CF6 0%, #EC4899 50%, #6366F1 100%); height:4px;"></td>
          </tr>
          <tr>
            <td align="center" style="padding:40px 40px 24px;">
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="width:64px; height:64px; background:linear-gradient(135deg, #8B5CF6, #6366F1); border-radius:50%; text-align:center; vertical-align:middle;">
                    <span style="color:#ffffff; font-size:32px; line-height:64px;">&#9208;</span>
                  </td>
                </tr>
              </table>
              <h1 style="margin:20px 0 0; color:#ffffff; font-size:28px; font-weight:700; letter-spacing:-0.5px;" class="headline">Magic Link</h1>
              <p style="margin:8px 0 0; color:rgba(255,255,255,0.55); font-size:16px; line-height:1.5;">One tap to sign in to Pausely. No password needed.</p>
            </td>
          </tr>
          <tr>
            <td style="padding:0 40px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr><td style="border-top:1px solid rgba(255,255,255,0.08);"></td></tr>
              </table>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:32px 40px;">
              <a href="{{ .SiteURL }}auth/confirm?token={{ .Token }}&type=magiclink&email={{ .Email }}" style="display:inline-block; padding:18px 48px; background:linear-gradient(135deg, #8B5CF6, #6366F1); color:#ffffff; text-decoration:none; border-radius:14px; font-size:16px; font-weight:600; letter-spacing:0.3px;">Sign In to Pausely</a>
              <p style="margin:20px 0 0; color:rgba(255,255,255,0.35); font-size:13px; line-height:1.5;">Or copy and paste this link into your browser:<br><span style="color:rgba(255,255,255,0.5); word-break:break-all;">{{ .SiteURL }}auth/confirm?token={{ .Token }}&type=magiclink</span></p>
            </td>
          </tr>
          <tr>
            <td style="padding:0 40px 32px; text-align:center;">
              <p style="margin:0; color:rgba(255,255,255,0.3); font-size:12px; line-height:1.6;">
                Sent to {{ .Email }}<br>
                This link expires in 1 hour. Pausely &mdash; Smart Subscription Manager
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
```

---

## 3. Change Email

**Subject:** `Confirm your new Pausely email`

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Confirm Email Change</title>
  <style>
    @media only screen and (max-width: 600px) {
      .container { width: 100% !important; padding: 20px !important; }
      .code { font-size: 36px !important; letter-spacing: 12px !important; }
      .headline { font-size: 24px !important; }
    }
  </style>
</head>
<body style="margin:0; padding:0; background-color:#0B0B14; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background-color:#0B0B14;">
    <tr>
      <td align="center" style="padding:40px 0;">
        <table role="presentation" cellpadding="0" cellspacing="0" width="480" class="container" style="max-width:480px; width:100%; background:linear-gradient(145deg, #1A1A2E 0%, #131328 100%); border-radius:24px; border:1px solid rgba(255,255,255,0.06); overflow:hidden;">
          <tr>
            <td style="background:linear-gradient(135deg, #8B5CF6 0%, #EC4899 50%, #6366F1 100%); height:4px;"></td>
          </tr>
          <tr>
            <td align="center" style="padding:40px 40px 24px;">
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="width:64px; height:64px; background:linear-gradient(135deg, #8B5CF6, #6366F1); border-radius:50%; text-align:center; vertical-align:middle;">
                    <span style="color:#ffffff; font-size:32px; line-height:64px;">&#9208;</span>
                  </td>
                </tr>
              </table>
              <h1 style="margin:20px 0 0; color:#ffffff; font-size:28px; font-weight:700; letter-spacing:-0.5px;" class="headline">Confirm New Email</h1>
              <p style="margin:8px 0 0; color:rgba(255,255,255,0.55); font-size:16px; line-height:1.5;">You requested to change your Pausely email address.</p>
            </td>
          </tr>
          <tr>
            <td style="padding:0 40px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr><td style="border-top:1px solid rgba(255,255,255,0.08);"></td></tr>
              </table>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:32px 40px;">
              <p style="margin:0 0 16px; color:rgba(255,255,255,0.45); font-size:13px; text-transform:uppercase; letter-spacing:1.5px; font-weight:600;">Your Verification Code</p>
              <table role="presentation" cellpadding="0" cellspacing="0" style="background:rgba(139,92,246,0.12); border:1px solid rgba(139,92,246,0.25); border-radius:16px; padding:24px 40px;">
                <tr>
                  <td style="text-align:center;">
                    <span style="color:#ffffff; font-size:44px; font-weight:800; letter-spacing:16px; font-family:'SF Mono',Monaco,Consolas,'Liberation Mono','Courier New',monospace;" class="code">{{ .Token }}</span>
                  </td>
                </tr>
              </table>
              <p style="margin:16px 0 0; color:rgba(255,255,255,0.35); font-size:14px;">Enter this code in the app to confirm your new email.</p>
            </td>
          </tr>
          <tr>
            <td style="padding:0 40px 32px; text-align:center;">
              <p style="margin:0; color:rgba(255,255,255,0.3); font-size:12px; line-height:1.6;">
                Sent to {{ .Email }}<br>
                Pausely &mdash; Smart Subscription Manager
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
```

---

## 4. Reset Password

**Subject:** `Reset your Pausely password`

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Reset Your Password</title>
  <style>
    @media only screen and (max-width: 600px) {
      .container { width: 100% !important; padding: 20px !important; }
      .headline { font-size: 24px !important; }
    }
  </style>
</head>
<body style="margin:0; padding:0; background-color:#0B0B14; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="background-color:#0B0B14;">
    <tr>
      <td align="center" style="padding:40px 0;">
        <table role="presentation" cellpadding="0" cellspacing="0" width="480" class="container" style="max-width:480px; width:100%; background:linear-gradient(145deg, #1A1A2E 0%, #131328 100%); border-radius:24px; border:1px solid rgba(255,255,255,0.06); overflow:hidden;">
          <tr>
            <td style="background:linear-gradient(135deg, #8B5CF6 0%, #EC4899 50%, #6366F1 100%); height:4px;"></td>
          </tr>
          <tr>
            <td align="center" style="padding:40px 40px 24px;">
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="width:64px; height:64px; background:linear-gradient(135deg, #8B5CF6, #6366F1); border-radius:50%; text-align:center; vertical-align:middle;">
                    <span style="color:#ffffff; font-size:32px; line-height:64px;">&#9208;</span>
                  </td>
                </tr>
              </table>
              <h1 style="margin:20px 0 0; color:#ffffff; font-size:28px; font-weight:700; letter-spacing:-0.5px;" class="headline">Reset Password</h1>
              <p style="margin:8px 0 0; color:rgba(255,255,255,0.55); font-size:16px; line-height:1.5;">We received a request to reset your Pausely password.</p>
            </td>
          </tr>
          <tr>
            <td style="padding:0 40px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr><td style="border-top:1px solid rgba(255,255,255,0.08);"></td></tr>
              </table>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:32px 40px;">
              <a href="{{ .SiteURL }}auth/reset-password?token={{ .Token }}&email={{ .Email }}" style="display:inline-block; padding:18px 48px; background:linear-gradient(135deg, #8B5CF6, #6366F1); color:#ffffff; text-decoration:none; border-radius:14px; font-size:16px; font-weight:600; letter-spacing:0.3px;">Reset Password</a>
              <p style="margin:20px 0 0; color:rgba(255,255,255,0.35); font-size:13px; line-height:1.5;">Or copy and paste this link into your browser:<br><span style="color:rgba(255,255,255,0.5); word-break:break-all;">{{ .SiteURL }}auth/reset-password?token={{ .Token }}&email={{ .Email }}</span></p>
              <p style="margin:16px 0 0; color:rgba(255,255,255,0.3); font-size:12px;">Didn't request this? You can safely ignore this email.</p>
            </td>
          </tr>
          <tr>
            <td style="padding:0 40px 32px; text-align:center;">
              <p style="margin:0; color:rgba(255,255,255,0.3); font-size:12px; line-height:1.6;">
                Sent to {{ .Email }}<br>
                Pausely &mdash; Smart Subscription Manager
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
```

---

## How to Apply

1. Go to **Supabase Dashboard** → Select your project
2. Navigate to **Authentication** → **Email Templates**
3. For each template tab (Confirm signup, Magic Link, Change Email, Reset Password):
   - Paste the corresponding HTML into the **Body** field
   - Paste the Subject line into the **Subject** field
   - Click **Save**
4. Make sure your **Site URL** is configured correctly:
   - Go to **Authentication** → **URL Configuration**
   - Site URL: `https://your-app-url.com` (or `pausely://` for deep links)
   - Redirect URLs: Add `pausely://auth/confirm` and `pausely://auth/reset-password`

> **Note:** Supabase uses table-based HTML for maximum email client compatibility (Gmail, Apple Mail, Outlook). The dark theme, gradient accents, and glass-like card match Pausely's iOS app aesthetic.
