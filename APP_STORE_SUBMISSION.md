# Pausely - App Store Submission Guide

Complete guide for submitting Pausely to the Apple App Store.

---

## Table of Contents

1. [App Store Connect Setup](#1-app-store-connect-setup)
2. [Bundle ID Configuration](#2-bundle-id-configuration)
3. [Certificates & Provisioning Profiles](#3-certificates--provisioning-profiles)
4. [App Listing Details](#4-app-listing-details)
5. [Screenshots Specifications](#5-screenshots-specifications)
6. [Review Guidelines Compliance](#6-review-guidelines-compliance)
7. [Privacy Policy Requirements](#7-privacy-policy-requirements)
8. [App Rating](#8-app-rating)
9. [Submission Checklist](#9-submission-checklist)
10. [Post-Submission](#10-post-submission)

---

## 1. App Store Connect Setup

### 1.1 Create App Record

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **"Apps"** → **"+"** → **"New App"**
3. Fill in the details:
   - **Platform**: iOS
   - **Name**: Pausely
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: `com.pausely.app` (or your chosen bundle ID)
   - **SKU**: `pausely-001` (unique identifier, not visible to users)
   - **User Access**: Full Access

### 1.2 App Information

Navigate to **App Information** section:

| Field | Value |
|-------|-------|
| Name | Pausely |
| Subtitle | Smart Subscription Manager |
| Category (Primary) | Finance |
| Category (Secondary) | Productivity |
| Content Rights | Does not contain third-party content |
| License Agreement | Use Apple's standard agreement |

---

## 2. Bundle ID Configuration

### 2.1 Current Bundle ID Setup

The app currently uses the bundle ID defined in the Xcode project. Update if needed:

```
Recommended: com.pausely.app
Alternative: com.yourcompany.pausely
```

### 2.2 Xcode Configuration

1. Open `Pausely.xcodeproj` in Xcode
2. Select the project → **Pausely** target → **Signing & Capabilities**
3. Set **Bundle Identifier**: `com.pausely.app`
4. Set **Team**: Your Apple Developer Team
5. Enable **Automatically manage signing**

### 2.3 URL Schemes (Already Configured)

The app uses deep linking with URL scheme `pausely://`. This is configured in:
- **Info.plist** → `CFBundleURLTypes`

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.pausely.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>pausely</string>
        </array>
    </dict>
</array>
```

---

## 3. Certificates & Provisioning Profiles

### 3.1 Required Certificates

1. **Apple Development** - For development/testing
2. **Apple Distribution** - For App Store submission

### 3.2 Provisioning Profiles

Xcode will automatically manage these with **Automatic Signing**:

- **iOS App Development** - For running on devices during development
- **App Store** - For App Store submission

### 3.3 Manual Setup (if needed)

If automatic signing fails:

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources)
2. **Certificates** → Create new distribution certificate
3. **Identifiers** → Register App ID with bundle ID `com.pausely.app`
4. **Profiles** → Create App Store provisioning profile
5. Download and import into Xcode

### 3.4 Capabilities Required

The app requires these capabilities (enable in Signing & Capabilities):

- ✅ **In-App Purchase** (for Premium subscriptions)
- ✅ **Push Notifications** (optional, for renewal reminders)
- ✅ **Background Fetch** (optional, for background sync)

---

## 4. App Listing Details

### 4.1 App Name

**Pausely**

- Maximum 30 characters
- Must be unique on App Store
- If taken, try: "Pausely Manager" or "Pausely Subscriptions"

### 4.2 Subtitle

**Smart Subscription Manager**

- Maximum 30 characters
- Appears below app name on App Store

### 4.3 Description

```
Take control of your subscriptions with Pausely — the smartest way to track, manage, and save on your monthly recurring charges.

FEATURES:

📊 SUBSCRIPTION TRACKING
• Track all your subscriptions in one place
• Support for 50+ currencies with real-time exchange rates
• Smart URL parsing — just paste a link and we auto-detect the service
• 200+ popular services pre-configured with cancellation info

💰 SMART SAVINGS
• See your true cost-per-hour for each subscription
• Get pause recommendations based on your usage
• Discover hidden perks you already have access to
• Calculate potential savings from pausing unused services

⏸️ ONE-TAP PAUSE & CANCEL
• Direct links to cancel 200+ subscription services
• Step-by-step cancellation guides
• Difficulty ratings for each service
• Pause options where available

🔒 SECURE & PRIVATE
• Secure authentication with email or magic links
• Biometric login with Face ID / Touch ID
• All data encrypted and stored securely
• No sharing of personal data with third parties

🌍 MULTI-CURRENCY
• Track subscriptions in any currency
• Automatic conversion to your preferred currency
• Real-time exchange rate updates
• Perfect for international users

PREMIUM FEATURES:
Upgrade to Pausely Premium for unlimited subscriptions, advanced analytics, bank connection (coming soon), and priority support.

• Monthly: $7.99
• Annual: $69.99 (Save 27%)

Take a pause. Save more. Live better.

Questions? Visit pausely.app/support
```

### 4.4 Keywords (ASO)

```
subscription manager, track subscriptions, cancel subscriptions, subscription tracker, monthly expenses, budget manager, spending tracker, subscription organizer, pause subscriptions, money saver, recurring payments, bill tracker, netflix manager, spotify tracker, subscription reminder
```

- Maximum 100 characters
- Separate with commas, no spaces after commas
- No competitor app names

### 4.5 What's New (First Version)

```
🎉 Welcome to Pausely!

We're excited to launch the first version of your smart subscription manager.

What's included in v1.0:
• Track unlimited subscriptions (3 free, unlimited with Premium)
• Smart URL detection for 200+ services
• One-tap cancellation links
• Multi-currency support (50+ currencies)
• Cost-per-hour insights
• Pause recommendations
• Secure authentication with magic links
• Face ID / Touch ID support

Take control of your subscriptions today!
```

### 4.6 URLs

| URL Type | Value | Status |
|----------|-------|--------|
| **Support URL** | https://pausely.app/support | Required - Create before submission |
| **Marketing URL** | https://pausely.app | Optional but recommended |
| **Privacy Policy URL** | https://pausely.app/privacy | Required |

---

## 5. Screenshots Specifications

### 5.1 Required Devices

You must provide screenshots for these device sizes:

#### iPhone (Required)

| Device | Size | Required |
|--------|------|----------|
| iPhone 16 Pro Max | 1290×2796 px (6.9") | ✅ Required |
| iPhone 16 | 1179×2556 px (6.1") | ✅ Required |
| iPhone 14 Plus / 13 Pro Max | 1284×2778 px (6.7") | ⚠️ Optional |
| iPhone 13 / 13 Pro | 1170×2532 px (6.1") | ⚠️ Optional |
| iPhone 8 Plus | 1242×2208 px (5.5") | ⚠️ Optional |

#### iPad (Required if supporting iPad)

| Device | Size | Required |
|--------|------|----------|
| iPad Pro 12.9" (6th gen) | 2048×2732 px | ✅ Required |
| iPad Pro 11" (4th gen) | 1668×2388 px | ⚠️ Optional |

### 5.2 Screenshot Content Guidelines

#### Screenshot 1 - Hero/Dashboard
- Show the main dashboard with subscription overview
- Display total monthly spending prominently
- Include a few subscription cards (Netflix, Spotify, etc.)
- Clean, uncluttered view

#### Screenshot 2 - Subscription Detail
- Show detailed view of a single subscription
- Include cost-per-hour calculation
- Show next billing date and pause options
- Display cancellation difficulty rating

#### Screenshot 3 - Smart Detection
- Show the URL input screen
- Demonstrate auto-detection of a service
- Display recognized service logo and details

#### Screenshot 4 - Multi-Currency
- Show currency settings or conversion
- Display subscriptions in different currencies
- Show exchange rate information

#### Screenshot 5 - Pause/Cancel
- Show the pause recommendation screen
- Or show the cancellation guide with steps
- Highlight potential savings

#### Screenshot 6 - Premium/Paywall (Optional)
- Show Premium features
- Display pricing options
- Highlight benefits of upgrading

### 5.3 Design Guidelines

- **Format**: PNG or JPEG (PNG preferred for quality)
- **Color Space**: sRGB or P3
- **Status Bar**: Should show full signal, full battery, time set to 9:41 AM
- **No Alpha/Transparency** in final images
- **No Device Frame**: Use pure screenshots, no device mockups in the actual submission
- **Localized**: Create separate sets for each supported language

### 5.4 Screenshot Tools

Recommended tools for creating screenshots:
- **Simulator**: Use Xcode Simulator for exact sizes
- **Screenshot Studio**: Screenshot Pro, Shotbot
- **Design Tools**: Figma, Sketch templates for device frames (for marketing only)

---

## 6. Review Guidelines Compliance

### 6.1 App Store Review Guidelines Checklist

#### Safety (Section 1)
- [x] App does not contain objectionable content
- [x] User-generated content is moderated
- [x] No harmful or dangerous content

#### Performance (Section 2)
- [x] App is complete and functional
- [x] No placeholder content
- [x] App uses public APIs correctly
- [x] No excessive battery drain

#### Business (Section 3)
- [x] In-App Purchase for digital goods (Premium subscription)
- [x] No misleading pricing
- [x] Correct use of StoreKit

#### Design (Section 4)
- [x] Follows Human Interface Guidelines
- [x] No excessive use of web views
- [x] Native iOS design patterns

#### Legal (Section 5)
- [x] Privacy policy provided
- [x] Required permissions have usage descriptions
- [x] Complies with data protection laws

### 6.2 In-App Purchase Requirements

The app uses StoreKit 2 for subscriptions. Ensure:

1. **Products are created** in App Store Connect:
   - `com.pausely.premium.monthly` - $7.99/month
   - `com.pausely.premium.annual` - $69.99/year

2. **Subscription Group**: Create a group called "Premium"

3. **Review Information**: Provide test credentials for reviewers:
   - Test email: `review@pausely.app`
   - Test password: [Create test account]

### 6.3 Common Rejection Reasons to Avoid

| Issue | Prevention |
|-------|------------|
| Crashes on launch | Test on physical device, not just simulator |
| Broken links | Verify all external URLs work |
| Placeholder content | Remove all "coming soon" or placeholder text |
| Missing privacy policy | Ensure privacy policy URL is live |
| Incorrect screenshots | Screenshots must reflect actual app UI |
| Test account issues | Provide working test credentials |

---

## 7. Privacy Policy Requirements

### 7.1 Required Privacy Policy Content

Your privacy policy at `https://pausely.app/privacy` must include:

#### Data Collection Disclosure

**Data Linked to You:**
- Email address (for authentication)
- Subscription data (names, costs, billing dates)
- Usage data (app analytics)

**Data Not Linked to You:**
- Crash logs
- Performance data
- Diagnostic information

#### Data Usage

Explain how you use each type of data:
- Authentication: To create and secure your account
- Subscription tracking: To provide core app functionality
- Analytics: To improve app performance and user experience

#### Data Sharing

Pausely does not:
- Sell user data to third parties
- Share subscription data with service providers
- Track users across apps and websites

#### Third-Party Services

List all third-party services used:
- **Supabase**: Database and authentication hosting
- **Apple Sign In**: Authentication option
- **RevenueCat**: In-app purchase management
- **LemonSqueezy**: Alternative payment processing

#### User Rights

Explain user rights regarding their data:
- Right to access: Users can view all their data in the app
- Right to deletion: Users can delete their account and all data
- Right to export: Users can request data export

#### Contact Information

Provide contact for privacy inquiries:
```
Email: privacy@pausely.app
Address: [Your business address]
```

### 7.2 Privacy Nutrition Labels

In App Store Connect, complete the privacy nutrition labels:

| Data Type | Used for Tracking | Linked to Identity | Purpose |
|-----------|-------------------|-------------------|---------|
| Email | No | Yes | App Functionality |
| User Content (subscriptions) | No | Yes | App Functionality |
| Usage Data | No | No | Analytics |
| Crash Data | No | No | App Functionality |

### 7.3 Privacy Manifest (PrivacyInfo.xcprivacy)

The app includes a `PrivacyInfo.xcprivacy` file (required as of Spring 2024):

- Tracks user data usage
- Documents required reason APIs
- Lists third-party SDKs

---

## 8. App Rating

### 8.1 Rating Questions

Answer these questions in App Store Connect:

| Question | Answer | Explanation |
|----------|--------|-------------|
| Made for Kids | No | Not specifically designed for children |
| Gambling | No | No gambling content |
| Contests | No | No contests or sweepstakes |
| Unrestricted Web Access | No | Links open in Safari, not in-app browser |
| Gambling and Contests (simulated) | No | - |
| Medical Treatment | No | No medical advice |
| Alcohol, Tobacco, Drugs | No | None referenced |
| Profanity/Crude Humor | No | None |
| Mature/Suggestive Themes | No | None |
| Horror/Fear Themes | No | None |
| Cartoon/ Fantasy Violence | No | None |
| Realistic Violence | No | None |
| Prolonged Graphic Violence | No | None |

### 8.2 Final Rating

Based on the answers above, Pausely will receive:

**Rating**: **4+** (Everyone)

This is the most permissive rating and appropriate for a subscription management app.

---

## 9. Submission Checklist

### Pre-Submission Checklist

#### App Functionality
- [ ] App launches without crashes
- [ ] All features work as described
- [ ] No placeholder or test content visible
- [ ] Deep links work correctly (`pausely://`)
- [ ] Magic link authentication works
- [ ] In-app purchases load correctly
- [ ] Biometric authentication works (Face ID/Touch ID)

#### App Store Connect
- [ ] App record created
- [ ] Bundle ID matches Xcode project
- [ ] App information completed
- [ ] Pricing and availability set
- [ ] In-app purchases created and approved
- [ ] Screenshots uploaded for all required sizes
- [ ] App description finalized
- [ ] Keywords entered
- [ ] Support URL is live
- [ ] Privacy policy URL is live
- [ ] App icon uploaded (1024×1024 px)

#### Legal & Privacy
- [ ] Privacy policy published
- [ ] Privacy nutrition labels completed
- [ ] Privacy manifest included in app bundle
- [ ] Required permission descriptions in Info.plist
- [ ] No use of non-public APIs

#### Review Information
- [ ] Test account credentials provided
- [ ] Review notes completed
- [ ] Contact information for review team
- [ ] Demo video prepared (if needed for complex features)

#### Build & Archive
- [ ] Version number updated (CFBundleShortVersionString)
- [ ] Build number updated (CFBundleVersion)
- [ ] App builds without warnings
- [ ] Archive created successfully
- [ ] App passes App Store validation
- [ ] Build uploaded to App Store Connect

### Final Submission Steps

1. **Archive Build**:
   ```
   Xcode → Product → Archive
   ```

2. **Upload to App Store Connect**:
   ```
   Organizer → Distribute App → App Store Connect → Upload
   ```

3. **Select Build**:
   - In App Store Connect, go to your app
   - Select the uploaded build

4. **Submit for Review**:
   - Complete all required fields
   - Click "Add for Review"

---

## 10. Post-Submission

### 10.1 Expected Timeline

| Stage | Timeline |
|-------|----------|
| App Review | 24-48 hours (typical) |
| First Review | May take longer for new apps |
| Re-review (if rejected) | 24 hours |
| Ready for Sale | Immediate after approval |

### 10.2 Common Rejection Reasons & Fixes

| Rejection Reason | Solution |
|------------------|----------|
| Metadata rejection | Update screenshots/description to match actual UI |
| Binary rejection | Fix the reported issue, increment build number, resubmit |
| Guideline 2.1 (Performance) | Ensure app is complete and all features work |
| Guideline 4.2 (Design) | Improve UI to follow Human Interface Guidelines |
| Guideline 5.1.1 (Privacy) | Update privacy policy, add required disclosures |

### 10.3 After Approval

1. **Release Options**:
   - Manual Release: You control when it goes live
   - Automatic Release: Goes live immediately after approval
   - Scheduled Release: Set a specific date/time

2. **Post-Launch Monitoring**:
   - Check App Analytics daily
   - Monitor crash reports in Xcode Organizer
   - Respond to user reviews
   - Track in-app purchase conversion rates

3. **Marketing Activities**:
   - Update website with App Store badge
   - Announce on social media
   - Reach out to press/bloggers
   - Consider Apple Search Ads

---

## Appendix A: Info.plist Reference

Required keys in `Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Basic Info -->
    <key>CFBundleDisplayName</key>
    <string>Pausely</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    
    <!-- Permissions -->
    <key>NSFaceIDUsageDescription</key>
    <string>Use Face ID to quickly and securely sign in to Pausely</string>
    
    <!-- URL Schemes -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.pausely.app</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>pausely</string>
            </array>
        </dict>
    </array>
    
    <!-- Device Support -->
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>armv7</string>
    </array>
    
    <!-- Orientation -->
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
</dict>
</plist>
```

---

## Appendix B: Contact Information

### Developer Contact

- **Developer Name**: [Your Name/Company]
- **Apple ID**: [Your Apple ID]
- **Team ID**: [Your Team ID]
- **Support Email**: support@pausely.app
- **Support Website**: https://pausely.app/support

### Emergency Contacts

If Apple needs to contact you urgently:

- **Primary**: [Your phone number]
- **Secondary**: [Backup phone number]

---

## Document Version

- **Version**: 1.0
- **Last Updated**: February 2026
- **Next Review**: Before v1.1 submission

---

*This document should be reviewed and updated before each App Store submission.*
