# StoreKit Testing Guide - Pausely
**Last Updated:** March 5, 2026  
**Status:** ✅ CONFIGURED & READY

---

## Quick Verification

### 1. Configuration Files Status
```
✅ Configuration.storekit (2,980 bytes) - PRIMARY CONFIG
✅ Products.storekit (2,193 bytes) - Backup config
✅ Scheme linked to Configuration.storekit
```

### 2. Build Status
```bash
xcodebuild -scheme Pausely -destination 'platform=iOS Simulator,name=iPhone 16'
Result: ✅ BUILD SUCCEEDED
```

### 3. Product IDs Match
| Location | Monthly | Annual |
|----------|---------|--------|
| Configuration.storekit | `com.pausely.premium.monthly` | `com.pausely.premium.annual` |
| StoreKitConfig.swift | `com.pausely.premium.monthly` | `com.pausely.premium.annual` |
| Status | ✅ MATCH | ✅ MATCH |

---

## StoreKit Configuration Details

### Products in Configuration.storekit

#### Monthly Pro
```json
{
  "productID": "com.pausely.premium.monthly",
  "displayPrice": "6.99",
  "recurringSubscriptionPeriod": "P1M",
  "introductoryOffer": {
    "displayPrice": "0.00",
    "paymentMode": "free",
    "subscriptionPeriod": "P1W"
  }
}
```

#### Annual Pro
```json
{
  "productID": "com.pausely.premium.annual",
  "displayPrice": "54.99",
  "recurringSubscriptionPeriod": "P1Y",
  "introductoryOffer": {
    "displayPrice": "0.00",
    "paymentMode": "free",
    "subscriptionPeriod": "P1W"
  }
}
```

---

## Testing In-App Purchases

### Method 1: Using the Paywall (Recommended)

The paywall appears automatically when:
- User tries to add more than 3 subscriptions (free limit)
- User taps "Upgrade" in profile/settings
- User tries to access premium features

**To Test:**
1. Build and run in iPhone Simulator
2. Navigate through onboarding
3. Try to add 4th subscription → Paywall appears
4. Tap on a product → Purchase flow starts

### Method 2: Direct Paywall Access

Add this test button anywhere in your view:
```swift
import SwiftUI

struct TestPurchaseView: View {
    @State private var showPaywall = false
    
    var body: some View {
        Button("Test Paywall") {
            showPaywall = true
        }
        .sheet(isPresented: $showPaywall) {
            RevolutionaryStoreKitView(currentSubscriptionCount: 4)
        }
    }
}
```

### Method 3: Existing Test Button

The app already includes a test button:
```swift
// In any view:
TestPaywallButton()
```

---

## Purchase Testing Checklist

### Simulator Testing (StoreKit Configuration)

| Test | Expected Result | Status |
|------|----------------|--------|
| Load paywall | Shows Monthly ($7.99) & Annual ($69.99) | ⏳ TEST |
| Select Monthly | Product highlighted, price shows | ⏳ TEST |
| Select Annual | Product highlighted, "BEST VALUE" badge | ⏳ TEST |
| Tap purchase | System purchase sheet appears | ⏳ TEST |
| Confirm purchase | Success animation & confetti | ⏳ TEST |
| Check subscription | `isSubscribed = true` | ⏳ TEST |
| Restore purchases | Finds active subscription | ⏳ TEST |

### Testing Scenarios

#### Scenario 1: Successful Monthly Purchase
1. Open paywall
2. Select "Monthly Pro"
3. Tap "Start Free Trial • $7.99"
4. System dialog appears
5. Confirm with Face ID/Touch ID
6. ✅ Success animation plays
7. Paywall dismisses automatically

#### Scenario 2: Successful Annual Purchase
1. Open paywall
2. Select "Annual Pro" (pre-selected)
3. Tap "Start Free Trial • $69.99"
4. System dialog appears
5. Confirm
6. ✅ Success animation with confetti
7. Paywall dismisses

#### Scenario 3: User Cancellation
1. Open paywall
2. Select product
3. Tap purchase button
4. System dialog appears
5. Tap "Cancel"
6. ⏹️ Returns to paywall (no error)

#### Scenario 4: Restore Purchases
1. Open paywall
2. Tap "Restore Purchases"
3. System checks for previous purchases
4. ✅ Shows "Purchases restored" or "No purchases found"

---

## Debug Console Output

When testing, watch the Xcode console for these messages:

### Product Loading
```
🛒 Loading StoreKit products...
✅ Loaded 2 products:
   - Pausely Pro Monthly: $7.99 (ID: com.pausely.premium.monthly)
   - Pausely Pro Annual: $69.99 (ID: com.pausely.premium.annual)
```

### Purchase Flow
```
🛒 Starting purchase for: Pausely Pro Monthly - $7.99
✅ Purchase successful, verifying...
✅ Purchase successful!
```

### Transaction Updates
```
🔄 Transaction update: com.pausely.premium.monthly
```

### Errors
```
❌ Failed to load products: <error>
⚠️ User cancelled purchase
❌ Purchase failed
```

---

## StoreKit Manager API Reference

### RevolutionaryStoreKitManager

```swift
// Access the shared instance
@StateObject private var storeManager = RevolutionaryStoreKitManager.shared

// Load products
await storeManager.loadProducts()

// Purchase a product
let result = await storeManager.purchase(product)

// Restore purchases
let result = await storeManager.restorePurchases()

// Check subscription status
if storeManager.isSubscribed { ... }

// Get specific product
if let monthly = storeManager.product(for: .premium) { ... }
if let annual = storeManager.product(for: .premiumAnnual) { ... }
```

### Published Properties
```swift
@Published var products: [Product]              // Available products
@Published var isSubscribed: Bool               // Subscription status
@Published var isLoading: Bool                  // Loading state
@Published var errorMessage: String?            // Error message
@Published var purchasedProductIDs: Set<String> // Purchased products
```

---

## Troubleshooting

### Issue: Products not loading
**Symptoms:** Paywall shows "Subscriptions not available"

**Solutions:**
1. Verify Configuration.storekit is selected in scheme:
   - Edit Scheme → Run → Options → StoreKit Configuration
   - Should show: `Pausely/Configuration.storekit`

2. Check product IDs match exactly:
   ```swift
   // In StoreKitConfig.swift
   case monthlyPro = "com.pausely.premium.monthly"
   case annualPro = "com.pausely.premium.annual"
   ```

3. Clean build folder and rebuild:
   ```bash
   Cmd+Shift+K (Clean)
   Cmd+B (Build)
   ```

### Issue: Purchase fails immediately
**Symptoms:** "Purchase failed" error without system dialog

**Solutions:**
1. Check simulator is using StoreKit configuration:
   - Must run in Simulator (not device) for local testing
   - Configuration.storekit only works in Simulator

2. Verify no purchase restrictions:
   - Settings → Screen Time → Content & Privacy Restrictions
   - Check "In-app Purchases" is allowed

### Issue: Transactions not completing
**Symptoms:** Purchase hangs, no success/failure

**Solutions:**
1. Check transaction listener is active:
   ```swift
   // In RevolutionaryStoreKitManager.init()
   updateListenerTask = listenForTransactions()
   ```

2. Verify `transaction.finish()` is called after purchase

### Issue: Build warnings about StoreKit
**Symptoms:** Warnings in console about deprecated APIs

**Status:** ✅ RESOLVED - Using StoreKit 2 (modern API)

---

## Advanced Testing

### Testing Different Scenarios

Modify Configuration.storekit to test edge cases:

#### Test Expired Subscription
1. Purchase subscription in app
2. Edit Configuration.storekit
3. Change subscription expiry to past date
4. Re-run app
5. Should show as unsubscribed

#### Test Billing Error
1. In Configuration.storekit settings
2. Enable `_failTransactionsEnabled: true`
3. Set error percentage
4. Test purchase failure handling

### StoreKit Testing in Xcode

1. **Open StoreKit Transaction Manager:**
   - Debug → StoreKit → Manage Transactions...
   - View all transactions
   - Refund, revoke, or approve transactions

2. **Enable StoreKit Diagnostics:**
   - Edit Scheme → Run → Diagnostics
   - Check "StoreKit"

---

## Production Deployment Checklist

Before releasing to App Store:

- [ ] Create products in App Store Connect (see APP_STORE_CONNECT_SETUP.md)
- [ ] Verify product IDs match exactly
- [ ] Test on physical device with sandbox account
- [ ] Test restore purchases flow
- [ ] Test subscription renewal (wait 1+ days or use accelerated time)
- [ ] Verify receipt validation (if server-side)
- [ ] Check subscription status after app restart
- [ ] Test family sharing (if enabled)

---

## File Locations

```
Pausely/
├── Configuration.storekit          # StoreKit config (linked to scheme)
├── Views/
│   └── RevolutionaryStoreKitView.swift   # Paywall UI
│   └── TestPaywallButton.swift           # Test helper
├── Services/
│   ├── RevolutionaryStoreKitManager.swift # Purchase logic
│   └── StoreKitConfig.swift              # Product IDs
└── STOREKIT_TESTING_GUIDE.md       # This file
```

---

## Support

- **Apple Documentation:** https://developer.apple.com/documentation/storekit/in-app_purchase
- **Testing Guide:** https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases
- **StoreKit Configuration:** https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode

---

**Status:** ✅ StoreKit fully configured and ready for testing
**Last Build:** SUCCEEDED  
**Products Configured:** 2 (Monthly & Annual)
