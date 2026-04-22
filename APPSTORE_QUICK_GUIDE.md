# Quick Setup Guide

## Login
1. Go to https://appstoreconnect.apple.com
2. Sign in with Apple Developer account

## Navigate
1. Click "My Apps"
2. Select "Pausely" (or create new app with bundle ID: com.pausely.app.Pausely)
3. Click "Subscriptions" in left sidebar

## Create Group
Click "Create Subscription Group"
- Reference Name: `Pausely Pro Subscriptions`
- Display Name: `Pausely Pro`

## Create Monthly Product
Click "Create Subscription"
1. **Product Information**
   - Reference Name: `Monthly Pro`
   - Product ID: `com.pausely.premium.monthly` ⚠️ EXACT MATCH REQUIRED
   - Display Name: `Pausely Pro Monthly`
   - Description: `Unlimited subscriptions + AI features`

2. **Subscription Details**
   - Duration: `1 Month`
   - Group: `Pausely Pro Subscriptions`
   - Group Level: `2`

3. **Pricing**
   - Price: `$7.99` (Tier 60)
   - Select all territories

4. **Introductory Offer**
   - Type: `Free Trial`
   - Duration: `1 Week`
   - Click "Save"

## Create Annual Product
Click "Create Subscription"
1. **Product Information**
   - Reference Name: `Annual Pro`
   - Product ID: `com.pausely.premium.annual` ⚠️ EXACT MATCH REQUIRED
   - Display Name: `Pausely Pro Annual`
   - Description: `Save 27% with annual billing`

2. **Subscription Details**
   - Duration: `1 Year`
   - Group: `Pausely Pro Subscriptions`
   - Group Level: `1`

3. **Pricing**
   - Price: `$69.99` (Tier 85)
   - Select all territories

4. **Introductory Offer**
   - Type: `Free Trial`
   - Duration: `1 Week`
   - Click "Save"

## Submit for Review
1. Both products should show "Ready to Submit"
2. Add review screenshots
3. Submit with app binary
