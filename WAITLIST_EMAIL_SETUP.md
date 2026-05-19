# Waitlist Email Setup & Testing

## What Was Built

1. **Waitlist landing page** (`pausely.pro/waitlist.html`) with:
   - Real Pausely app icon
   - Glass morphism design matching the app
   - Affiliate/influencer tracking via `?ref=CODE`
   - Calls edge function for signup + email

2. **Edge Function** (`supabase/functions/waitlist-signup/index.ts`) that:
   - Inserts email into the `waitlist` table
   - Sends a branded Pausely welcome email
   - **Auto-selects the best provider**: AWS SES (high volume) > Resend (easy setup)

3. **Branded email template** with Pausely gold/purple design

---

## Email Provider Options

| Provider | Free Tier | Paid Pricing | Best For |
|----------|-----------|--------------|----------|
| **AWS SES** | 62,000 emails/month (from EC2) | **$0.10 per 1,000 emails** | High volume, lowest cost |
| **Resend** | 100 emails/day | $20/month for 50,000 | Easy setup, great dev experience |
| **SendGrid** | 100 emails/day | $15/month for 15,000 | Enterprise features |

**For viral/high-volume launches, AWS SES is the clear winner.**
- 100,000 emails = $10 with SES vs $40+ with Resend
- 1,000,000 emails = $100 with SES vs $400+ with Resend

---

## Option 1: AWS SES (Recommended for High Volume)

### 1. Create AWS Account
Go to [aws.amazon.com](https://aws.amazon.com) and sign up (free tier available).

### 2. Verify Your Domain
1. Go to **Amazon SES** console
2. Click **Configuration** → **Verified identities**
3. Click **Create identity** → **Domain**
4. Enter `pausely.app`
5. Add the DNS records (CNAME for DKIM) to your domain registrar
6. Wait for verification status = "Verified" (usually within minutes)

### 3. Request Production Access (Sandbox Removal)
By default, AWS SES starts in **sandbox mode** — you can only send to verified emails.

1. In SES console, go to **Account dashboard**
2. Click **Request production access**
3. Select **Transactional** as use case
4. Enter:
   - Website URL: `https://pausely.app`
   - Use case description: "Welcome emails for users who join our iOS app waitlist. We collect email via a landing page and send a single confirmation email."
5. Submit request (approval usually within 24 hours)

**For immediate testing**, add your email as a verified identity:
- Configuration → Verified identities → Create identity → Email address
- Verify via the email AWS sends you

### 4. Create IAM User with SES Permissions
1. Go to **IAM** → **Users** → **Create user**
2. Name: `pausely-ses-sender`
3. Attach policy: `AmazonSESFullAccess`
4. Create **Access key** (programmatic access)
5. Save the `Access key ID` and `Secret access key`

### 5. Deploy Edge Function with AWS Credentials

```bash
# Set AWS credentials as Supabase secrets
supabase secrets set AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXX
supabase secrets set AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
supabase secrets set AWS_REGION=us-east-1
supabase secrets set SES_FROM_EMAIL=hello@pausely.app
supabase secrets set SES_REPLY_TO=support@pausely.app

# Deploy
supabase functions deploy waitlist-signup
```

The edge function will **automatically detect AWS credentials** and use SES. If no AWS credentials are found, it falls back to Resend.

---

## Option 2: Resend (Easier Setup, Lower Volume)

### 1. Sign Up for Resend
Go to [resend.com](https://resend.com) and create a free account.

### 2. Add Your Domain
1. Go to **Domains** → **Add Domain**
2. Enter `pausely.app`
3. Add DNS records to your domain registrar
4. Wait for verification

**For quick testing**, use the default sender: `onboarding@resend.dev`

### 3. Get API Key
1. Go to **API Keys** → **Create API Key**
2. Name it `Pausely Waitlist`
3. Copy the key (starts with `re_`)

### 4. Deploy

```bash
supabase secrets set RESEND_API_KEY=re_xxxxxxxxxxxx
supabase functions deploy waitlist-signup
```

---

## Update waitlist.html

Edit `pausely.pro/waitlist.html` and replace:
```javascript
const SUPABASE_URL = 'YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

With your real values from Supabase dashboard (Settings → API).

---

## Testing

### Quick Curl Test

```bash
curl -X POST 'https://YOUR-PROJECT.functions.supabase.co/waitlist-signup' \
  -H 'Content-Type: application/json' \
  -d '{"email": "test@example.com", "source": "test"}'
```

Expected response:
```json
{"success": true, "message": "Welcome to the waitlist! Check your email.", "email_sent": true, "provider": "aws_ses"}
```

### Local Test (No Real Emails)

```bash
# Serve locally
supabase functions serve waitlist-signup

# In another terminal, test
curl -X POST 'http://localhost:54321/functions/v1/waitlist-signup' \
  -H 'Content-Type: application/json' \
  -d '{"email": "test@example.com"}'
```

Without credentials, you'll see:
```
[DEBUG MODE] Would send welcome email to: test@example.com
[DEBUG MODE] Set AWS SES credentials OR RESEND_API_KEY to send real emails
```

---

## Cost Calculator

| Daily Signups | Monthly Emails | AWS SES Cost | Resend Cost |
|--------------|----------------|--------------|-------------|
| 100 | 3,000 | $0.30 | Free (within 100/day) |
| 500 | 15,000 | $1.50 | $20 plan |
| 1,000 | 30,000 | $3.00 | $20 plan |
| 5,000 | 150,000 | $15.00 | ~$40 |
| 10,000 | 300,000 | $30.00 | ~$100 |
| 50,000 | 1,500,000 | $150.00 | ~$580 |

---

## Troubleshooting

### "provider": "none" in response
- No email credentials configured. Set either AWS SES or Resend secrets.

### Emails not sending with AWS SES
- Check your SES sandbox status (must be removed for production)
- Verify domain identity is "Verified"
- Check IAM user has `AmazonSESFullAccess` policy
- Verify `SES_FROM_EMAIL` uses your verified domain

### Emails going to spam
- Complete domain verification (DKIM) in your email provider
- Add SPF, DKIM, and DMARC DNS records
- Use a recognizable sender name: `Pausely` not `no-reply`

### CORS errors
- Edge function handles CORS automatically
- Ensure you're calling the correct function URL

---

## Next Steps

1. **Add your friend as an affiliate:**
```sql
INSERT INTO affiliates (name, code, revenue_share_pct)
VALUES ('Your Friend Name', 'FRIENDCODE', 20.00);
```

2. **Give your friend their link:**
```
https://pausely.app/waitlist?ref=FRIENDCODE
```

3. **Track conversions** in Supabase or MissionControl

4. **Pay your friend** monthly based on `affiliate_conversions` data
