# StoreKit Setup Guide for Pausely

This guide will help you configure StoreKit in-app purchases for Pausely in App Store Connect.

## Current Configuration

Your app is already configured with these product IDs (in `StoreKitConfig.swift`):

| Product ID | Type | Purpose |
|------------|------|---------|
| `com.pausely.premium.monthly` | Auto-Renewable Subscription | Monthly Pro ($7.99/month) |
| `com.pausely.premium.annual` | Auto-Renewable Subscription | Annual Pro ($69.99/year) |

## Prerequisites

1. Apple Developer Account ($99/year)
2. App registered in App Store Connect
3. Paid Applications Agreement signed in App Store Connect
4. Banking and tax information completed

---

## Step 1: Configure App Store Connect

### 1.1 Sign Required Agreements

1. Go to https://appstoreconnect.apple.com
2. Click **Agreements, Tax, and Banking**
3. Sign the **Paid Applications Agreement**
4. Complete **Bank Information** and **Tax Forms**

### 1.2 Create Subscription Group

1. Go to **My Apps** → Select **Pausely**
2. Click **Subscriptions** in the left sidebar
3. Click **Create Subscription Group**
4. **Reference Name:** `Pausely Pro Subscriptions`
5. **Product ID:** `com.pausely.premium`
6. Click **Create**

### 1.3 Create Monthly Subscription

1. Click **Create Subscription**
2. **Reference Name:** `Monthly Pro`
3. **Product ID:** `com.pausely.premium.monthly`
4. Click **Create**

**Subscription Details:**
- **Subscription Level:** 2 (lower number = higher priority)
- **Status:** Ready to Submit
- **Subscription Duration:** 1 Month
- **Free Trial:** 7 Days (optional but recommended)

**Pricing:**
- **Price:** $7.99 USD
- Configure prices for other regions

**Localization (English US):**
- **Display Name:** `Pausely Pro Monthly`
- **Description:** `Unlimited subscriptions + AI features`

**App Store Promotional Image:**
- Upload a screenshot showing premium features
- Size: 1024x1024px (can be reduced)

### 1.4 Create Annual Subscription

1. Click **Create Subscription**
2. **Reference Name:** `Annual Pro`
3. **Product ID:** `com.pausely.premium.annual`
4. Click **Create**

**Subscription Details:**
- **Subscription Level:** 1 (higher priority than monthly)
- **Status:** Ready to Submit
- **Subscription Duration:** 1 Year
- **Free Trial:** 7 Days (optional but recommended)

**Pricing:**
- **Price:** $69.99 USD (~27% savings vs monthly)
- Configure prices for other regions

**Localization (English US):**
- **Display Name:** `Pausely Pro Annual`
- **Description:** `Save 27% with annual billing`

---

## Step 2: Configure Xcode

### 2.1 Add StoreKit Configuration File

A StoreKit configuration file has been created at:
- `Pausely/Configuration.storekit`

**To add it to your Xcode project:**

1. Open `Pausely.xcodeproj` in Xcode
2. Right-click on the project folder in the navigator
3. Select **Add Files to "Pausely"...**
4. Select `Configuration.storekit`
5. Make sure **"Copy items if needed"** is checked
6. Click **Add**

### 2.2 Configure StoreKit for Testing

1. In Xcode, go to **Product** → **Scheme** → **Edit Scheme...**
2. Select **Run** in the left sidebar
3. Click **Options** tab
4. Under **StoreKit Configuration**, select `Configuration.storekit`
5. Close the scheme editor

### 2.3 Update App Capabilities

1. Select the **Pausely** target in Xcode
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **In-App Purchase**

### 2.4 Add App ID Configuration

1. Go to https://developer.apple.com/account/resources/identifiers/list
2. Find your App ID (e.g., `com.pausely.app`)
3. Click on it
4. Make sure **In-App Purchase** is enabled
5. Click **Save**

---

## Step 3: Testing StoreKit

### 3.1 Local Testing (Xcode)

The StoreKit configuration file allows you to test purchases without App Store Connect:

1. Run the app in Xcode simulator or device
2. Navigate to the upgrade/paywall screen
3. Tap on a subscription option
4. The StoreKit test interface will appear
5. Complete the test purchase

### 3.2 Sandbox Testing

To test with real App Store Connect products:

1. Go to https://appstoreconnect.apple.com
2. Click **Users and Access**
3. Click **Sandbox Testers**
4. Click **+** to add a new sandbox tester
5. Fill in the required information
6. Use this account on your test device

**On your test device:**
1. Sign out of your regular Apple ID (Settings → Apple ID → Sign Out)
2. Run the Pausely app
3. Attempt a purchase
4. Sign in with the sandbox tester credentials when prompted

---

## Step 4: Verify Integration

### 4.1 Check Product Loading

Open the paywall and verify:
- Products load correctly
- Prices display as configured
- Trial information shows (if enabled)

### 4.2 Test Purchase Flow

1. Tap **Start Free Trial** or **Subscribe**
2. Complete the purchase
3. Verify the app updates to Pro status
4. Check that subscription appears in Settings

### 4.3 Test Restore Purchases

1. Delete and reinstall the app
2. Tap **Restore Purchases**
3. Verify subscription is restored

---

## Troubleshooting

### "Product not found" error

- Verify product IDs match exactly (case-sensitive)
- Check that products are "Ready to Submit" in App Store Connect
- Wait 15-30 minutes after creating products in App Store Connect

### "Cannot connect to iTunes Store"

- Ensure you're testing on a real device or simulator with proper configuration
- Check internet connection
- Verify sandbox tester account is set up correctly

### Products not loading in production

- Products must be approved by Apple review before they work in production
- Ensure Paid Applications Agreement is signed
- Check that app binary includes In-App Purchase capability

---

## App Store Submission Checklist

Before submitting to App Store review:

- [ ] Paid Applications Agreement signed
- [ ] Banking and tax information complete
- [ ] Subscriptions created in App Store Connect
- [ ] Products marked as "Ready to Submit"
- [ ] Screenshots uploaded for each subscription
- [ ] In-App Purchase capability enabled in Xcode
- [ ] Tested with sandbox account
- [ ] Restore Purchases functionality tested

---

## Code References

### Current Implementation

- **Configuration:** `StoreKitConfig.swift`
- **Manager:** `RevolutionaryStoreKitManager.swift`
- **UI:** `RevolutionaryStoreKitView.swift`

### Product IDs (Do Not Change)

```swift
case monthlyPro = "com.pausely.premium.monthly"
case annualPro = "com.pausely.premium.annual"
```

If you change these in App Store Connect, you MUST update the code to match.

---

## Support

For StoreKit issues:
1. Check Apple Developer Documentation: https://developer.apple.com/documentation/storekit
2. Review StoreKit testing guide: https://developer.apple.com/documentation/storekit/original_apis_for_in-app_purchase/testing_in-app_purchases
3. Verify App Store Connect status: https://appstoreconnect.apple.com
