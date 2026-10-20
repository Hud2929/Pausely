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
   - Description: `Unlimited subscriptions and all Pro features`

2. **Subscription Details**
   - Duration: `1 Month`
   - Group: `Pausely Pro Subscriptions`
   - Group Level: `2`

3. **Pricing**
   - Price: `$4.99` (US base price; run `asc subscriptions pricing equalize --base-price 4.99` for all other countries)
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
   - Description: `Best value with yearly billing`

2. **Subscription Details**
   - Duration: `1 Year`
   - Group: `Pausely Pro Subscriptions`
   - Group Level: `1`

3. **Pricing**
   - Price: `$29.99` (US base price; run `asc subscriptions pricing equalize --base-price 29.99`)
   - Select all territories

4. **Introductory Offer**
   - Type: `Free Trial`
   - Duration: `1 Week`
   - Click "Save"

## Submit for Review
1. Both products should show "Ready to Submit"
2. Add review screenshots
3. Submit with app binary
