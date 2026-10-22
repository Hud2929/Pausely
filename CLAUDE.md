# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Pausely is an iPhone app (SwiftUI, iOS 18+) that tracks subscriptions and reminds people before every
renewal. Its core loop: a reminder before each charge opens a **Renewal Verdict** (keep it or cancel
it), every cancellation lands on a **Savings Receipt**, and **Pause Plan** rotates streaming services
one month at a time. Pausely also tracks its own subscription and tells people to cancel it if it
isn't saving them more than it costs (the **Pausely Promise**).

Backend: Supabase (auth + database). Payments: StoreKit 2, Pausely Pro monthly ($4.99) and yearly
($29.99) with a 7-day free trial. Bundle id `com.pausely.app.Pausely`, App Store Connect app 6759973158.

Read `ENGINEERING_RULES.md` before changing money, dates, reminders or what Pro unlocks.

## Building and testing

Open `Pausely.xcodeproj`, scheme `Pausely`. From the command line:

```bash
xcodebuild build -scheme Pausely -destination "id=<simulator id>" -derivedDataPath /tmp/PauselyBuild
xcodebuild test -scheme Pausely -destination "id=<simulator id>" -derivedDataPath /tmp/PauselyBuild \
  -only-testing:PauselyTests -parallel-testing-enabled NO
```

Run tests serially; parallel simulator clones sometimes fail to boot. Check Release builds too:
DEBUG-only code must not be referenced from release code paths.

DEBUG launch arguments open single screens with demo data (see `RootView` in `ContentView.swift`):
`--demo-mode`, `--demo-tab=N`, `--demo-verdict`, `--demo-receipt`, `--demo-savings`,
`--demo-pause-plan` (`--demo-plan-active`), `--demo-subscription`, `--demo-subscription-edit`,
`--demo-paywall`, `--demo-browser`, `--demo-gmail-results`, `--demo-wrapped`, and `--screenshots`
for App Store captures. `PauselyUITests/ScreenTourTests` captures every screen when
`TEST_RUNNER_PAUSELY_TOUR_DIR` is set.

## Architecture

### Entry and navigation
`Pausely/ContentView.swift` holds `PauselyApp`, the `AppDelegate` (sets the notification delegate and
categories at launch) and `RootView`: splash → `OnboardingCarouselView` (3 pages) →
`PremiumWelcomeFlow` (sign up / sign in) → `AgeGateView` when needed → `PremiumMainTabView`
(Dashboard, Subscriptions, Analysis, Profile). Deep links go through `DeepLinkManager`
(`URL.routeSegments` treats `pausely://auth/confirm` and `https://pausely.pro/r/CODE` alike).

### Renewals and decisions (`Pausely/Core/Renewals/`)
All pure and unit-tested; they take `now` and a `Calendar`.
- `RenewalSchedule`: next renewals from the billing anchor (`Subscription.nextBillingDate`).
- `ReminderPlanner`: every pending reminder (renewal, trial, Pause Plan); `ReminderScheduler` applies it.
- `SubscriptionLifecycle`: trials that ended, renewals that passed; runs on load and on foreground.
- `LifecycleEventLog`: on-device event history (added, kept, cancelled, reactivated, price changes).
- `RenewalDecisions`, `VerdictFacts`: what's waiting for a keep-or-cancel decision, and its facts.
- `SavingsLedger`: the Savings Receipt (charges each cancellation avoided over 12 months).
- `PausePlan`: rotation schedule, savings estimate and its reminders.

### Services (`Pausely/Services/`)
- `RevolutionaryAuthManager` (AuthManager.swift): auth, sign out, `deleteAccount()`.
- `SubscriptionStore` (ViewModels): offline-first list, synced to the Supabase `subscriptions` table.
- `PaymentManager`, `StoreKitManager`, `ProFeature`: tiers and the single list of what Pro unlocks.
- `VerdictCenter`, `SavingsSummary`, `PausePlanStore`, `LocalUserData`: the decision flow, receipt
  totals in the user's currency, the saved Pause Plan, and wiping on-device data.
- `NotificationManager` (Core/Utilities): permission, categories, delegate.
- `SupabaseManager` (also `CurrencyManager`), `GmailSubscriptionScanner` (off in release via
  `FeatureFlags`), `ScreenTimeManager` (manual usage), `ReferralManager`, `KeychainManager`, `AppConfig`.

### Views
- `Views/Verdict/`: `RenewalVerdictView`, `SavingsReceiptView`, `PausePlanView`, dashboard cards.
- `SubscriptionManagementView`: the subscription screen (tools, cancel timing, lifetime cost).
- `SubscriptionEditView`, `SubscriptionBrowserView` (catalog), `StoreKitUpgradeView` (paywall),
  `Settings/` (notifications, privacy and account deletion, help).

### Design
Dark only. Colours `Color.obsidianBlack`, `obsidianSurface`, `accentMint`; rounded system fonts.
`ServiceLogoView` loads logos (touch icon, then favicon, cached). `.statusBarBackdrop()` for full-screen
scroll views.

### Localization
`Pausely/Localizable.xcstrings`: English plus Arabic, German, Spanish, French and Japanese. New
strings need all five translations; take the exact keys from the build's `.stringsdata` files.

## Backend

Supabase project `ddaotwyaowspwspyddzs`. Migrations live in `supabase/migrations/` and are applied by
hand in the Supabase SQL editor (the app needs `20261022_delete_my_account.sql` for account deletion).
Edge function: `supabase/functions/waitlist-signup`. Website and policies: `pausely.pro/` (GitHub Pages).

## App Store

Listing text in `metadata/` (push with `asc metadata push`), screenshots in
`AppStoreScreenshots/iphone-6.9`, products and review notes in `appstore_products.json`,
`scripts/asc_apply.sh` for pricing and subscription text. Never submit for review without the
owner's explicit go-ahead.

## Autonomy

I trust Claude to act autonomously on this project. Unless an action is destructive, irreversible, or affects shared/external systems (e.g., force push, delete production data, send messages, spend money), Claude may proceed without asking for approval. Claude should proactively identify problems, propose fixes, and keep working until blocked or complete.
