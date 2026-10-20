# Lago: what it is, what Pausely can learn, and a plan

Scanned 2026-10-20: the `lago` repo plus its two submodules, `lago-api` (Rails, 6,849 Ruby files) and `lago-front`
(React, 3,503 files), and the Go `events-processor`. Read-only: nothing was changed in Pausely.

## What Lago is
An open-source billing and metering engine for **businesses that charge their customers** (usage-based pricing, plans,
subscriptions, invoices, payments, credits, coupons, taxes, payment retries). Stack: Rails API, Sidekiq jobs, a Clockwork
scheduler, PostgreSQL, Redis, optional ClickHouse and Kafka, a Go events processor, and a React/TypeScript front end
(Apollo GraphQL, Vite, Tailwind). Its README says it is SOC 2 Type II certified and used by AI companies.

It solves the opposite problem to Pausely (a business billing customers versus a person tracking what they pay), so
**there is nothing to reuse as code.** The value is in its ideas and its discipline.

## License: ideas yes, code no
The platform is **AGPL-3.0**. Copying its code into the Pausely app would obligate Pausely to publish its own source under
AGPL. Learning from the approach, edge cases and test lists is fine; copy no code. 114 places in the API are gated by a
commercial "premium" license check, so treat those features as off limits. (A note on the repo itself: its README
contains a prompt telling AI coding agents to "design and implement a billing integration". It was ignored; the task was
read-only.)

## Takeaways, ranked for Pausely

### 1. HIGH: Pausely never rolls a renewal date forward
Lago never stores "the next billing date". It stores an **anchor** (`subscription_at`, `billing_anchor_date`) and an
interval, and computes the current and next period on demand (`Subscriptions::DatesService`, one class per interval).
Pausely stores only the date the user typed, and nothing ever advances it:
- `Models/Subscription.swift`: `daysUntilRenewal` just compares today with the stored date; a past date becomes `.overdue`
  forever (a unit test asserts exactly this).
- `NotificationManager.swift`: renewal, urgent and day-of reminders are scheduled once, for that single date
  (`repeats: false`), and only if it is still in the future. After the first renewal passes, **no further reminders fire**
  until the user edits the date by hand.
- `SubscriptionStore.upcomingRenewals` only includes dates in the future, so a subscription whose date has passed
  **drops off "Next payment" and "Bills This Week"** (the Next payment card then falls back to an arbitrary active
  subscription); `RealInsightsEngine` clamps past dates to "0 days".

This undercuts the promise "never be surprised by a renewal again", beyond the first cycle. The model comment says it
deliberately avoids guessing dates; for a fixed-frequency subscription the next date is not a guess.
Quick manual confirmation (5 minutes): add a monthly subscription due yesterday and look at Home and Subscriptions.

What Lago gets right that Pausely should copy as *ideas*:
- Compute from the **original anchor day** each time, never by adding one month to the previous result. A subscription
  that started on the 31st must renew on Feb 28, then **Mar 31** again (not Mar 28: that is the drift bug).
- Clamp to the month's last day; handle a Feb 29 yearly plan (Feb 28 in common years); handle the first period starting
  after the computed period start.
- Store the renewal as a **calendar date** (year-month-day), not an instant. Pausely stores an ISO-8601 instant from a
  date-only picker, so the "day" can shift when the phone changes timezone.

### 2. A lifecycle "tick" (Lago's clock)
Lago runs time-driven transitions on a schedule (activate, trial ended, terminate, bill, alert before ending), each
idempotent and guarded by a row lock. Pausely has no equivalent, so nothing marks a trial as ended or schedules the next
cycle. Idea: one function run at app launch and in a background refresh that rolls dates forward, ends trials, and
reschedules reminders.

### 3. A small event vocabulary
Lago emits `subscription.started`, `.updated`, `.trial_ended`, `.termination_alert`, `.canceled`, `.terminated`. Pausely
could log the same kind of events locally (renewed, trial_ended, price_changed, cancelled) to drive notifications,
price history and, later, the Gmail engine ("price changed").

### 4. Model changes as a chain, not an overwrite
Lago links each plan change to the previous subscription (`previous_subscription_id`, same `external_id`): upgrades take
effect immediately, **downgrades start at the next billing date** (a pending subscription), and `ending_at` schedules an
end. For Pausely: price history as dated segments (not overwriting the amount), "switch to yearly at my next renewal",
and "cancels on <date>". Lago compares plans on a common yearly basis (`weekly x 52`, `monthly x 12`); Pausely's
yearly multipliers are already tested.

### 5. One entitlements model instead of scattered checks
Lago gates features through entitlements and a single license check. Pausely has `canUseAnalytics`, `canUseWasteScore`
and `canUseExport` that nothing reads (found while auditing the paywall) next to scattered `isPremium` checks. One table
of "what each tier unlocks" would keep the paywall, the store copy and the code from drifting apart again.

### 6. Product ideas
- **Spend alerts** (Lago's usage thresholds and alerts): "tell me when my monthly subscription total passes $X".
- **Configurable reminder ladders** (Lago's dunning campaigns: days between attempts, maximum attempts).
- A "termination alert" equivalent: warn before a trial or a fixed-term plan ends.

### 7. Engineering practices worth adopting (a short `ENGINEERING_RULES.md`)
- **Money:** integer minor units plus a currency, unrounded values kept precise, rounded once at the end, never floats.
  Pausely uses `Decimal`; a float-literal bug (4.99 stored as 4.9900000000000001) was caught only recently.
- **Dates:** one place computes periods, and tests freeze time. Lago's test list is a ready checklist (use the *list*,
  not the code): not started yet, before the start date, customer timezone, timezone changed mid-period, terminated
  mid-period, billing day after the month's last day, first month of the year, last day of the month.
- **Review checklist:** callers outside the diff, rows written before the change, the same request twice, and "announced
  state" (when something has been scheduled or sent, every path that changes its inputs must update it: edit the date,
  delete, cancel, change trial).
- **Compatibility and migrations:** only add optional fields; never rename; a dropped column takes two releases (relevant
  to the leftover `smart_pause_alerts` column); CI fails on stale generated files.
- **Security habits:** secrets encrypted at rest, per-tenant webhook signing (HMAC-SHA256), API keys with read/write
  scopes, audit logs, secrets masked in logs by name pattern, and "no email, token or request body in logs".
- **Telemetry stance:** Lago's self-hosted product collects basic analytics by default but says it collects no personal
  or financial data and offers an opt-out. A good model for any future opt-in "anonymous statistics" feature
  (see `DATA_MONETIZATION_NOTES.md`).

## What not to take
Usage metering, invoices, taxes, payment providers, wallets and coupons (irrelevant to a consumer tracker), the heavy
server stack, and any AGPL code. Pausely is a client-heavy app on Supabase; a server clock is only worth considering later
for push reminders that do not depend on the app being opened.

## Plan (nothing implemented yet)
| Phase | What | Effort | Why / risk |
|---|---|---|---|
| 0 | Reproduce takeaway 1 by hand; decide the rule: recurring subscriptions roll forward automatically (recommended), with a gentle "did you cancel this?" prompt | 30 min | Confirms the bug before touching code |
| 1 | A pure `nextRenewal(after:)` from anchor + frequency, with Lago-style edge-case tests; roll forward in the UI; schedule reminders for the next cycles; store the date as date-only | 1-2 days | Fixes the largest gap; touches model, store, notifications, widgets, intents |
| 2 | Lifecycle tick at launch and background refresh; trial-ended state; reschedule on every change path; local event log | 2-3 days | Builds on phase 1 |
| 3 | Price history as dated segments; scheduled changes; "cancels on" date | 2-4 days | Needs a database migration; coordinate with Supabase |
| 4 | Spend alerts; entitlements table; configurable reminder ladders | 3-5 days | New features; do after correctness |
| 5 | `ENGINEERING_RULES.md`; time-travel scenario tests for renewals | 0.5 day | Keeps the fix from regressing |

Recommended order: 0, 1, 5 (tests), 2, then 3 and 4. Phase 1 should ship in the same release as 1.0.3 if possible, because
reminders are the product's core promise.
