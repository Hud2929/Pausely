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

`scripts/proof.sh` is the whole proof in one command (`PAUSELY_SIM=<simulator id>`): the mechanical
checks (`scripts/gold_check.sh`, which must print a total of 0), the unit tests, the mail rig (the
synthetic mailbox served on this Mac, and every test a plain run skips for want of a mail server),
the UI tests other than the screen tour, and a Release build, stopping at the first that fails.
`scripts/proof.sh unit ui` runs only the steps named (`checks`, `unit`, `mail`, `ui`, `release`); `db`
adds the database and function rigs (Docker). Run it before a commit
that changes a screen: a UI test can go stale without any unit test noticing. In a UI test, a tap
that has a result to wait for goes through `tap(until:)` (`PauselyUITests/TabHelper.swift`): on the
simulator a test's touch is sometimes taken back before it counts, so it taps once more, and a button
that does nothing still fails.

Tests must be able to fail: assert exact outcomes (not "not nil" or "didn't crash"), never test code the
app doesn't call (delete the dead code instead), and never skip on every run. Tests that use the shared
`SubscriptionStore` wrap themselves in `StoreSandbox` (TestHelpers.swift): the account is replaced by a
stand-in (`sandbox.transport`, offline until the test puts it online; it can refuse and be changed
mid-send), and the list, history, widget data, Spotlight and reminders are put back afterwards. Nothing
touches the live database from tests.

DEBUG launch arguments open single screens with demo data (see `RootView` in `ContentView.swift`):
`--demo-mode`, `--demo-tab=N`, `--demo-verdict`, `--demo-receipt`, `--demo-savings`,
`--demo-pause-plan` (`--demo-plan-active`), `--demo-subscription`, `--demo-subscription-edit`,
`--demo-paywall`, `--demo-browser`, `--demo-gmail-results`, `--demo-inbox` (`=connected`, `=nothing`, `=failed`), `--demo-imap-connect` (`=yahoo`, `=aol`, `=other`…),
`--demo-wrapped`, `--demo-auth` (`=signup`, `=signin`, `=verify`, `=reset`, `=newpassword`), `--demo-age-gate`,
`--demo-settings=notifications|privacy|help|currency|export|language`, `--demo-whats-new`, and `--screenshots`
for App Store captures. Debug builds show "Test without an account" on the welcome screen (a local test
user; nothing reaches the server). `--reset-state` (UI tests) starts signed out with onboarding not yet seen;
`--fresh-demo-data` starts the subscription list from the demo set on every launch, with cloud writes off
(other lists: `--varied-demo-data`, `--empty-demo-data`, `--quiet-demo-data`, `--large-demo-data` with
`--demo-currency=IDR` for nine-digit totals). States with no screen of their own: `--demo-splash`,
`--demo-loading`, `--demo-load-failed`, `--demo-reminders=ask|denied|on|hidden|late`, `--demo-form-problem`,
`--demo-reset-code`, `--demo-store-offline`, `--demo-no-trial`, `--demo-pro[=trial|ending|problem]`, `--demo-account[=named]`,
`--demo-dates`, `--demo-waiting`, `--demo-guess=N`. `PauselyUITests/ScreenTourTests` captures every screen
and state when `TEST_RUNNER_PAUSELY_TOUR_DIR` is set (`TEST_RUNNER_PAUSELY_TOUR_VARIANT=ar|de|es|fr|ja|big|xxxl`,
`TEST_RUNNER_PAUSELY_TOUR_AUDIT=1` for Apple's accessibility audit, `TEST_RUNNER_PAUSELY_TOUR_ONLY=a,b` for a few,
`TEST_RUNNER_PAUSELY_TOUR_ORIENTATION=landscape` for an iPad on its side). For Bold Text, switch the simulator's own
setting on before the run and off after it: `xcrun simctl spawn <device> defaults write com.apple.Accessibility
EnhancedTextLegibilityEnabled -bool true` (SwiftUI's `legibilityWeight` can be read but setting it changes nothing).
A step the tour could not take (a button it never reached, a tap that brought nothing) is listed in `tour_misses.txt` in the
tour folder: the capture under that state's name is then of the screen before it. Every page is followed to its end, and
`python3 scripts/tour_page_ends.py <tour folder> [<later folder> …]` lists any that was not (it exits 1).
`scripts/tour_read.swift` reads a tour folder (build it with `swiftc -O`): `contrast` measures every text from the pixels it was
drawn with, `words` looks up every word readable on a capture in what accessibility says, and `audit` shows what is drawn where
the system audit called low contrast (its contrast lines change from run to run on an unchanged screen, so they are checked this way).
A field's hint is made by `Hint.text` (the system's placeholder grey is 2.5 to 1 on ink).
Don't use `ViewThatFits` (the audit reports its text as unable to grow; `LineOrStack` does the same with one copy).

## Architecture

### Entry and navigation
`Pausely/ContentView.swift` holds `PauselyApp`, the `AppDelegate` (sets the notification delegate and
categories at launch) and `RootView`: splash → `FirstRunView` (guess, tally, reveal) →
`WelcomeFlow` (sign up / sign in) → `AgeGateView` when needed → `MainTabView`
(Dashboard, Subscriptions, Analysis, Profile). Deep links go through `DeepLinkManager`: only
`pausely://` links are the app's (`URL.routeSegments`); it claims no web links.

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
- `AuthManager` (AuthManager.swift): auth, sign out, `deleteAccount()`.
- `SubscriptionStore` (ViewModels): offline-first list, synced to the Supabase `subscriptions` table.
  Every change lands on the device and in `Sync/SyncQueue` in one step (one pending add, change or
  remove per subscription; sent after each change, on foreground and when the network returns);
  `Sync/SubscriptionSyncMerge` joins the server's list with the phone's. Changes cannot fail; only
  `addSubscription` throws, for the free limit.
- `PaymentManager`, `StoreKitManager`, `ProFeature`: tiers and the single list of what Pro unlocks.
- `VerdictCenter`, `SavingsSummary`, `PausePlanStore`, `LocalUserData`: the decision flow, receipt
  totals in the user's currency, the saved Pause Plan, and wiping on-device data.
- `NotificationManager` (Core/Utilities): permission, categories, delegate.
- `Core/Money`: `MoneyFormat` (all money text), `CurrencyRates` (conversion, built-in rates),
  `MoneyMath` (totals across currencies). `CurrencyManager` (also in Core/Money) holds the
  display currency and live rates.
- `WidgetDataStore` writes `WidgetFeed` (the days each subscription charges on, about a year ahead) for
  the widgets, which work out "what is next" on the day they draw. `Shared/` is compiled into both the
  app and `PauselyWidget` (the feed, the day wording, the billing calendar, the palette); the widgets
  have their own string catalog.
- `SupabaseManager`, `UsageLog` (hours the person types in, counted for the month they were entered),
  `KeychainManager`, `AppConfig`.

### Finding subscriptions in email (`Pausely/Services/Mailbox/`, plan in `INBOX_PLAN.md`)
One engine, one adapter per kind of inbox, all read-only and on-device:
- `MailboxProvider` (open → candidates → summaries → raw message → close/revoke) with three adapters:
  `GmailMailboxProvider` (Gmail API, `gmail.readonly`), `MicrosoftGraphProvider` (Outlook, Hotmail,
  Live, MSN, Microsoft 365; needs `MS_CLIENT_ID` in Info.plist) and `IMAP/IMAPMailboxProvider`
  (iCloud, Yahoo, AOL, GMX, WEB.DE, Zoho, Fastmail, any server; app passwords; EXAMINE and
  BODY.PEEK only, TLS 1.2+). Presets live in `MailboxAccount.swift`.
- `MIMEParser` turns raw RFC 822 into a `RawEmail`; `Intelligence/EmailSignalExtractor.extractAll` +
  `ReceiptTextAnalyzer` (each figure judged by its own label) + `AppleReceipt` (several subscriptions on
  one receipt) reduce it to `ReceiptSignal`s; `ReceiptLedger` keeps the facts (never the mail) tagged
  by inbox; `SubscriptionIntelligenceEngine` proves subscriptions from charge patterns: `ChargeSchedule`
  finds the schedule in one merchant's charges (which billing period leaves the least unexplained),
  the engine scores it, and `SubscriptionInsights` says what follows (a price rise, a trial ending).
- `InboxScanner` runs it all for every connected inbox and publishes `FoundSubscription`s;
  `Views/InboxImportView` and `Views/Inbox/` are the screens. Findings join the list through
  `TallyImporter.add` (Core/FirstRun), the one importer: free limit in the open, the last real charge
  date as the anchor. Each provider is gated in `FeatureFlags` (on in DEBUG, off in release).
- The privacy sentences on the screen are held by `InboxPrivacyTests`; change the wording and the
  tests together.
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
  `Settings/` (notifications, privacy and account deletion, help, currency), all built from
  `DesignSystem/SettingsParts.swift` (`SettingsPage`, `SettingsSection`, `SettingsRow`, `ChoiceRow`).

### Design
iPhone and iPad (`TARGETED_DEVICE_FAMILY = "1,2"`; 1.0.1 shipped on iPad, so Apple rejects any
update that drops it). On iPad, `.readableWidth()` keeps the app at phone width, centred; apply it
to any new `fullScreenCover`. Dark only. The design system is "Ink and Paper"
(`DesignSystem/InkPaper.swift`, with the parts that share a line in `InkLayout.swift`; rules in the `pausely-design` skill): `Color.ink` background, `PaperSlip`
only where money is decided or proven, `Color.kept` (mint) only for money kept, `Font.question` (serif)
for questions and totals, `Font.proof` (mono) for receipt lines, `.buttonStyle(.ink…)`, `Motion`, `Feel`.
`scripts/old_ui_check.sh` must print "0 files". `ServiceLogoView` loads logos from the service's own site and nobody else (touch icon, favicon, then the icon its front page names; cached). `--demo-design` shows every part; screen ratings are in `REDESIGN_PLAN.md` section 11.

### Localization
`Pausely/Localizable.xcstrings`: English plus Arabic, German, Spanish, French and Japanese. New
strings need all five translations; take the exact keys from the build's `.stringsdata` files.

## Backend

Supabase project `ddaotwyaowspwspyddzs`. Migrations live in `supabase/migrations/` and are applied by
hand in the Supabase SQL editor: paste the newest `supabase/APPLY_*.sql`. It is safe to run more than
once and brings any state of the database up to date (account deletion, cancel-difficulty ratings and
sync need it).
Edge functions (`supabase/functions/`): `waitlist-signup`, `auth-email` (sends the sign-in codes),
`apple-revoke` (revokes Apple's tokens when an account made with Sign in with Apple is deleted; needs
Apple's key as secrets, see its header), and `appstore-notifications` (App Store Server Notifications
webhook). Website and policies: `pausely.pro/` (GitHub Pages; the live site is the `gh-pages` branch).

Account emails are sent by Supabase from templates edited in its dashboard; the copy to paste is
`SUPABASE_EMAIL_TEMPLATES.md`. The app asks for the 6-digit code in them (`Views/Auth/EmailCodeViews.swift`)
and also accepts any link shape a template might carry (`Services/AuthLink.swift`, `handleDeepLink`), so a
template change can't lock people out. Sign-up, sign-in and reset screens: `Views/Auth/AccountForms.swift`.
A link is acted on only when this device asked for a code or reset within the hour, nobody is signed in,
and the account that comes back has the address that was asked for (`AuthLinkGate`). Keep that gate: without
it, a link carrying someone else's code signs the person holding the phone into the sender's account.

Database rules are proven locally, never against the real project: `bash scripts/dbtest/run.sh` builds six
starting states in a throwaway Postgres that stands in for Supabase, applies the newest APPLY file twice to
each, and checks what a signed-out visitor, two signed-in people and the service role can each do.
`bash scripts/dbtest/waitlist_function.sh`, `auth_email_function.sh`, `apple_revoke_function.sh` and
`appstore_notifications_function.sh` run each function against stand-ins. All need Docker (Colima works).
A new migration goes into the APPLY file too, and all five scripts must pass.

## App Store

Listing text in `metadata/` (push with `asc metadata push`), screenshots in
`AppStoreScreenshots/iphone-6.9` and `AppStoreScreenshots/ipad-13` (taken by `ScreenTourTests/testStoreScreenshots` on the 6.9-inch iPhone and the 13-inch iPad simulators, in the `en_CA` locale, with `PAUSELY_TOUR_DIR` set; the clock is set with `xcrun simctl status_bar <device> override --time 9:41`), products and review notes in `appstore_products.json`,
`scripts/asc_apply.sh` for pricing and subscription text. Never submit for review without the
owner's explicit go-ahead.

## Autonomy

I trust Claude to act autonomously on this project. Unless an action is destructive, irreversible, or affects shared/external systems (e.g., force push, delete production data, send messages, spend money), Claude may proceed without asking for approval. Claude should proactively identify problems, propose fixes, and keep working until blocked or complete.
