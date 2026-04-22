# Supabase Email Configuration - Pausely

## Step-by-Step Setup

### 1. Go to Supabase Dashboard
- Open https://supabase.com/dashboard
- Select your Pausely project
- Go to **Authentication** → **Email Templates**

### 2. Configure Confirmation Email (SIGN UP)
**Template Type**: Confirm Signup
**Subject**: `Confirm Your Email - Pausely`

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to Pausely</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
        
        body {
            margin: 0;
            padding: 0;
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #0F0F0F 0%, #1A1A2E 50%, #16213E 100%);
            color: #FFFFFF;
        }
        
        .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 40px 20px;
        }
        
        .header {
            text-align: center;
            padding: 40px 0;
        }
        
        .logo {
            font-size: 42px;
            font-weight: 700;
            background: linear-gradient(135deg, #8B5CF6 0%, #EC4899 50%, #F59E0B 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 10px;
        }
        
        .tagline {
            font-size: 16px;
            color: rgba(255, 255, 255, 0.6);
            letter-spacing: 2px;
            text-transform: uppercase;
        }
        
        .card {
            background: rgba(255, 255, 255, 0.05);
            backdrop-filter: blur(20px);
            border-radius: 24px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            padding: 48px;
            margin: 32px 0;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
        }
        
        .title {
            font-size: 28px;
            font-weight: 700;
            margin-bottom: 16px;
            text-align: center;
        }
        
        .subtitle {
            font-size: 16px;
            color: rgba(255, 255, 255, 0.7);
            line-height: 1.6;
            text-align: center;
            margin-bottom: 32px;
        }
        
        .button-container {
            text-align: center;
            margin: 32px 0;
        }
        
        .button {
            display: inline-block;
            padding: 18px 48px;
            background: linear-gradient(135deg, #8B5CF6 0%, #EC4899 100%);
            color: #FFFFFF;
            text-decoration: none;
            border-radius: 14px;
            font-weight: 600;
            font-size: 16px;
            box-shadow: 0 10px 40px -10px rgba(139, 92, 246, 0.5);
        }
        
        .divider {
            height: 1px;
            background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
            margin: 32px 0;
        }
        
        .features {
            display: flex;
            justify-content: space-around;
            flex-wrap: wrap;
            margin: 32px 0;
        }
        
        .feature {
            text-align: center;
            padding: 16px;
            flex: 1;
            min-width: 120px;
        }
        
        .feature-icon {
            font-size: 32px;
            margin-bottom: 8px;
        }
        
        .feature-text {
            font-size: 14px;
            color: rgba(255, 255, 255, 0.8);
        }
        
        .footer {
            text-align: center;
            padding: 32px 0;
            color: rgba(255, 255, 255, 0.4);
            font-size: 14px;
        }
        
        .support {
            background: rgba(245, 158, 11, 0.1);
            border: 1px solid rgba(245, 158, 11, 0.3);
            border-radius: 12px;
            padding: 20px;
            margin-top: 32px;
            text-align: center;
        }
        
        .support-title {
            color: #F59E0B;
            font-weight: 600;
            margin-bottom: 8px;
        }
        
        .support-email {
            color: #FFFFFF;
            text-decoration: none;
        }
        
        @media (max-width: 480px) {
            .card {
                padding: 32px 24px;
            }
            
            .title {
                font-size: 24px;
            }
            
            .button {
                padding: 16px 32px;
                font-size: 15px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">Pausely</div>
            <div class="tagline">Take Control</div>
        </div>
        
        <div class="card">
            <h1 class="title">Welcome to the Revolution</h1>
            <p class="subtitle">
                You're one step away from mastering your subscriptions. 
                Confirm your email to unlock the full power of Pausely.
            </p>
            
            <div class="button-container">
                <a href="{{ .ConfirmationURL }}" class="button">Confirm Email Address</a>
            </div>
            
            <div class="divider"></div>
            
            <div class="features">
                <div class="feature">
                    <div class="feature-icon">📊</div>
                    <div class="feature-text">Track Spending</div>
                </div>
                <div class="feature">
                    <div class="feature-icon">⏸️</div>
                    <div class="feature-text">Pause Anytime</div>
                </div>
                <div class="feature">
                    <div class="feature-icon">💰</div>
                    <div class="feature-text">Save Money</div>
                </div>
            </div>
            
            <div class="support">
                <div class="support-title">Need Help?</div>
                <p style="color: rgba(255,255,255,0.7); margin: 8px 0;">
                    Our team is here for you 24/7<br>
                    <a href="mailto:Clawdgood@gmail.com" class="support-email">Clawdgood@gmail.com</a>
                </p>
            </div>
        </div>
        
        <div class="footer">
            <p>You're receiving this because you signed up for Pausely.</p>
            <p>© 2024 Pausely. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
```

### 3. Configure Password Reset Email
**Template Type**: Reset Password
**Subject**: `Reset Your Pausely Password`

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reset Your Pausely Password</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
        
        body {
            margin: 0;
            padding: 0;
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #0F0F0F 0%, #1A1A2E 50%, #16213E 100%);
            color: #FFFFFF;
        }
        
        .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 40px 20px;
        }
        
        .header {
            text-align: center;
            padding: 40px 0;
        }
        
        .logo {
            font-size: 42px;
            font-weight: 700;
            background: linear-gradient(135deg, #8B5CF6 0%, #EC4899 50%, #F59E0B 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 10px;
        }
        
        .card {
            background: rgba(255, 255, 255, 0.05);
            backdrop-filter: blur(20px);
            border-radius: 24px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            padding: 48px;
            margin: 32px 0;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
        }
        
        .title {
            font-size: 28px;
            font-weight: 700;
            margin-bottom: 16px;
            text-align: center;
        }
        
        .subtitle {
            font-size: 16px;
            color: rgba(255, 255, 255, 0.7);
            line-height: 1.6;
            text-align: center;
            margin-bottom: 32px;
        }
        
        .warning {
            background: rgba(239, 68, 68, 0.1);
            border: 1px solid rgba(239, 68, 68, 0.3);
            border-radius: 12px;
            padding: 16px;
            margin: 24px 0;
            text-align: center;
            color: rgba(255, 255, 255, 0.8);
            font-size: 14px;
        }
        
        .button-container {
            text-align: center;
            margin: 32px 0;
        }
        
        .button {
            display: inline-block;
            padding: 18px 48px;
            background: linear-gradient(135deg, #8B5CF6 0%, #EC4899 100%);
            color: #FFFFFF;
            text-decoration: none;
            border-radius: 14px;
            font-weight: 600;
            font-size: 16px;
            box-shadow: 0 10px 40px -10px rgba(139, 92, 246, 0.5);
        }
        
        .divider {
            height: 1px;
            background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
            margin: 32px 0;
        }
        
        .footer {
            text-align: center;
            padding: 32px 0;
            color: rgba(255, 255, 255, 0.4);
            font-size: 14px;
        }
        
        .support {
            background: rgba(245, 158, 11, 0.1);
            border: 1px solid rgba(245, 158, 11, 0.3);
            border-radius: 12px;
            padding: 20px;
            margin-top: 32px;
            text-align: center;
        }
        
        .support-title {
            color: #F59E0B;
            font-weight: 600;
            margin-bottom: 8px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">Pausely</div>
        </div>
        
        <div class="card">
            <h1 class="title">Password Reset</h1>
            <p class="subtitle">
                We received a request to reset your Pausely password. 
                Click the button below to create a new password.
            </p>
            
            <div class="warning">
                ⚠️ This link expires in 1 hour for your security
            </div>
            
            <div class="button-container">
                <a href="{{ .ConfirmationURL }}" class="button">Reset Password</a>
            </div>
            
            <div class="divider"></div>
            
            <p style="color: rgba(255,255,255,0.6); font-size: 14px; text-align: center;">
                Didn't request this? You can safely ignore this email. 
                Your password will remain unchanged.
            </p>
            
            <div class="support">
                <div class="support-title">Need Help?</div>
                <p style="color: rgba(255,255,255,0.7); margin: 8px 0;">
                    Contact us at <a href="mailto:Clawdgood@gmail.com" style="color: #FFFFFF;">Clawdgood@gmail.com</a>
                </p>
            </div>
        </div>
        
        <div class="footer">
            <p>© 2024 Pausely. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
```

### 4. Configure Magic Link Email (Optional)
**Template Type**: Magic Link
**Subject**: `Your Magic Link to Pausely`

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Your Magic Link to Pausely</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
        
        body {
            margin: 0;
            padding: 0;
            font-family: 'Inter', sans-serif;
            background: linear-gradient(135deg, #0F0F0F 0%, #1A1A2E 100%);
            color: #FFFFFF;
        }
        
        .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 40px 20px;
        }
        
        .logo {
            font-size: 42px;
            font-weight: 700;
            background: linear-gradient(135deg, #8B5CF6, #EC4899, #F59E0B);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            text-align: center;
            margin-bottom: 32px;
        }
        
        .card {
            background: rgba(255, 255, 255, 0.05);
            border-radius: 24px;
            padding: 48px;
            border: 1px solid rgba(255, 255, 255, 0.1);
        }
        
        .title {
            font-size: 28px;
            font-weight: 700;
            margin-bottom: 16px;
            text-align: center;
        }
        
        .subtitle {
            font-size: 16px;
            color: rgba(255, 255, 255, 0.7);
            text-align: center;
            margin-bottom: 32px;
        }
        
        .button-container {
            text-align: center;
            margin: 32px 0;
        }
        
        .button {
            display: inline-block;
            padding: 18px 48px;
            background: linear-gradient(135deg, #8B5CF6 0%, #EC4899 100%);
            color: #FFFFFF;
            text-decoration: none;
            border-radius: 14px;
            font-weight: 600;
            font-size: 16px;
        }
        
        .footer {
            text-align: center;
            padding: 32px 0;
            color: rgba(255, 255, 255, 0.4);
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">Pausely</div>
        
        <div class="card">
            <h1 class="title">Your Magic Link</h1>
            <p class="subtitle">
                Click the button below to sign in to your Pausely account instantly. 
                No password needed!
            </p>
            
            <div class="button-container">
                <a href="{{ .ConfirmationURL }}" class="button">Sign In to Pausely</a>
            </div>
        </div>
        
        <div class="footer">
            <p>This link expires in 1 hour. Need help? Contact us at Clawdgood@gmail.com</p>
            <p>© 2024 Pausely. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
```

### 5. Configure URL Settings (CRITICAL!)
Go to **Authentication** → **URL Configuration**

**Site URL**: `pausely://auth/callback`

**Redirect URLs** (add these):
```
pausely://auth/confirm
pausely://auth/reset-password
pausely://auth/callback
```

### 6. Configure SMTP (Send Emails from YOUR Domain)
Go to **Authentication** → **SMTP Settings**

**Sender Email**: `noreply@pausely.app`
**Sender Name**: `Pausely`

For now, you can use Supabase's default email provider. To use your own:
- Set up SendGrid, AWS SES, or Mailgun
- Enter SMTP credentials in Supabase dashboard

## Testing the Flow

1. **Sign up** in the app
2. **Check your email** (including spam folder)
3. **Click the confirmation button** in the email
4. **App should open** and log you in automatically

## Support Contact

If users don't receive emails, they can contact:
- **Email**: Clawdgood@gmail.com
- **In-app support**: Profile → Support

## Troubleshooting

**Emails going to spam?**
- Set up custom SMTP with your domain
- Add SPF/DKIM records
- Warm up your email reputation

**Deep links not working?**
- Verify URL scheme in Info.plist
- Check Redirect URLs in Supabase
- Test on real device (simulator has issues with deep links)

**Still having issues?**
Contact support at Clawdgood@gmail.com
