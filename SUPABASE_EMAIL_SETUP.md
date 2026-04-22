# Pausely Email Configuration

This guide explains how to set up personalized Pausely-branded emails in Supabase.

## 1. Configure Site URL and Redirect URLs

In your Supabase Dashboard:

1. Go to **Authentication** → **URL Configuration**
2. Set **Site URL** to: `pausely://auth/callback`
3. Add these **Redirect URLs**:
   - `pausely://auth/confirm`
   - `pausely://auth/reset-password`
   - `http://localhost:3000/*` (for web testing)
   - `https://yourdomain.com/*` (for production website)

## 2. Custom Email Templates

Go to **Authentication** → **Email Templates** and replace each template with the Pausely-branded versions below.

### Confirm Signup Email

**Subject:** `Welcome to Pausely - Confirm Your Email`

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to Pausely</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.6;
            color: #1a1a2e;
            background-color: #f5f5f7;
            margin: 0;
            padding: 0;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 40px 20px;
        }
        .email-wrapper {
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            border-radius: 24px;
            padding: 48px 40px;
            text-align: center;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        .logo {
            width: 80px;
            height: 80px;
            background: linear-gradient(135deg, #8b5cf6 0%, #ec4899 100%);
            border-radius: 50%;
            margin: 0 auto 32px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 40px;
        }
        h1 {
            color: #ffffff;
            font-size: 28px;
            font-weight: 700;
            margin: 0 0 16px;
        }
        .subtitle {
            color: rgba(255,255,255,0.7);
            font-size: 16px;
            margin-bottom: 32px;
        }
        .button {
            display: inline-block;
            background: linear-gradient(135deg, #8b5cf6 0%, #ec4899 100%);
            color: #ffffff !important;
            text-decoration: none;
            padding: 16px 40px;
            border-radius: 12px;
            font-weight: 600;
            font-size: 16px;
            margin: 24px 0;
            box-shadow: 0 4px 20px rgba(139, 92, 246, 0.4);
        }
        .divider {
            height: 1px;
            background: rgba(255,255,255,0.1);
            margin: 32px 0;
        }
        .footer {
            color: rgba(255,255,255,0.5);
            font-size: 14px;
            line-height: 1.5;
        }
        .fallback {
            background: rgba(255,255,255,0.05);
            border-radius: 12px;
            padding: 20px;
            margin: 24px 0;
            word-break: break-all;
        }
        .fallback p {
            color: rgba(255,255,255,0.6);
            font-size: 13px;
            margin: 0 0 8px;
        }
        .fallback a {
            color: #fbbf24 !important;
            text-decoration: none;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="email-wrapper">
            <div class="logo">⏸️</div>
            <h1>Welcome to Pausely</h1>
            <p class="subtitle">Smart subscription management starts here</p>
            
            <p style="color: rgba(255,255,255,0.8); font-size: 16px; margin-bottom: 24px;">
                Hi {{ .Email }},<br><br>
                Thanks for signing up! Please confirm your email address to start managing your subscriptions and saving money.
            </p>
            
            <a href="{{ .ConfirmationURL }}" class="button">Confirm Email Address</a>
            
            <div class="divider"></div>
            
            <div class="fallback">
                <p>Button not working? Copy and paste this link into your browser:</p>
                <a href="{{ .ConfirmationURL }}">{{ .ConfirmationURL }}</a>
            </div>
            
            <div class="footer">
                <p>This link will expire in 24 hours.<br>
                If you didn't create an account, you can safely ignore this email.</p>
                <p style="margin-top: 24px; font-size: 12px;">
                    © 2024 Pausely. All rights reserved.<br>
                    Smart subscription management for everyone.
                </p>
            </div>
        </div>
    </div>
</body>
</html>
```

### Reset Password Email

**Subject:** `Reset Your Pausely Password`

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reset Your Password</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.6;
            color: #1a1a2e;
            background-color: #f5f5f7;
            margin: 0;
            padding: 0;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 40px 20px;
        }
        .email-wrapper {
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            border-radius: 24px;
            padding: 48px 40px;
            text-align: center;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        .logo {
            width: 80px;
            height: 80px;
            background: linear-gradient(135deg, #8b5cf6 0%, #ec4899 100%);
            border-radius: 50%;
            margin: 0 auto 32px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 40px;
        }
        h1 {
            color: #ffffff;
            font-size: 28px;
            font-weight: 700;
            margin: 0 0 16px;
        }
        .subtitle {
            color: rgba(255,255,255,0.7);
            font-size: 16px;
            margin-bottom: 32px;
        }
        .button {
            display: inline-block;
            background: linear-gradient(135deg, #8b5cf6 0%, #ec4899 100%);
            color: #ffffff !important;
            text-decoration: none;
            padding: 16px 40px;
            border-radius: 12px;
            font-weight: 600;
            font-size: 16px;
            margin: 24px 0;
            box-shadow: 0 4px 20px rgba(139, 92, 246, 0.4);
        }
        .divider {
            height: 1px;
            background: rgba(255,255,255,0.1);
            margin: 32px 0;
        }
        .footer {
            color: rgba(255,255,255,0.5);
            font-size: 14px;
            line-height: 1.5;
        }
        .fallback {
            background: rgba(255,255,255,0.05);
            border-radius: 12px;
            padding: 20px;
            margin: 24px 0;
            word-break: break-all;
        }
        .fallback p {
            color: rgba(255,255,255,0.6);
            font-size: 13px;
            margin: 0 0 8px;
        }
        .fallback a {
            color: #fbbf24 !important;
            text-decoration: none;
            font-size: 14px;
        }
        .security-notice {
            background: rgba(251, 191, 36, 0.1);
            border: 1px solid rgba(251, 191, 36, 0.3);
            border-radius: 12px;
            padding: 20px;
            margin: 24px 0;
        }
        .security-notice p {
            color: #fbbf24;
            font-size: 14px;
            margin: 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="email-wrapper">
            <div class="logo">⏸️</div>
            <h1>Reset Your Password</h1>
            <p class="subtitle">We received a request to reset your password</p>
            
            <p style="color: rgba(255,255,255,0.8); font-size: 16px; margin-bottom: 24px;">
                Hi {{ .Email }},<br><br>
                Someone (hopefully you) requested a password reset for your Pausely account. Click the button below to create a new password.
            </p>
            
            <a href="{{ .ConfirmationURL }}" class="button">Reset Password</a>
            
            <div class="security-notice">
                <p>⚠️ If you didn't request this reset, you can safely ignore this email. Your password will remain unchanged.</p>
            </div>
            
            <div class="divider"></div>
            
            <div class="fallback">
                <p>Button not working? Copy and paste this link into your browser:</p>
                <a href="{{ .ConfirmationURL }}">{{ .ConfirmationURL }}</a>
            </div>
            
            <div class="footer">
                <p>This link will expire in 1 hour for security reasons.</p>
                <p style="margin-top: 24px; font-size: 12px;">
                    © 2024 Pausely. All rights reserved.<br>
                    Smart subscription management for everyone.
                </p>
            </div>
        </div>
    </div>
</body>
</html>
```

### Magic Link Email

**Subject:** `Your Pausely Login Link`

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Your Pausely Login Link</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.6;
            color: #1a1a2e;
            background-color: #f5f5f7;
            margin: 0;
            padding: 0;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 40px 20px;
        }
        .email-wrapper {
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            border-radius: 24px;
            padding: 48px 40px;
            text-align: center;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        .logo {
            width: 80px;
            height: 80px;
            background: linear-gradient(135deg, #8b5cf6 0%, #ec4899 100%);
            border-radius: 50%;
            margin: 0 auto 32px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 40px;
        }
        h1 {
            color: #ffffff;
            font-size: 28px;
            font-weight: 700;
            margin: 0 0 16px;
        }
        .subtitle {
            color: rgba(255,255,255,0.7);
            font-size: 16px;
            margin-bottom: 32px;
        }
        .button {
            display: inline-block;
            background: linear-gradient(135deg, #8b5cf6 0%, #ec4899 100%);
            color: #ffffff !important;
            text-decoration: none;
            padding: 16px 40px;
            border-radius: 12px;
            font-weight: 600;
            font-size: 16px;
            margin: 24px 0;
            box-shadow: 0 4px 20px rgba(139, 92, 246, 0.4);
        }
        .divider {
            height: 1px;
            background: rgba(255,255,255,0.1);
            margin: 32px 0;
        }
        .footer {
            color: rgba(255,255,255,0.5);
            font-size: 14px;
            line-height: 1.5;
        }
        .fallback {
            background: rgba(255,255,255,0.05);
            border-radius: 12px;
            padding: 20px;
            margin: 24px 0;
            word-break: break-all;
        }
        .fallback p {
            color: rgba(255,255,255,0.6);
            font-size: 13px;
            margin: 0 0 8px;
        }
        .fallback a {
            color: #fbbf24 !important;
            text-decoration: none;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="email-wrapper">
            <div class="logo">⏸️</div>
            <h1>Your Magic Link</h1>
            <p class="subtitle">Password-free login to Pausely</p>
            
            <p style="color: rgba(255,255,255,0.8); font-size: 16px; margin-bottom: 24px;">
                Hi {{ .Email }},<br><br>
                Click the button below to securely sign in to your Pausely account. No password needed!
            </p>
            
            <a href="{{ .ConfirmationURL }}" class="button">Sign In to Pausely</a>
            
            <div class="divider"></div>
            
            <div class="fallback">
                <p>Button not working? Copy and paste this link into your browser:</p>
                <a href="{{ .ConfirmationURL }}">{{ .ConfirmationURL }}</a>
            </div>
            
            <div class="footer">
                <p>This link will expire in 1 hour.<br>
                If you didn't request this, you can safely ignore this email.</p>
                <p style="margin-top: 24px; font-size: 12px;">
                    © 2024 Pausely. All rights reserved.<br>
                    Smart subscription management for everyone.
                </p>
            </div>
        </div>
    </div>
</body>
</html>
```

## 3. Email Settings

In **Authentication** → **SMTP Settings**:

1. **Sender Name:** `Pausely`
2. **Sender Email:** `noreply@pausely.app` (or your custom domain)

If you want to use a custom domain:
1. Set up a custom domain in Supabase
2. Configure SPF, DKIM, and DMARC records with your DNS provider
3. Verify the domain in Supabase

## 4. Test the Setup

1. Create a new account in the app
2. Check that you receive a Pausely-branded email
3. Click the confirmation link - it should open the app and confirm the email
4. If the link doesn't work, check that the URL scheme is properly configured in Info.plist

## Troubleshooting

### Email not received
- Check spam/junk folders
- Verify email templates are saved
- Check Supabase email logs in Dashboard

### Link opens browser instead of app
- Ensure `pausely://` URL scheme is in Info.plist
- Test on a real device (simulators can have issues with deep links)
- Verify redirect URLs in Supabase Auth settings

### Deep link not working
- Check console logs for the URL
- Ensure the app is properly handling `onOpenURL`
- Verify the URL format matches what Supabase is sending
