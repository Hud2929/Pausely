# 🎁 Referral System Setup Guide

## Step 1: Create Discount Code in LemonSqueezy (2 minutes)

1. Go to https://app.lemonsqueezy.com/
2. Click **Discounts** in the sidebar
3. Click **Create Discount**
4. Fill in:
   - **Name**: Referral 30% Off
   - **Code**: `REFERRAL30`
   - **Amount**: 30%
   - **Type**: Percentage
   - **Apply to**: Both Monthly & Annual variants
5. Click **Save**

## Step 2: Deploy Webhook to Supabase (1 minute)

### Option A: Using Supabase CLI
```bash
# Install Supabase CLI if not already installed
npm install -g supabase

# Login
supabase login

# Link your project
supabase link --project-ref YOUR_PROJECT_REF

# Deploy the webhook
supabase functions deploy lemon-squeezy-webhook
```

### Option B: Manual Deploy
1. Go to https://app.supabase.com
2. Select your project
3. Go to **Edge Functions**
4. Click **Deploy a new function**
5. Name: `lemon-squeezy-webhook`
6. Paste the code from `supabase/functions/lemon-squeezy-webhook/index.ts`
7. Click **Deploy**

## Step 3: Configure LemonSqueezy Webhook (2 minutes)

1. In LemonSqueezy Dashboard → **Settings** → **Webhooks**
2. Click **Add Webhook**
3. **URL**: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/lemon-squeezy-webhook`
4. **Events to send**:
   - ✅ order_created
   - ✅ order_paid
   - ✅ subscription_created
   - ✅ subscription_cancelled
   - ✅ subscription_expired
5. Click **Save**

## Step 4: Set Environment Variables (1 minute)

In Supabase Dashboard:
1. Go to **Settings** → **API**
2. Copy your `service_role_key`
3. Go to Edge Functions → **lemon-squeezy-webhook** → **Settings**
4. Add secrets:
   - `SUPABASE_URL`: Your Supabase URL
   - `SUPABASE_SERVICE_ROLE_KEY`: Your service role key

## Step 5: Test the System

### Test 1: Create Referral Code
```
1. Open app → Profile → Refer & Earn
2. Your code should appear instantly (e.g., PAUSELY-ABC123)
```

### Test 2: Use Referral Code
```
1. Sign up with a new account
2. Enter referral code during onboarding
3. Open Paywall
4. Should see: ~~$6.83~~ $4.78/month (30% off)
```

### Test 3: Complete Purchase
```
1. Click Subscribe
2. Checkout opens with discount applied
3. Complete test purchase
4. Original referrer gets +1 credit
```

### Test 4: Earn Free Pro
```
1. Refer 3 friends who all subscribe
2. After 3rd referral, see "CLAIM FREE PRO" button
3. Click it → Get Premium forever
```

## 🎯 How It Works

### User Journey:
```
User A (Referrer)
├─ Gets code: PAUSELY-ABC123
├─ Shares with friends
└─ After 3 friends subscribe → FREE PRO

User B (New User)
├─ Enters code: PAUSELY-ABC123
├─ Sees 30% discount on paywall
├─ Pays with discount
└─ User A gets +1 referral credit
```

### Database Tables Created:
- `referral_codes` - Stores codes and conversion counts
- `referral_conversions` - Tracks who referred who
- `orders` - Pending/paid orders
- `user_subscriptions` - Active subscriptions

## 🚨 Troubleshooting

### "Loading your referral code..." stuck?
- Code is generated locally, should appear in 1 second
- If not, pull down to refresh

### Discount not showing?
- Check `REFERRAL30` discount exists in LemonSqueezy
- Verify user entered referral code during signup

### Referrer not getting credit?
- Check webhook is deployed
- Check webhook URL is correct
- Check events are selected (order_paid especially)

## 📊 Monitoring

### View Referrals in Supabase:
```sql
-- See all referrals
SELECT * FROM referral_codes;

-- See conversions
SELECT * FROM referral_conversions;

-- See who earned free Pro
SELECT * FROM referral_codes WHERE is_eligible_for_free_pro = true;
```

### Webhook Logs:
1. Supabase Dashboard → Edge Functions
2. Click **lemon-squeezy-webhook**
3. Click **Logs** tab

## 🎉 You're Done!

Your referral system is now:
- ✅ Giving 30% discounts automatically
- ✅ Tracking referrals
- ✅ Awarding Free Pro after 3 referrals
- ✅ Working globally with all currencies

**Questions?** Check the logs in Supabase for real-time debugging.
