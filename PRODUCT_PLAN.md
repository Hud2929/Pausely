# Product plan: from 4/10 to "it pays for itself"

**Status 2026-10-22: all of Parts A, B and C are built, tested and pushed** (commits af99dd8, eaa8104,
1421c04, 8f05e58 and the deep-link fix). Re-rated 8/10 in `CONSUMER_REVIEW.md`. Still open:
Gmail import (waiting on Google), a real-device reminder test, applying
`supabase/APPLY_2026-10-22.sql`, and shipping build 1.0.3.

Based on `CONSUMER_REVIEW.md` (2026-10-22). Three parts: fix what breaks the core promise,
fix what costs trust, then build the feature that makes Pausely different from every other
subscription tracker.

---

## Part A — The core promise has to work (P0)

| # | Problem | Fix | Done when |
|---|---|---|---|
| A1 | Notification permission is never requested, so reminders never fire for new installs. | Ask at the moment it makes sense: right after the first subscription is added ("Get a heads-up before Netflix charges you on Oct 31"). Also add a real status row in Settings → Notifications that turns reminders on or opens iOS Settings if they were denied. Reschedule as soon as permission is granted. | Fresh install → add one subscription → prompt → reminders are pending. |
| A2 | Tapping a reminder does nothing; the action buttons are never handled. | Set the notification delegate at launch and register categories on every launch. A tap opens the Renewal Verdict (C1) for that subscription. Action buttons: **Keep it** (handled in the background) and **Review** (opens the app). Show reminders while the app is open. | Tapping a reminder opens that subscription's verdict. |
| A3 | Six notification toggles do nothing; four describe features that don't exist. | Keep the two that are real: renewal reminders and trial reminders, and have the planner honour them. Remove the other four. | Turning off "Renewal reminders" removes every pending renewal reminder. |
| A4 | Real taps open the old detail screen; the redesigned screen is debug-only. | Open `SubscriptionManagementView` everywhere. Move the Cancel timing and Lifetime cost cards into it. Delete `SubscriptionDetailView`. | Subs tab → tap → Done/Edit screen with tools, cancel timing and lifetime cost. |
| A5 | Cancelling is paywalled. | Cancel guidance is free for everyone. Remove `guidedCancel` from `ProFeature`. | No lock on "Cancel subscription". |
| A6 | Pausely Pro is added to your list at the old prices ($79.99/$9.99), in USD, ignoring the 7-day trial. | Read the real StoreKit price, currency, trial and renewal date from the latest transaction. | After buying, "Pausely Pro" shows the correct price and its trial end. |

## Part B — Trust and polish (P1)

| # | Problem | Fix |
|---|---|---|
| B1 | Two onboarding carousels (six pages) before sign-up. | "Get Started" goes straight to sign-up and "Sign In" to sign-in. One carousel with three true pages: *Know every renewal before it hits* · *Decide in one tap: keep it or cancel it* · *See exactly what Pausely saved you*. Remove the "Smart Detect" badge and the "$42/month" claim. |
| B2 | No logos anywhere (logo.clearbit.com is dead). | Load the service's own `apple-touch-icon`, then fall back to Google's favicon service, then the monogram. Cache on disk. Only the service's domain is sent. |
| B3 | "Possible waste" just means "expensive". | Only call something waste when there's evidence: a duplicate category, a price increase, a forgotten entry, or low Screen Time usage. Otherwise label it "Biggest costs", which is information, not a judgement. |
| B4 | Forecast shows Optimized = Current and Minimal = half. | Show the forecast only when there are real suggested savings, as "Now" vs "With suggested changes". Drop "Minimal". |
| B5 | Three categories share one grey in the donut; "Ai Tools". | A distinct colour per category; "AI Tools". |
| B6 | Content scrolls under the clock. | A status-bar backdrop on the scrolling tabs and sheets. |
| B7 | "$0.00 since added" and "Lifetime Spend $0.00" look broken. | Show recorded renewals once there are any; until then say "Tracking since Oct 2026". |
| B8 | "7 renewing soon" vs "Upcoming 2". | Label it "renew in 30 days". |
| B9 | Paywall lists "Cancel anytime" as a feature, shows "Save 50%" twice, and uses faceless avatars. | Feature rows come from `ProFeature` only. Show the discount once. Replace the avatars with the customer's own numbers and the Pausely Promise (C3). |
| B10 | Small copy bugs ("per monthly", two yearly totals on one screen). | Fix the label; use one yearly calculation everywhere. |

## Part C — The standout: every renewal becomes a decision, with a receipt

Other apps *list* subscriptions. Some cancel them for a cut of the savings. **None of them
turn the renewal itself into a decision, keep an honest receipt of what those decisions saved,
and hold themselves to the same test.**

### C1. Renewal Verdict
Before every renewal (the heads-up N days before, and again the day before) Pausely asks one
question: **keep it or cancel it?** The verdict card shows the evidence on one screen:

- what it renews for and when, and what that is per year
- the price trend from the local event log ("up $2 since you started tracking")
- cancel timing ("cancel now and you keep access until Oct 31")
- the last decision ("you kept it on Sep 30")
- a cheaper option (Pro)

Three answers: **Keep** (recorded; asked again next renewal), **Cancel it** (cancel steps and
link, then "I cancelled it", which marks it cancelled and starts the receipt), **Later**
(asks again tomorrow, never after the renewal day).

Where it shows up: notification tap or action button, a "Decide" card on the dashboard for
renewals inside the reminder window, and the subscription screen.

### C2. Savings Receipt
A conservative, checkable record of money Pausely helped keep:

- A cancellation through Pausely avoids the renewals that would have followed. These come from
  the same renewal engine as the reminders, counted over the 12 months after the decision.
- **Saved so far** counts only avoided charges whose date has passed while the subscription
  stayed cancelled. **On track** is the rest of the 12 months.
- Cancelling a free trial before it ends counts its first charge.
- Shown as a dashboard card ("Saved with Pausely: $46 so far · $310 over 12 months") and a
  receipt screen that lists each line with dates, so nothing is a black box.
- **Return on Pausely:** "Pausely costs you $29.99 a year and has saved you 7.4× that." Free
  users see what Pausely saved them for free.

### C3. The Pausely Promise
Pausely tracks its own subscription like any other, and its own renewal gets a verdict too:
"Pausely saved you $310 this year, 7× its price. Keep it?" If it saved less than it costs,
it says so: *"Pausely saved you less than it costs. We'd rather you cancel than pay for
nothing,"* with the steps to cancel. The paywall says the same up front: **"If Pausely
doesn't save you more than it costs, it will tell you to cancel it."** No other subscription
app tells you to cancel it.

### C4. Pause Plan (Pro)
Pausely is named for pausing. Most people pay for three or four streaming services at once and
watch one at a time. Pause Plan rotates them:

- Pick the services to rotate (monthly streaming services are suggested). Pausely builds a
  month-by-month plan: one service on, the others paused.
- It shows the yearly saving before you start.
- It reminds you to cancel the outgoing service the day before it renews, and to restart the
  next one when its month begins.
- Saved months go on the Savings Receipt.

### What's free and what's Pro
- **Free:** up to 5 subscriptions, reminders, Renewal Verdicts, cancel guidance, the
  Savings Receipt and the Pausely Promise. The core promise is never paywalled.
- **Pro:** unlimited subscriptions, deep savings analysis, cheaper alternatives (shown inside
  the verdict) and Pause Plan.

## Engineering notes
- Decisions are `LifecycleEvent`s (`kept`, `cancelled`, `snoozed`, `rotationPaused`,
  `rotationResumed`), so the receipt is derived from the log and never stored twice.
- `SavingsLedger` and the Pause Plan scheduler are pure functions with tests that pass a
  fixed `now` and calendar (see `ENGINEERING_RULES.md`).
- Reminder settings, snoozes and rotation reminders all go through `ReminderPlanner`, which
  remains the only source of pending notifications.
- Order of work: A1–A6, B1–B10, C1–C3, C4. Build and run the full test suite after each group,
  re-run the screen tour, commit, push.
