# App Store Connect - Subscription Products Setup
**For:** Pausely iOS App  
**Date:** March 5, 2026  
**Bundle ID:** com.pausely.app.Pausely

---

## Quick Setup Checklist

### Prerequisites
- [ ] Apple Developer Program membership ($99/year)
- [ ] App record created in App Store Connect
- [ ] Paid Apps agreement signed
- [ ] Tax and banking information complete

---

## Step 1: Sign Agreements

1. Go to **App Store Connect** → **Agreements, Tax, and Banking**
2. Sign **Paid Apps** agreement
3. Complete **Tax forms** (W-9 for US, W-8BEN for international)
4. Add **Banking information** for payouts

---

## Step 2: Create Subscription Group

### Group Details
```
Reference Name: Pausely Pro Subscriptions
Display Name: Pausely Pro
Group ID: com.pausely.premium
```

**To Create:**
1. App Store Connect → Your App → Subscriptions
2. Click **"Create Subscription Group"
3. Enter the details above
4. Click Create

---

## Step 3: Create Products

### Product 1: Monthly Pro

#### Product Information
```
Reference Name: Monthly Pro
Product ID: com.pausely.premium.monthly
Display Name: Pausely Pro Monthly
Description: Unlimited subscriptions + AI features
```

#### Subscription Details
```
Subscription Duration: 1 Month
Subscription Group: Pausely Pro Subscriptions
Group Level: 2 (lower priority than annual)
```

#### Pricing
```
Price: $7.99 USD (Tier 60)
```

#### Introductory Offer (Free Trial)
```
Offer Type: Free Trial
Duration: 1 Week
```

**Countries:** Enable all countries you want to sell in

---

### Product 2: Annual Pro

#### Product Information
```
Reference Name: Annual Pro
Product ID: com.pausely.premium.annual
Display Name: Pausely Pro Annual
Description: Save 27% with annual billing
```

#### Subscription Details
```
Subscription Duration: 1 Year
Subscription Group: Pausely Pro Subscriptions
Group Level: 1 (highest priority - shown first)
```

#### Pricing
```
Price: $69.99 USD (Tier 85)
```

#### Introductory Offer (Free Trial)
```
Offer Type: Free Trial
Duration: 1 Week
```

**Countries:** Enable all countries you want to sell in

---

## Step 4: Review Information

### Review Notes (Copy-Paste)
```
Subscription Features:
- Unlimited subscription tracking
- Smart pause functionality
- Cost per hour analysis
- AI financial advisor
- Subscription health score
- Price increase alerts
- Smart alternatives finder
- Renewal calendar
- Cancel/pause links
- Referral rewards

Users can manage subscriptions in Settings > Apple ID > Subscriptions
or at https://apps.apple.com/account/subscriptions

No free content is locked behind the paywall - all premium features
are additive to the free experience.
```

### Subscription Terms URL
```
https://www.pausely.app/terms
```

### Privacy Policy URL
```
https://www.pausely.app/privacy
```

---

## Step 5: Screenshot Requirements

### For Review (Required)
You need screenshots showing the paywall and subscription management:

1. **Paywall Screen** - Show pricing and features
2. **Subscription Management** - Show where users manage/cancel
3. **Feature Unlock** - Show premium feature access

**Specifications:**
- iPhone: 1290 x 2796 pixels (iPhone 14 Pro Max)
- iPad: 2048 x 2732 pixels (12.9" iPad Pro)
- Format: PNG or JPG

---

## Step 6: App Store Review Information

### App Review Information
```
First Name: [Your Name]
Last Name: [Your Last Name]
Email: [Your Email]
Phone: [Your Phone]
```

### Demo Account (Optional but Recommended)
```
Username: demo@pausely.app
Password: Demo123!
```

### Notes for Reviewer
```
This app helps users track and optimize their subscription spending.

FREE FEATURES:
- Track up to 5 subscriptions
- Basic cost analysis
- Manual usage tracking
- Referral program

PREMIUM FEATURES (Subscription):
- Unlimited subscriptions
- Smart pause suggestions
- AI financial insights
- Cost per hour calculation
- Alternative service recommendations

Subscription auto-renews unless cancelled 24 hours before renewal.
Users can cancel anytime in Settings > Apple ID > Subscriptions.

Test subscription purchases can be made using Sandbox accounts.
```

---

## Step 7: Sandbox Testing

### Create Sandbox Tester
1. App Store Connect → **Users and Access** → **Sandbox** → **Testers**
2. Click **"+"** to add tester
3. Fill in details:
   ```
   First Name: Test
   Last Name: User
   Email: testuser123@example.com
   Password: TestPass123!
   Country: United States
   App Store Country: United States
   ```
4. Click **Create**

### Test on Device
1. Sign out of regular App Store account on test device
2. Open Pausely app
3. Attempt purchase
4. Use sandbox credentials when prompted

---

## Pricing Tiers Reference

| Tier | USD | Description |
|------|-----|-------------|
| 60 | $7.99 | Monthly Pro |
| 85 | $69.99 | Annual Pro |

**Annual Discount:** 27% savings vs monthly
- Monthly: $7.99 × 12 = $83.88/year
- Annual: $69.99/year
- Savings: $28.89/year

---

## Promotional Offers (Optional)

You can create promotional offers for:
- Win-back campaigns (former subscribers)
- Special events (Black Friday, etc.)
- Referral rewards

### Example Promotional Offer
```
Offer Reference Name: Win Back - 50% Off
Product: Monthly Pro
Offer Type: Pay As You Go
Discount: 50%
Duration: 3 Months
```

---

## Localized Metadata (Recommended)

Create localized versions for top markets:

### English (Default)
```
Display Name: Pausely Pro
Description: Unlock unlimited subscriptions and AI features
```

### Spanish (es-MX)
```
Display Name: Pausely Pro
Description: Desbloquea suscripciones ilimitadas y funciones de IA
```

### French (fr-CA)
```
Display Name: Pausely Pro
Description: Débloquez des abonnements illimités et des fonctionnalités IA
```

### German (de-DE)
```
Display Name: Pausely Pro
Description: Schalten Sie unbegrenzte Abonnements und KI-Funktionen frei
```

---

## Submission Checklist

Before submitting for review:

### App Information
- [ ] App name finalized
- [ ] Subtitle (30 chars max)
- [ ] Description (localized)
- [ ] Keywords (100 chars max)
- [ ] Support URL
- [ ] Marketing URL

### Pricing & Availability
- [ ] Price: Free (with In-App Purchases)
- [ ] Availability: All countries or selected

### App Review
- [ ] Demo account provided (if needed)
- [ ] Review notes added
- [ ] Contact information complete

### Build
- [ ] Build uploaded via Xcode
- [ ] Build processed (no errors)
- [ ] Build selected for submission

### In-App Purchases
- [ ] Subscription group created
- [ ] Monthly product created
- [ ] Annual product created
- [ ] Products show "Ready to Submit"
- [ ] Prices set for all territories

---

## Troubleshooting

### Products Show "Missing Metadata"
- Add display name and description for all locales
- Add screenshot for review

### Products Show "Waiting for Review"
- This is normal - they review with the app

### Products Show "Approved" but not working
- Check that Product IDs match exactly (case-sensitive)
- Verify app is signed with correct provisioning profile

### Sandbox Purchase Fails
- Ensure device is logged out of real App Store
- Use sandbox tester credentials (not real Apple ID)
- Check that device has internet connection

---

## Revenue Sharing

### Standard Revenue Share
- Apple: 30%
- Developer: 70%

### Small Business Program (if eligible)
- Apple: 15%
- Developer: 85%

### Eligibility Requirements
- New to App Store OR
- Earned ≤ $1 million in previous calendar year

**Apply at:** App Store Connect → Agreements → Small Business Program

---

## Next Steps After Approval

1. **Monitor Sales** - App Store Connect → Analytics
2. **Respond to Reviews** - Engage with user feedback
3. **Track Churn** - Subscription retention metrics
4. **Optimize Pricing** - Test different price points
5. **Add Offers** - Promotional campaigns

---

## Support Resources

- **Apple Developer Documentation:** https://developer.apple.com/in-app-purchase/
- **App Store Connect Help:** https://help.apple.com/app-store-connect/
- **StoreKit Testing:** https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases

---

**Last Updated:** March 5, 2026  
**Document Version:** 1.0
