# Pausely through a first-time customer's eyes

Reviewed 2026-10-22 on a freshly erased iPhone 17 Pro simulator, build from `main`
(1.0.3, after the renewal-engine and dead-code work). Every screen was captured by
`PauselyUITests/ScreenTourTests` and read the way a customer would read it.

**Who I am for this review:** 34, in the US, about eight subscriptions (streaming, music,
a gym app, iCloud, ChatGPT, a meal kit I keep meaning to cancel). I spend $150–220 a month
and I'm not sure exactly how much. I found Pausely by searching "subscription tracker". I
want two things: **don't let me get charged for things I forgot**, and **show me what to
cut**. I'll pay if the app saves me more than it costs.

---

## Screen by screen

| Screen | What I liked | What bothered me |
|---|---|---|
| Onboarding carousel (3 pages) | Dark, calm, looks premium. | "We automatically find and categorize your subscriptions", with a *Smart Detect* badge on Spotify. It doesn't: I have to add everything by hand (Gmail import isn't live yet). "Save $42/month by switching 3 subscriptions to annual" is not believable. The card on page 2 is clipped at the top. |
| "Get Started" | | **A second 3-page carousel** ("Track Your Spending", Skip/Next) shows the same dashboard mockup again. Six intro pages before I can do anything. |
| Sign-up wall | Sign in with Apple is there. | I must create an account before I see a single number about *my* money. |
| Dashboard | Monthly total is big and clear. "Next payment · in 2 days" and the week strip are exactly what I want. | "Apple One: possible waste" just because it's my most expensive subscription. Pausely knows nothing about whether I use it. Under the tab bar there's a half-hidden "Highest monthly cost". "Lifetime Spend $0.00" looks broken. |
| Subscriptions list | Clean, sorted by renewal, colour shows urgency. | Every service is a coloured letter. No logos anywhere in the app. |
| Tapping a subscription | Cancel timing ("80% used, $4.48 left") is clever. "Keep until retirement: $8,058" made me think. | "Total Paid Since Added $0.00". Two different yearly numbers on one screen ($269.30 and $268.63). **"Cancel Subscription 🔒 Pro"**: I have to pay Pausely to find out how to cancel Netflix. That's when I stopped trusting it. |
| Analysis | "This year you'll spend $2,491 = 444 coffees" lands. | The donut has three categories in the same grey. "Spending forecast: Optimized $207.09", the same as Current, then "Minimal $103.54", exactly half. The waste alerts are the same sentence twice: "costs $X/day — consider if cheaper alternatives exist". "Unlock Pro to Analyze" doesn't say what I'd get. Text scrolls under the clock. |
| Profile | Settings are well organised. The "personality" card is fun. | "7 renewing soon" while the list says "Upcoming 2". Content scrolls under the status bar. |
| Settings → Notifications | | Six toggles, including Weekly Reports, Savings Opportunities and Usage Reminders. **None of them do anything**, and four describe features that don't exist. |
| Add subscription (catalog) | 1,192 services, plans per service, search. Fast. | All logos are letters. Prices show "$" for my CAD account and a couple look wrong. |
| Edit | Excellent: big amount, cycle, next payment, "Remind me", yearly total. | |
| Paywall | Honest: real prices, 7-day trial, renewal terms, restore. | "Cancel anytime" is listed as a Pro feature. "Save 50%" appears twice. Faceless avatar circles as "social proof". Nothing about what Pro would save *me*. |
| Gmail import results (demo) | **The best screen in the app.** "We found 7 subscriptions, $143/month", "Adobe renews in 20 days, $779.88 yearly", "Spotify raised its price", "Hulu looks like it ended", "Checked 312 emails, all on your phone". This is the product. | Not available to customers yet (waiting on Google verification). |
| Wrapped | Shareable and well designed. | |

## What I found under the hood (things a customer feels but can't name)

1. **Pausely never asks for notification permission.** The only code that asks runs when you
   cancel a subscription or use a Shortcut. Renewal reminders are planned but never scheduled,
   because permission is still "not determined". *The app's main promise doesn't work for a
   new customer.*
2. **Tapping a reminder does nothing special.** The notification delegate is never set. The
   "Tap to decide whether to keep it" text in the reminder leads nowhere, and the action
   buttons that are registered are never handled.
3. **The redesigned subscription screen is unreachable.** Real taps open the older
   `SubscriptionDetailView`. The newer `SubscriptionManagementView` (Edit, price history,
   switch to yearly, cheaper alternatives, usage, call support) is only opened by a debug
   launch flag, and the App Store screenshots show it.
4. **Service logos never load.** They come from logo.clearbit.com, which no longer answers.

## Verdict

**Value for the price today: 4 / 10.**
(10 = the golden standard: it obviously pays for itself and I'd recommend it unprompted.)

- **Design and feel: 8/10.** It looks and moves like a premium app.
- **Core job, "warn me before I'm charged": 2/10.** Reminders never fire for a new install.
- **Trust: 4/10.** Overpromising onboarding, placebo settings, paying to see how to cancel,
  and "waste" that's really just "expensive".
- **Pro value: 3/10.** Unlimited subscriptions plus generic tips. The one feature that would
  make me pay, the Gmail import, isn't live.
- **Price fairness:** $29.99 a year is reasonable *if* it catches one forgotten charge.
  $4.99 a month is hard to justify for what Pro does today.

**Is the price justified today? No.** I'd use the free tier for a week, never get a
reminder, and forget the app exists, which is ironic for a subscription tracker.

**Could it be worth far more than it costs? Yes, clearly.** The pieces are already here:
the Gmail results screen, cancel timing, lifetime cost, a correct renewal engine and a local
event log. What's missing is the moment that turns information into a saved charge, and a
receipt that proves it. With the fixes and the standout feature in `PRODUCT_PLAN.md` I'd
expect **8.5/10**: the app pays for itself in the first month and *shows* me that it did.

---

## After the fixes (same day, re-run of the screen tour on a fresh install)

| What I hit as a customer | Before | Now |
|---|---|---|
| Onboarding | Six intro pages, "We automatically find…", "$42/month" | Three true pages, then the age check and sign-up |
| Reminders | Never asked for permission, so nothing fired | Dashboard asks in context, naming my next charge; Settings shows the real status |
| Tapping a reminder | Did nothing | Opens the Renewal Verdict; "Keep it" works from the notification |
| Settings → Notifications | Six placebo switches | Two real switches and the real permission state |
| Tapping a subscription | Old screen, cancel locked behind Pro | Redesigned screen with cancel timing, lifetime cost, tools; cancel help free |
| Logos | Letters everywhere | Real service icons |
| "Waste" | My most expensive subscription | Only with evidence (forgotten, duplicate, unused) |
| Privacy & Security | "End-to-End Encryption" switch, Delete did nothing | Plain facts about where data lives; Delete Account works (after the server function is applied) |
| What Pausely saved me | Nothing to show | Savings Receipt with every avoided charge and its date |
| Streaming | Pay for all of them | Pause Plan: about $180–360 a year back for two or three services |

**Value for the price now: 8 / 10.** The core promise works, every claim is true, and the app shows
its own return: the Savings Receipt, and the Pausely Promise telling me to cancel Pausely if it isn't
worth it. For someone with two or more streaming services, Pause Plan alone covers the $29.99 a year
several times over.

**Why not 9 or 10 yet:** adding subscriptions is still manual (Gmail import is waiting on Google's
review), the reminders need a check on a real iPhone over a real renewal cycle, and account deletion
needs the `delete_my_account` migration applied before release.
