# Pausely

**Subscription optimization that maximizes value, not just cancellations.**

Pausely is an iOS app that connects to your bank accounts to identify every recurring charge, then calculates a personal ROI score for each subscription based on your actual usage. Instead of seeing "Netflix - $15.99," you see "Netflix - $8.00 per hour this month" — revealing which subscriptions are actually worth keeping.

## Key Features

- **True Cost Visibility**: Cost-per-hour calculations based on Screen Time data
- **Free Perk Unlocking**: Discover $50-100/month in free alternatives (credit card perks, employer benefits, library access)
- **Pause-First Philosophy**: Pause subscriptions instead of canceling (many services hide this feature)
- **Smart Detection**: Automatically identifies recurring charges from bank transactions

## Project Structure

```
pausely/
├── ios/                          # iOS Swift app
│   └── Pausely/
│       ├── Models/               # Data models (Subscription, UserPerk, etc.)
│       ├── Views/                # SwiftUI views
│       ├── ViewModels/           # State management
│       ├── Services/             # Supabase, API clients
│       └── Utils/                # Helpers and extensions
├── backend/
│   └── supabase/
│       └── migrations/           # Database schema
├── docs/                         # Documentation
└── assets/                       # Logos, images, etc.
```

## Quick Start

### Prerequisites

1. **Apple Developer Account** ($99/year) - Required for App Store submission
2. **Supabase Account** (Free tier) - Backend database
3. **GitHub Account** - Code repository
4. **Domain** - pausely.pro (already purchased ✅)

### Backend Setup (Supabase)

1. Create a new Supabase project at https://supabase.com
2. Go to SQL Editor → New query
3. Copy and paste the contents of `backend/supabase/migrations/001_initial_schema.sql`
4. Run the query to create all tables
5. Go to Project Settings → API to get your `Project URL` and `anon public` key

### iOS App Setup

1. Update `SupabaseManager.swift` with your Supabase credentials:
```swift
let supabaseURL = URL(string: "https://YOUR_PROJECT_ID.supabase.co")!
let supabaseKey = "YOUR_ANON_KEY"
```

2. Build and run in Xcode

### Required Dependencies (Add to Package.swift or SPM)

```swift
dependencies: [
    .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
]
```

## Next Steps

### Immediate
- [ ] Set up Apple Developer account
- [ ] Configure Supabase auth (email/password, Apple Sign In, Google Sign In)
- [ ] Integrate Plaid for bank account connections
- [ ] Implement Screen Time API access
- [ ] Design and implement free perk discovery logic

### Features to Build
- [ ] Bank account connection via Plaid
- [ ] Subscription auto-detection from transactions
- [ ] Screen Time integration for usage tracking
- [ ] Free perk database (credit cards, employers, libraries)
- [ ] Pause functionality with direct links
- [ ] Push notifications for billing reminders
- [ ] App Store submission

## Tech Stack

- **Frontend**: SwiftUI (iOS 16+)
- **Backend**: Supabase (PostgreSQL + Auth + Realtime)
- **Banking**: Plaid API
- **Hosting**: Supabase (free tier)

## Database Schema

### Tables
- `profiles` - User profiles
- `subscriptions` - User's tracked subscriptions
- `bank_connections` - Connected bank accounts
- `user_perks` - Free perks the user has access to
- `perk_opportunities` - Subscription/perk match opportunities
- `pause_history` - Track pause/resume history
- `screen_time` - Usage data from device
- `subscription_catalog` - Known subscription services

## License

Private - All rights reserved

## Contact

Hudson Kim - hudson@pausely.pro
