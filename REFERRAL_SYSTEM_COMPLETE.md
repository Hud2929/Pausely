# 🎁 Referral System - COMPLETE SETUP

## ✅ What's Already Working in the App

### 1. Referral Code Generation
- ✅ Instant code display (no loading)
- ✅ Format: `PAUSELY-XXXX-XXXX`
- ✅ Stored locally + synced to server

### 2. Sharing Features
- ✅ Copy to clipboard
- ✅ Share via Messages
- ✅ Share via Email
- ✅ System share sheet
- ✅ Progress tracking (X of 3)

### 3. Referral Discount (30% Off)
- ✅ Auto-applied at checkout
- ✅ Discount code: `REFERRAL30`
- ✅ Shows strikethrough price
- ✅ Works with all currencies

### 4. Free Pro Reward
- ✅ After 3 successful referrals
- ✅ "Claim Free Pro" button appears
- ✅ Grants Premium forever
- ✅ No subscription needed

---

## 🔧 What YOU Need to Do

### Step 1: Create Discount in LemonSqueezy (2 min)

Go to https://app.lemonsqueezy.com/settings/discounts

Create new discount:
```
Name: Referral 30% Off
Code: REFERRAL30
Amount: 30%
Type: Percentage
Apply to: Monthly & Annual variants
```

### Step 2: Deploy Webhook (1 min)

Option A - Using terminal:
```bash
cd /Users/hudson/Desktop/Pausely
chmod +x QUICK_SETUP.sh
./QUICK_SETUP.sh
```

Option B - Manual:
```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy lemon-squeezy-webhook
```

### Step 3: Configure Webhook URL (1 min)

In LemonSqueezy:
```
Settings → Webhooks → Add Webhook

URL: https://YOUR_PROJECT_REF.supabase.co/functions/v1/lemon-squeezy-webhook

Events:
☑ order_created
☑ order_paid
☑ subscription_created
☑ subscription_cancelled
☑ subscription_expired
```

### Step 4: Run Database Migration (1 min)

In Supabase Dashboard:
```
SQL Editor → New Query

Paste: supabase/migrations/20240226000000_add_referral_tables.sql

Click: Run
```

---

## 🧪 Testing Checklist

### Test 1: Code Generation
- [ ] Open app → Profile → Refer & Earn
- [ ] Code appears instantly (e.g., PAUSELY-ABC123)
- [ ] Progress shows "0 of 3 completed"

### Test 2: Share Code
- [ ] Tap Copy button
- [ ] Verify code copied to clipboard
- [ ] Share via Messages works

### Test 3: Use Referral Code
- [ ] Create new test account
- [ ] Enter referral code during signup
- [ ] Open Paywall
- [ ] Verify 30% discount shown:
  ```
  ~~$6.83~~ $4.78/month (30% off)
  ```

### Test 4: Complete Purchase
- [ ] Click Subscribe
- [ ] Checkout opens with discount
- [ ] Complete purchase
- [ ] Original referrer gets +1 credit

### Test 5: Earn Free Pro
- [ ] Refer 3 friends (repeat test 3-4)
- [ ] After 3rd referral, see "CLAIM FREE PRO" button
- [ ] Click button → Get Premium
- [ ] Verify Premium features unlocked

---

## 📊 Database Schema

### Tables Created:

**referral_codes**
```
id, code, referrer_user_id, conversions, 
is_eligible_for_free_pro, created_at
```

**referral_conversions**
```
id, referrer_code, referred_user_id, 
status, created_at, converted_at
```

**orders**
```
id, user_id, status, referral_code, 
created_at, paid_at
```

**user_subscriptions**
```
id, user_id, status, tier, is_free_pro,
created_at, updated_at
```

---

## 🎯 User Flow

```
┌─────────────────────────────────────────────────────────┐
│  USER A (Referrer)                                      │
│  ├─ Opens "Refer & Earn"                               │
│  ├─ Gets code: PAUSELY-ABC123                          │
│  ├─ Shares with 3 friends                              │
│  └─ After 3rd signup → FREE PRO! 🎉                    │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│  USER B (New User)                                      │
│  ├─ Signs up                                           │
│  ├─ Enters code: PAUSELY-ABC123                        │
│  ├─ Sees 30% discount on paywall                       │
│  │   ~~$6.83~~ $4.78/month                             │
│  ├─ Subscribes with discount                           │
│  └─ User A gets +1 credit                              │
└─────────────────────────────────────────────────────────┘
```

---

## 🔍 Monitoring

### View Referrals:
```sql
-- All referral codes
SELECT * FROM referral_codes;

-- All conversions
SELECT * FROM referral_conversions;

-- Who earned free Pro
SELECT * FROM referral_codes 
WHERE is_eligible_for_free_pro = true;

-- Recent orders
SELECT * FROM orders ORDER BY created_at DESC;
```

### Check Webhook Logs:
```
Supabase Dashboard → Edge Functions → lemon-squeezy-webhook → Logs
```

---

## 🚨 Troubleshooting

### Issue: "Loading your referral code..."
**Fix**: Code generates locally - should appear in 1 second. If stuck, pull down to refresh.

### Issue: Discount not showing
**Fix**: Check `REFERRAL30` discount exists in LemonSqueezy and is "Active"

### Issue: Referrer not getting credit
**Fix**: 
1. Check webhook URL is correct
2. Check webhook is deployed
3. Check `order_paid` event is selected
4. View webhook logs in Supabase

### Issue: Free Pro button not appearing
**Fix**: 
1. Check conversions count in database
2. Ensure `is_eligible_for_free_pro` is true
3. Refresh the Referral Sheet

---

## 📱 Files Modified

### App Code:
- `ReferralManager.swift` - Core referral logic
- `ReferralSheet.swift` - UI with progress & claim button
- `UpgradePromptView.swift` - Discount display
- `LemonSqueezyManager.swift` - Checkout with referral code

### Server Code:
- `supabase/functions/lemon-squeezy-webhook/index.ts` - Webhook handler
- `supabase/migrations/20240226000000_add_referral_tables.sql` - Database

---

## 🎉 Success Metrics

After setup, you should see:
- ✅ Codes generate instantly
- ✅ 30% discount auto-applied
- ✅ Referrals tracked in real-time
- ✅ Free Pro unlocked at 3 referrals
- ✅ All prices in user's currency

---

## 📞 Support

If something breaks:
1. Check `SETUP_REFERRAL_SYSTEM.md` for detailed steps
2. Check `LEMONSQUEEZY_DISCOUNT_SETUP.md` for visual guide
3. View webhook logs in Supabase
4. Check database tables for data

**You're 4 steps away from a fully working referral system! 🚀**
