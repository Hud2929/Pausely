# Engineering rules

Short rules that keep Pausely's numbers, dates and promises correct. Most of them come from
how Lago (an open-source billing engine) avoids billing bugs; see `LAGO_TAKEAWAYS.md`.

## Money

Full rules, recipes and checks: the `pausely-currency` skill (`.claude/skills/pausely-currency/`).
`CurrencyGuardTests` fails the tests when code goes around them.

- Amounts are `Decimal` and always travel with a currency code. Convert to `Double` only for
  display math or charts, never before storing or comparing.
- All money text comes from `MoneyFormat` (Core/Money); the reader's locale picks the symbol.
- A subscription's price shows in its own currency; anything added up, compared or ranked is in the
  display currency, every item converted first (`monthlyTotal(in:)`, `MoneyMath.total`).
- Conversion returns nil for an unknown currency; never fall back to the unconverted number.
- Prices shown on the paywall come only from StoreKit for the customer's storefront ("…" while
  loading). `ProPricing` holds the USD launch prices for internal use, never for display.
- The annual "Save N%" badge is computed from the real StoreKit prices
  (`StoreKitManager.annualSavingsPercent`). Never hardcode a percentage.

## Renewal dates

- `Subscription.nextBillingDate` is the **anchor**: the date the user entered or confirmed.
  Never overwrite it with a computed date.
- Read upcoming renewals through `calculatedNextBillingDate` or `nextRenewal(onOrAfter:)`.
  Both roll the anchor forward for active and trial subscriptions, and leave cancelled and
  paused ones alone.
- Compute the k-th renewal from the anchor (`anchor + k × period`), never by adding a month to
  the previous result. This keeps the 31st on the 31st (or the last day of short months) and
  Feb 29 on Feb 28 in other years. `RenewalSchedule` does this. Do not reimplement it.
- Store dates at local noon (`Calendar.noon(of:)`) so time zone and DST changes cannot move
  them to another day.

## Reminders

- Never schedule a renewal or trial notification directly. Change the data, then call
  `ReminderScheduler.shared.reschedule(_:)`. `SubscriptionStore` already does this after
  add, edit, delete, cancel, pause and resume.
- The scheduler removes every pending Pausely reminder and adds `ReminderPlanner.plan(...)`.
  The plan is a pure function of the subscriptions and the time, so a stale reminder can't
  survive a change.
- iOS keeps 64 pending notifications per app. The planner keeps the soonest 60.
- "Remind me: Off" (`notifyBeforeDays == 0`) means no renewal reminders of any kind.
- Decisions change reminders: a "Keep it" (`LifecycleEvent.kept` with its `renewalDate`) removes the
  remaining reminders for that charge; subscriptions in a Pause Plan get the plan's reminders instead
  of renewal ones. Both go through `ReminderPlanner`, never around it.
- Ask for notification permission in context (the dashboard card, Settings → Notifications), never
  with `.provisional` and never at launch.

## Things that happen over time

- Changes that happen without a user action (a trial ends, a renewal passes) go in
  `SubscriptionLifecycle.changes(for:since:now:)`, which is pure and tested, and are applied
  in `run()`. It runs when subscriptions load and when the app comes to the foreground.
- Record what happened in `LifecycleEventLog`. The log stays on the device and is the source
  for price history and measured savings. Don't infer history from the current state.

## What Pro unlocks

- `ProFeature` is the list. The paywall rows are generated from it, and screens check
  `PaymentManager.isUnlocked(_:)`.
- Use `isPremium` only to show membership status (badges, profile), never to gate a feature.
- The free limit is `FreeTier.subscriptionLimit`. Copy that mentions the limit reads that value.
- The App Store listing (`metadata/`) must promise exactly what `ProFeature` lists. Update both
  together.

## Savings

- The Savings Receipt is derived from the event log (`SavingsLedger`), never stored. Only charges the
  renewal engine says would have happened count, for 12 months after a cancellation, and they stop
  on reactivation. Pausely's own subscription never counts.
- "I cancelled it" marks a subscription cancelled; it doesn't delete it.

## Settings and claims

- Every switch in Settings must change behaviour. If a feature doesn't exist, it has no switch.
- Every claim on a screen, in the paywall or in the App Store listing must be true of the shipped
  build (no "end-to-end encryption", no Face ID that isn't there). Check the code before writing copy.

## Private data on the device

- Local history (event log, Pause Plan, cached list) belongs to one account: `LocalUserData.claim`
  wipes it when a different account signs in, and account deletion wipes it with the server data.

## Links and configuration

- Support, privacy, terms and website URLs come from `AppConfig`. Don't hardcode a domain in a view.
- Route deep links with `URL.routeSegments`: in `pausely://auth/confirm` "auth" is the host, not a
  path component.
- No secrets in the repo, in `Info.plist` committed values, or in memory notes.

## Database migrations

- Two steps for removing a column: first ship an app version that no longer reads or writes it,
  then drop the column (for example `20261020_drop_smart_pause_alerts.sql`).
- Migrations are additive and idempotent (`if not exists` / `if exists`).

## Localization and builds

- New user-facing strings get all five translations (ar, de, es, fr, ja) in `Localizable.xcstrings`,
  using the exact keys from the build's `.stringsdata`; keep format placeholders identical and use
  positional ones (`%1$@`) when word order changes.
- DEBUG-only types and flags must not be referenced from release code; build Release before shipping.

## Tests

- Logic that depends on time takes `now` and `calendar` parameters. Tests pass a fixed date and
  a calendar with DST (`America/Toronto`) instead of reading the clock.
- Run the suite serially. Parallel simulator clones sometimes fail to boot:

  ```
  xcodebuild test -scheme Pausely -destination "id=<simulator>" \
    -only-testing:PauselyTests -parallel-testing-enabled NO
  ```
