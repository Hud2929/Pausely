# 🍋 LemonSqueezy Discount Setup (Visual Guide)

## Create REFERRAL30 Discount

### Step 1: Navigate to Discounts
```
Dashboard
└── Products
    └── Discounts ← Click here
```

### Step 2: Create New Discount
Click **"Create Discount"** button

### Step 3: Fill Form

```
┌─────────────────────────────────────────┐
│  Create Discount                        │
├─────────────────────────────────────────┤
│                                         │
│  Name:                                  │
│  ┌─────────────────────────────────┐   │
│  │ Referral 30% Off                │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Code:                                  │
│  ┌─────────────────────────────────┐   │
│  │ REFERRAL30                      │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Amount:                                │
│  ┌─────────────────────────────────┐   │
│  │ 30                              │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Type:                                  │
│  ○ Fixed amount                       │
│  ● Percentage ✓                       │
│                                         │
│  Apply to:                              │
│  ☑ Monthly Subscription               │
│  ☑ Annual Subscription                │
│                                         │
│  [         Save Discount         ]     │
│                                         │
└─────────────────────────────────────────┘
```

### Step 4: Verify
You should see:
```
Discounts
├── Referral 30% Off
│   ├── Code: REFERRAL30
│   ├── Amount: 30%
│   └── Status: Active ✓
```

## Configure Webhook

### Step 1: Go to Settings
```
Dashboard
└── Settings ← Click here
    └── Webhooks
```

### Step 2: Add Webhook
Click **"Add Webhook"**

### Step 3: Fill Form
```
┌─────────────────────────────────────────┐
│  Webhook URL                            │
│  ┌─────────────────────────────────┐   │
│  │ https://YOUR_PROJECT.supabase.co│   │
│  │ /functions/v1/lemon-squeezy-    │   │
│  │ webhook                         │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Events:                                │
│  ☑ order_created                      │
│  ☑ order_paid                         │
│  ☑ subscription_created               │
│  ☑ subscription_cancelled             │
│  ☑ subscription_expired               │
│                                         │
│  [          Save Webhook          ]    │
└─────────────────────────────────────────┘
```

## Test Discount

### Test URL
```
https://YOUR_STORE.lemonsqueezy.com/checkout/buy/YOUR_VARIANT_ID
?checkout[discount_code]=REFERRAL30
&checkout[email]=test@example.com
```

### Expected Result
- ✅ Original price shown with strikethrough
- ✅ 30% discount applied
- ✅ Final price shown

## 🎉 Done!

Your referral discount is now active and will automatically apply when users use a referral code!

## Troubleshooting

### Discount not working?
1. Check code is exactly `REFERRAL30`
2. Check discount is "Active"
3. Check it applies to correct variants
4. Try test URL above

### Webhook not firing?
1. Check URL is correct
2. Check events are selected
3. Check Supabase function deployed
4. View logs in Supabase Dashboard
