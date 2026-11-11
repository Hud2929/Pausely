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

Read `ENGINEERING_RULES.md` before changing money, dates, reminders or what Pro unlocks. For
anything that shows, adds or converts an amount, use the `pausely-currency` skill: all money goes
through `Pausely/Core/Money` and `CurrencyGuardTests` enforces it.
Where the product is going: `REVOLUTION_PLAN.md` (positioning, roadmap, $10M model, makeover).

## Building and testing

Open `Pausely.xcodeproj`, scheme `Pausely`. From the command line:

```bash
xcodebuild build -scheme Pausely -destination "id=<simulator id>" -derivedDataPath /tmp/PauselyBuild
xcodebuild test -scheme Pausely -destination "id=<simulator id>" -derivedDataPath /tmp/PauselyBuild \
  -only-testing:PauselyTests -parallel-testing-enabled NO
```

Run tests serially; parallel simulator clones sometimes fail to boot. Check Release builds too:
DEBUG-only code must not be referenced from release code paths.

Tests must be able to fail: assert exact outcomes (not "not nil" or "didn't crash"), never test code the
app doesn't call (delete the dead code instead), and never skip on every run. Tests that use the shared
`SubscriptionStore` wrap themselves in `StoreSandbox` (TestHelpers.swift): cloud writes off, and the list,
sync queue, history, widget data, Spotlight and reminders put back afterwards. Nothing touches the live
database from tests.

DEBUG launch arguments open single screens with demo data (see `RootView` in `ContentView.swift`):
`--demo-mode`, `--demo-tab=N`, `--demo-verdict`, `--demo-receipt`, `--demo-savings`,
`--demo-pause-plan` (`--demo-plan-active`), `--demo-subscription`, `--demo-subscription-edit`,
`--demo-paywall`, `--demo-browser`, `--demo-gmail-results`, `--demo-inbox`, `--demo-imap-connect` (`=yahoo`, `=aol`, `=other`…),
`--demo-wrapped`, `--demo-auth` (`=signup`, `=signin`, `=verify`, `=reset`, `=newpassword`), `--demo-age-gate`,
`--demo-settings=notifications|privacy|help|currency|export|language`, `--demo-whats-new`, and `--screenshots`
for App Store captures. Debug builds show "Test without an account" on the welcome screen (a local test
user; nothing reaches the server). `--reset-state` (UI tests) starts signed out with onboarding not yet seen;
`--fresh-demo-data` starts the subscription list from the demo set on every launch, with cloud writes off. `PauselyUITests/ScreenTourTests` captures every screen when
`TEST_RUNNER_PAUSELY_TOUR_DIR` is set.

## Architecture

### Entry and navigation
`Pausely/ContentView.swift` holds `PauselyApp`, the `AppDelegate` (sets the notification delegate and
categories at launch) and `RootView`: splash → `FirstRunView` (guess, tally, reveal) →
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
- `Core/Money`: `MoneyFormat` (all money text), `CurrencyRates` (conversion, built-in rates),
  `MoneyMath` (totals across currencies). `CurrencyManager` (in SupabaseManager.swift) holds the
  display currency and live rates.
- `SupabaseManager`, `ScreenTimeManager` (manual usage), `ReferralManager`, `KeychainManager`, `AppConfig`.

### Finding subscriptions in email (`Pausely/Services/Mailbox/`, plan in `INBOX_PLAN.md`)
One engine, one adapter per kind of inbox, all read-only and on-device:
- `MailboxProvider` (open → candidates → summaries → raw message → close/revoke) with three adapters:
  `GmailMailboxProvider` (Gmail API, `gmail.readonly`), `MicrosoftGraphProvider` (Outlook, Hotmail,
  Live, MSN, Microsoft 365; needs `MS_CLIENT_ID` in Info.plist) and `IMAP/IMAPMailboxProvider`
  (iCloud, Yahoo, AOL, GMX, WEB.DE, Zoho, Fastmail, Xfinity, any server; app passwords; EXAMINE and
  BODY.PEEK only, TLS 1.2+). Presets live in `MailboxAccount.swift`.
- `MIMEParser` turns raw RFC 822 into a `RawEmail`; `Intelligence/EmailSignalExtractor` +
  `ReceiptTextAnalyzer` reduce it to a `ReceiptSignal`; `ReceiptLedger` keeps the facts (never the
  mail) tagged by inbox; `SubscriptionIntelligenceEngine` proves subscriptions from charge patterns.
- `InboxScanner` runs it all for every connected inbox; `Views/InboxImportView` and `Views/Inbox/`
  are the screens. Each provider is gated in `FeatureFlags` (on in DEBUG, off in release).
- Tests: `PauselyTests/Services/Mailbox/` and `RealWorldReceiptShapesTests` (shapes from real inboxes,
  rewritten with made-up details). `LiveMailboxTests` only run with `TEST_RUNNER_` variables:
  `PAUSELY_LOCAL_IMAP` / `PAUSELY_LOCAL_IMAP_APP` (a local IMAP server), `PAUSELY_REAL_MAIL_DIR` (a
  folder of .eml files), `PAUSELY_LIVE_SERVERS=1` (real provider servers), `PAUSELY_REAL_ACCOUNTS=1`
  (inboxes connected in the app on that simulator). `ProviderWorkflowTests` run the Gmail and Outlook
  adapters against stand-ins for their APIs (made-up mail, or `PAUSELY_REAL_MAIL_DIR`).
  `PauselyUITests/InboxWorkflowUITests` drives the IMAP flow through the screens with
  `PAUSELY_LOCAL_IMAP_UI=host:port:user:password`. Never commit real email.
- End-to-end rig: `scripts/mailtest/make_test_mailbox.py <dir>` writes a synthetic mailbox (real MIME, six
  languages, decoys) and its `truth.json`; `scripts/mailtest/imap_test_server.py` serves it on localhost;
  `MailTruthTests` (`PAUSELY_MAIL_TRUTH_DIR=<dir>`) scores a scan against the truth on name, amount,
  currency, period and state. `ReceiptAccuracyTests` pins each mistake that rig has exposed.

### Views
- `Views/Verdict/`: `RenewalVerdictView`, `SavingsReceiptView`, `PausePlanView`, dashboard cards.
- `SubscriptionManagementView`: the subscription screen (tools, cancel timing, lifetime cost).
- `SubscriptionEditView`, `SubscriptionBrowserView` (catalog), `StoreKitUpgradeView` (paywall),
  `Settings/` (notifications, privacy and account deletion, help).

### Design
iPhone and iPad (`TARGETED_DEVICE_FAMILY = "1,2"`; 1.0.1 shipped on iPad, so Apple rejects any
update that drops it). On iPad, `.readableWidth()` keeps the app at phone width, centred; apply it
to any new `fullScreenCover`. Dark only. The design system is "Ink and Paper"
(`DesignSystem/InkPaper.swift`, rules in the `pausely-design` skill): `Color.ink` background, `PaperSlip`
only where money is decided or proven, `Color.kept` (mint) only for money kept, `Font.question` (serif)
for questions and totals, `Font.proof` (mono) for receipt lines, `.buttonStyle(.ink…)`, `Motion`, `Feel`.
`scripts/old_ui_check.sh` must print "0 files". `ServiceLogoView` loads logos (touch icon, then favicon,
cached). `--demo-design` shows every part; screen ratings are in `REDESIGN_PLAN.md` section 11.

### Localization
`Pausely/Localizable.xcstrings`: English plus Arabic, German, Spanish, French and Japanese. New
strings need all five translations; take the exact keys from the build's `.stringsdata` files.

## Backend

Supabase project `ddaotwyaowspwspyddzs`. Migrations live in `supabase/migrations/` and are applied by
hand in the Supabase SQL editor. Pending as of 2026-11-06: paste `supabase/APPLY_2026-11-06.sql` (account deletion and
cancel-difficulty ratings need it; it also closes the 2026-11-06 security holes: self-granted Pro,
public affiliate and referral data, and adds the sync columns).
Edge function: `supabase/functions/waitlist-signup`. Website and policies: `pausely.pro/` (GitHub Pages).

Account emails are sent by Supabase from templates edited in its dashboard; the copy to paste is
`SUPABASE_EMAIL_TEMPLATES.md`. The app asks for the 6-digit code in them (`Views/Auth/EmailCodeViews.swift`)
and also accepts any link shape a template might carry (`Services/AuthLink.swift`, `handleDeepLink`), so a
template change can't lock people out. Sign-up, sign-in and reset screens: `Views/Auth/AccountForms.swift`.

## App Store

Listing text in `metadata/` (push with `asc metadata push`), screenshots in
`AppStoreScreenshots/iphone-6.9` and `AppStoreScreenshots/ipad-13` (captured in the `en_CA` locale), products and review notes in `appstore_products.json`,
`scripts/asc_apply.sh` for pricing and subscription text. Never submit for review without the
owner's explicit go-ahead.

## Autonomy

I trust Claude to act autonomously on this project. Unless an action is destructive, irreversible, or affects shared/external systems (e.g., force push, delete production data, send messages, spend money), Claude may proceed without asking for approval. Claude should proactively identify problems, propose fixes, and keep working until blocked or complete.
