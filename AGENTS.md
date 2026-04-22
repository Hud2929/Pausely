# Pausely - Revolutionary Subscription Manager

## Overview

Pausely has been completely rebuilt as a production-ready, fully functional subscription management app with:

- ✅ **Real Authentication** with email confirmation & persistent sessions
- ✅ **Multi-Currency Support** (50+ currencies with real-time exchange rates)
- ✅ **Smart URL Parser** (500+ services recognized from URLs)
- ✅ **Enhanced Pause/Cancel** (200+ services with direct links)
- ✅ **Real Data from Supabase** (no more fake/sample data)
- ✅ **Revolutionary UI/UX** with glass morphism design

## Architecture

### Core Services

#### AuthManager (`Services/AuthManager.swift`)
- Email confirmation on signup
- Persistent session with Keychain storage
- Biometric authentication (Face ID / Touch ID)
- Session auto-refresh before expiry
- Password reset flow

```swift
@StateObject private var authManager = AuthManager.shared

// Sign up with email confirmation
try await authManager.signUp(email: email, password: password)

// Sign in with session persistence
try await authManager.signIn(email: email, password: password)

// Check session on app launch
await authManager.checkSession()
```

#### CurrencyManager (`Services/CurrencyManager.swift`)
- 50+ currencies with real-time exchange rates
- Automatic conversion of all subscription amounts
- Exchange rate caching (1 hour TTL)
- Device locale auto-detection

```swift
@StateObject private var currencyManager = CurrencyManager.shared

// Convert amount
let converted = currencyManager.convert(amount, from: "USD", to: "EUR")

// Format amount
let formatted = currencyManager.format(amount, currencyCode: "USD")
```

#### SmartURLParser (`Services/SmartURLParser.swift`)
- 500+ service patterns
- Auto-detection from pasted URLs
- Metadata extraction (logo, description, pricing)
- Direct cancel/pause URL detection

```swift
@StateObject private var urlParser = SmartURLParser.shared

// Parse URL
if let result = await urlParser.parseURL("https://netflix.com") {
    print(result.name) // "Netflix"
    print(result.directCancelURL) // "https://www.netflix.com/cancelplan"
}
```

#### SubscriptionActionManager (`Services/SubscriptionActionManager.swift`)
- 200+ services with detailed information
- Direct cancel/pause URLs
- Support contact info (phone, chat, email)
- Cancellation difficulty ratings
- Alternative service suggestions

### Data Models

#### Subscription (`Models/Subscription.swift`)
```swift
struct Subscription: Identifiable, Codable {
    var id: UUID
    var name: String
    var amount: Decimal
    var currency: String
    var billingFrequency: BillingFrequency
    var status: SubscriptionStatus
    var nextBillingDate: Date?
    var canPause: Bool
    var pauseUrl: String?
    // ... more fields
}
```

### View Models

#### SubscriptionStore (`ViewModels/SubscriptionStore.swift`)
- Real-time sync with Supabase
- Local caching for offline access
- CRUD operations with error handling
- Automatic total calculations

```swift
@StateObject private var store = SubscriptionStore.shared

// Fetch subscriptions
await store.fetchSubscriptions()

// Add subscription
try await store.addSubscription(newSubscription)
```

## Key Features

### 1. Authentication Flow

1. User signs up with email/password
2. Confirmation email sent
3. User clicks link in email
4. Account activated
5. Session persisted across app launches

### 2. Multi-Currency Support

- Each subscription stores its native currency
- All totals displayed in user's preferred currency
- Real-time exchange rate updates
- Visual indicators for foreign currency subscriptions

### 3. Smart URL Input

Users can add subscriptions by:
1. Pasting a URL (e.g., `https://netflix.com`)
2. App auto-detects service name, category, pricing
3. Pre-fills subscription details
4. User can edit before saving

### 4. Pause/Cancel Management

For each subscription:
- Direct cancel URL (if available)
- Direct pause URL (if supported)
- Support phone number
- Support chat/email
- Step-by-step cancellation instructions
- Difficulty rating (Easy/Medium/Hard/Very Hard)

## Supabase Setup

### Required Tables

```sql
-- Subscriptions table
CREATE TABLE subscriptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    logo_url TEXT,
    category TEXT,
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT DEFAULT 'USD',
    billing_frequency TEXT DEFAULT 'monthly',
    next_billing_date DATE,
    monthly_usage_minutes INTEGER DEFAULT 0,
    cost_per_hour DECIMAL(10,2),
    roi_score DECIMAL(5,2),
    status TEXT DEFAULT 'active',
    can_pause BOOLEAN DEFAULT true,
    pause_url TEXT,
    paused_until DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- RLS Policy
CREATE POLICY "Users can only see their own subscriptions"
    ON subscriptions FOR ALL
    USING (auth.uid() = user_id);
```

### Auth Settings

1. Enable Email provider in Supabase Auth
2. Enable "Confirm email" for new signups
3. Configure email templates with confirmation links
4. Set up deep linking for email confirmation (optional)

## App Store Configuration

### In-App Purchases

Configure in App Store Connect:
- `com.pausely.premium.monthly` - $7.99/month
- `com.pausely.premium.annual` - $69.99/year

### Info.plist

```xml
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to quickly sign in to Pausely</string>
```

## UI Components

### Glass Modifier
```swift
.glass(intensity: 0.2, tint: .white)
.glassCard(color: .purple)
```

### Premium Button
```swift
Text("Get Started")
    .premiumButton(gradient: [Color.luxuryPurple, Color.luxuryPink])
```

### Animated Background
```swift
AnimatedGradientBackground()
```

## Testing

### Test Scenarios

1. **Sign Up Flow**
   - Create new account
   - Check email for confirmation
   - Click confirmation link
   - Verify auto-login

2. **Session Persistence**
   - Log in
   - Kill app
   - Reopen - should still be logged in

3. **Currency Conversion**
   - Add subscription in USD
   - Change currency to EUR
   - Verify amounts convert correctly

4. **URL Parsing**
   - Paste Netflix URL
   - Verify auto-detection
   - Check cancel link availability

5. **Offline Mode**
   - Load subscriptions
   - Turn off internet
   - Verify cached data displays

## Known Limitations

1. **Email Confirmation Deep Linking**: Currently requires manual email check. Deep linking from email app to Pausely app requires additional setup.

2. **Exchange Rate API**: Using free API with rate limits. For production, consider:
   - exchangerate-api.com paid plan
   - Open Exchange Rates
   - Cache rates locally with longer TTL

3. **URL Metadata Extraction**: Basic pattern matching. Advanced scraping would require:
   - Server-side scraping (to avoid CORS)
   - Open Graph / Schema.org parsing
   - ML-based service detection

## Future Enhancements

1. **Bank Connection**: Plaid integration for auto-detection
2. **Email Import**: Gmail API for receipt scanning
3. **Push Notifications**: Renewal reminders
4. **Widgets**: Home screen spending widget
5. **Siri Shortcuts**: "Add Netflix subscription"
6. **Apple Watch**: Quick spending check
7. **Family Sharing**: Shared subscription tracking

## File Structure

```
Pausely/
├── PauselyApp.swift              # App entry point
├── Services/
│   ├── AuthManager.swift         # Authentication
│   ├── CurrencyManager.swift     # Multi-currency
│   ├── SmartURLParser.swift      # URL recognition
│   ├── SubscriptionActionManager.swift  # Cancel/pause
│   ├── SupabaseManager.swift     # Backend client
│   ├── PaymentManager.swift      # In-app purchases
│   └── SubscriptionLinkingManager.swift # Email/bank import
├── Models/
│   ├── Subscription.swift        # Core data model
│   └── User.swift                # User model
├── ViewModels/
│   └── SubscriptionStore.swift   # Data management
├── Views/
│   ├── Auth/
│   │   ├── EnhancedLoginView.swift
│   │   └── EmailConfirmationView.swift
│   ├── Subscription/
│   │   └── SmartURLInputView.swift
│   ├── DashboardView.swift
│   ├── SubscriptionsListView.swift
│   ├── SubscriptionManagementView.swift
│   ├── ProfileView.swift
│   ├── PerksView.swift
│   ├── PaywallView.swift
│   └── EnhancedAddSubscriptionView.swift
└── DesignSystem/
    └── GlassModifier.swift
```

## Build & Run

1. Open `Pausely.xcodeproj` in Xcode
2. Set your Supabase URL and key in `SupabaseManager.swift`
3. Build and run on simulator or device
4. Test all features thoroughly

## Credits

Built with:
- SwiftUI
- Supabase
- StoreKit
- SwiftKeychainWrapper (for secure storage)
