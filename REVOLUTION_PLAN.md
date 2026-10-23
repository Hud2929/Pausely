# Pausely: the plan to $10M a year

Written 2026-10-23 from four research reports (market and revenue model, product vision, design,
growth). Builds on `PRODUCT_PLAN.md` (shipped) and `CONSUMER_REVIEW.md` (8/10 today).

**The "10":** Pausely earns $10M a year from about 200–240k paying subscribers who would recommend
it unprompted, because it saves each of them many times what it costs and proves it.

---

## 1. Where the market is (October 2026)

- **Listing subscriptions is now free everywhere.** Apple Card added a Recurring view in iOS 27,
  ChatGPT shows subscriptions from linked banks, and Rocket Money launched *Rowan* (Aug 2026), an AI
  agent that texts you and cancels on reply, in a $15/month tier. A tracker alone won't support a price.
- **People distrust the apps meant to save them money.** Fees of 35–60% of savings, trials that turn
  into annual charges, apps that are hard to cancel (Cleo paid the FTC $17M), and worry about linking a bank.
  AI agents that cancel for you stall at identity checks.
- **The money is real.** People guess they spend $86 a month on subscriptions; it's $219, and 42% pay
  for one they forgot. Rocket Money earns $390M a year from 4.6M payers; Monarch has 500k+ payers at
  $100/yr; Copilot about 100k at $95/yr.
- **Trackers with no automatic detection stay small** (Bobby, Chronicle: one-time purchases under $12).
  Every app over $10M either connects to money or sells a service on top.

## 2. Positioning: the subscription agent that's on your side

> **Pausely finds every subscription you pay for without your bank password, turns each renewal into
> a keep-or-cancel decision on your lock screen, does the busywork of cancelling, pausing and claiming
> refunds, and proves every dollar it saved you. No ads, no trackers, no cut of your savings. If
> Pausely doesn't pay for itself, it tells you to cancel it.**

Tagline candidates: *Every renewal, a decision. Every dollar, proof.* · *Pay for what you use. Pause
the rest.* · *The subscription app that tells you to cancel it.*

What nobody else can say, and what we already have:
1. **No bank password.** Detection by email, screenshot and (later) Apple's FinanceKit, all on device.
2. **Decisions at the moment of charge.** Renewal Verdict with one-tap Keep from the lock screen.
3. **Proof.** The Savings Receipt counts only charges that really didn't happen.
4. **The Pausely Promise.** It tracks its own price and tells you to cancel it if it isn't worth it.
5. **On-device AI at zero marginal cost.** Apple's Foundation Models (iOS 26+): no per-token bill,
   nothing sent to a server. Rowan, ChatGPT and Meta Muse pay per call and see your data.

**North-star metric:** verified yearly savings per active user. Target ≥ $300 a year per Pro
subscriber (10× its price). Guardrail: under 2% wrong detections.

## 3. The product at "10": five signature features

| # | Feature | What it does | Status |
|---|---|---|---|
| 1 | **Find Everything** | Screenshot Import (Settings › Subscriptions or any card app, read on device with Vision), then Gmail, Outlook and iCloud mail import, then Apple Card via FinanceKit (US/UK, if eligible). | Gmail built, waiting on Google; the rest is new |
| 2 | **Renewal Verdict + Trial Guard** | A decision before every charge; a "safe to cancel now?" flag per service, a last-day alert and a Live Activity for the final hours of a trial or renewal. | Verdict shipped in 1.0.3 |
| 3 | **Cancel Concierge** | Step-by-step guides (164 today), drafted cancellation emails you send yourself, confirmation detected from your inbox, and crowd results ("worked, 2 min, offered 50% off"). Never stores passwords, never cancels Apple subscriptions for you. | Guides shipped; rest is new |
| 4 | **Proof: Savings Receipt + Refund Finder + Promise** | Receipt with evidence levels (confirmation found / next charge didn't appear / self-reported); Refund Finder for charges after cancelling (deadlines, prefilled requests, outcome on the receipt). | Receipt and Promise shipped |
| 5 | **Pause Plan + Price-Hike Radar** | Rotate streaming services month by month, with titles arriving and leaving; alerts when a service raises its price, plus a public monthly **Pausely Price Index** for press. | Pause Plan shipped |

Later (6–18 months): **Household** (shared subscriptions and splits via CloudKit),
**On-device coach** ("what should I cut to save $40 a month?"), **Bundle & Perk Finder** (carrier,
card and student deals you already have).

**Won't do:** bank linking in the core app, issuing cards, AI phone calls on your behalf, a credit
score gimmick, ads, selling data, affiliate links that rank by commission.

## 4. Pricing and revenue

| | Today | From Gmail launch (target Q1 2027) |
|---|---|---|
| Free | 5 subscriptions, reminders, verdicts, cancel help, receipt | same; test 3 subscriptions |
| Pro | $29.99/yr, $4.99/mo, 7-day trial | **$39.99/yr, $6.99/mo** for new subscribers; existing ones keep their price as founding members. Test a 14-day trial on annual. |
| Plus / Family | — | **$69.99/yr**: up to 6 people with Family Sharing, shared household list, concierge credits |
| Lifetime | — | Test $89.99, offered selectively |

Both price rises stay under Apple's 50% threshold, so existing subscribers aren't asked to consent
again. Turn on the 16-day Billing Grace Period now (failed payments cause 14% of App Store
cancellations) and win-back offers for people who lapsed 30–90 days ago.

**The maths of $10M:**

| Price (annual / monthly) | Revenue per payer per year | Payers for $10M |
|---|---|---|
| $29.99 / $4.99 (today) | ~$31 | ~326k |
| $39.99 / $6.99 | ~$42 | ~240k |
| 75% Pro + 25% Plus | ~$49 | ~203k |

About 72% of payers are gone within a year, so holding 220k payers means adding ~13–15k new payers
every month: **~300k installs a month at 4.5% install-to-paid.** Paid ads can't buy that: Finance
keywords cost ~$13 per install on Apple Ads, and Pausely can afford ~$1–3. Most installs have to be
earned: App Store search, ratings, creators, press, referrals and search pages.

**Scenarios (month 1 = November 2026):**

| | Floor | Base | The 10 |
|---|---|---|---|
| Installs a month at the peak | 60k | 300k by month 30 | 350k by month 24 |
| Install → paid | 2.5% | 3% → 5% | 4% → 6% |
| ARR at month 12 | $0.03M | $0.12M | $0.3M–1M |
| ARR at month 24 | $0.13M | $1.1M | $4.5M |
| ARR at month 36 | $0.4M | $6.4M | **$13M** |
| $10M reached | no | ~month 49 | **~month 31 (mid-2029)** |

Only ~5% of new apps reach $10k a month within two years. The plan is built to find out early
which column we're in: see the gates in section 7.

At $10M gross, Apple's commission (Small Business Program ends above $1M a year) leaves about
$7.5–7.8M. Support alone needs hires before month 30.

## 5. Growth engine

Ranked by expected share of installs in year one:

1. **App Store search and ratings (30–35%).**
   - Ratings first: 0 → 50 by month 2, 300 by month 4, 1,000 by month 6, at 4.7★+.
     The prompt now fires only after a cancellation lands on the Savings Receipt (1st, 3rd, 10th);
     shipped in this build.
   - Keywords that don't repeat the name or subtitle.
   - Six custom product pages tied to keywords: cancel subscriptions, free-trial reminders, streaming
     rotation, save money, students, Bobby alternative.
   - An in-app event always live: January Subscription Detox, Black Friday trial-trap check,
     December Subscription Wrapped.
   - Promotional text rewritten around each price-rise in the news.
2. **Short video (25–30%).** Founder account daily, then 20–40 small creators a month (10k–150k
   followers, frugal and student niches), $75–300 per video plus a bonus per view. Each creator gets
   a product page, campaign link and offer code. Kill any format under 5 installs per 1,000 views.
   Formats that fit Pausely: "I guessed $40, it's $187", "Keep or cancel?" game show, "This app told
   me to cancel it", "I pay for one streaming service at a time", "How to cancel X in 40 seconds".
3. **"How to cancel X" pages (10–15%, growing).** One page per verified guide on pausely.pro with
   the App Store banner. First verify every guide: 32 of the 164 cancel links return 404 to an
   anonymous visitor and 23 block bots. Check each by hand before publishing.
4. **Apple featuring (bursts).** Featuring nominations 3–4 weeks before each launch (1.0.3, Wrapped,
   Gmail). Adopt Liquid Glass, widgets, Live Activities and App Intents: Apple features apps that use
   its newest features.
5. **Referrals (5–10%).** "Give a month, get a month": the friend enters a code, so nothing is tracked.
   Asked right after a Savings Receipt. (Receiving codes already works; the share screen isn't
   reachable yet.)
6. **Press.** "The app that tells you to cancel it"; the quarterly Pausely Price Index from public
   catalog prices (no user data); "Click-to-cancel was struck down, so one developer built it".
7. **Apple Search Ads (5–10%).** Exact phrases only (subscription tracker, cancel subscriptions,
   Pausely), $20 a day, max $3 per install.

**Activation (the first 90 seconds):** guess your monthly spend → tap the logos of what you pay for
(top 30 services for your country, local prices) → reveal ("You guessed $40. It's $112 a month,
$1,344 a year") → the notification ask names a real charge → a skippable paywall right after the
reveal. Target: 5+ subscriptions in the first session, 70% notification opt-in.

**Measuring without trackers:** App Store Connect analytics by source and product page, campaign
links, offer codes, App Store Server Notifications to Supabase, daily totals only for the onboarding
funnel, and a one-tap "How did you hear about us?".

## 6. The makeover: from dashboard to calm advisor

**Thesis:** one number or one question per screen; color means state, never decoration; Liquid
Glass only on controls; calm everywhere except the one moment money is kept.

**Design system**
- Colors as semantic tokens with light mode and Increased Contrast variants: mint = money kept,
  amber = decide soon, coral = today, sky = paused. Every state also has a symbol.
- SF Pro Rounded for numbers and titles only; drop the `.black` weight; every amount rolls
  (`numericText`).
- A 4-pt spacing grid; concentric corners (card 26, tile 14); no glow shadows, no gradients behind text.
- Springs instead of ease-in-out; a haptics map (selection, keep, swipe, success, printer ticks).
- Charts: ranked bars instead of the donut, one takeaway sentence above each chart, audio graphs.

**Five big moves, in order of impact**
1. **Dashboard from ~13 cards to 5.** The top changes with context: when a renewal needs a
   decision, the decision leads.
2. **System tab bar with Liquid Glass on iOS 26**, plus a "Next decision" bar on every tab, like Apple
   Music's Now Playing. The custom tab bar stays for iOS 18.
3. **The Cancel moment.** The verdict morphs into a paper receipt that prints line by line with
   printer-tick haptics; you tear it off and it flies into "Kept with Pausely". Share renders the
   slip as an image. No confetti (Robinhood had to remove its confetti).
4. **Tokens everywhere**: light mode, springs, haptics, rolling numbers.
5. **Pausely outside the app:** Home and Lock Screen widgets with Keep/Review buttons, a
   "Cancel window" Live Activity, a Watch Smart Stack card, and a Control Center button.

Screen by screen (full spec in the design report): interactive onboarding demo; subscriptions grouped
by time (Needs a decision, This week, This month, Later, Paused), with swipe to Keep or Pause; detail
with a cancel-timing bar; verdict as an inset glass sheet with at most three facts and "Pausely's take";
receipt on paper with the Promise stamp; Pause Plan as a rotation dial; paywall that leads with
"Pays for itself, or we'll tell you to cancel it."

**Order of work:** tokens and motion (2 days) → system tab bar and glass (1) → dashboard (2) →
verdict, Cancel moment and receipt (4) → app icon in Icon Composer (½) → list and detail (3) →
widgets (3) → paywall (1) → light mode (2) → onboarding (3) → charts and dial (5) → Live
Activity, Watch, Wrapped (6). Steps 1–5 take about two weeks and change how Pausely feels more than
everything after them.

## 7. Roadmap with gates

**Now (this week).** Ship 1.0.3: the owner steps in section 9, then "go".

**Horizon 1, November to mid-December 2026: feel premium, find more, get rated.**
- Makeover steps 1–5; Screenshot Import; Trial Guard 2.0; guess-then-reveal onboarding with the
  skippable paywall; Subscription Wrapped for December 1–7; grace period and win-back offers;
  keywords and the first custom product pages; featuring nomination; verify the 164 cancel guides.

**Horizon 2, January to April 2027: automatic detection and the price step.**
- Gmail import when Google approves, then Outlook and iCloud mail; the new prices for new
  subscribers; widgets and the Live Activity; Refund Finder; Price-Hike Radar and the first Price
  Index; referrals; creators; the cancel-guide pages; Plus/Family.

**Horizon 3, May 2027 to April 2028: the agent.**
- Cancel Concierge; on-device coach; Household; FinanceKit if eligible; employer pilot (bulk Pro
  codes); hire for support, then Android or web, once past $1M a year.

**Gates.** Each one decides whether we're on "the 10" path or should re-plan:

| Gate | Date | On track for $10M | If missed |
|---|---|---|---|
| G1 | Feb 2027 | 300 ratings at 4.7★+, 20k installs a month, 3% install→paid | Fix the store page and onboarding before any spend |
| G2 | Apr 2027 | 50k installs a month organically, Gmail live, 4% install→paid | Aim for $1–3M a year: a great solo business |
| G3 | Oct 2027 | ~$1M ARR, 100k+ installs a month, one video format below $0.75 per install | Scale only what pays back within 12 months |
| G4 | Oct 2028 | ~$4.5M ARR, Plus/Family 20%+ of new payers | Add B2B (employers, credit unions) |
| G5 | 2029 | **$10M ARR** | — |

## 8. Risks

- **Rowan, Apple Card and ChatGPT make tracking a commodity.** Answer: detection without a bank,
  decisions at the right moment, proof and honesty, none of which a bank or a chatbot is built for.
- **Gmail's security review** costs about $540 to five figures a year, and Google can take months.
  Screenshot Import is the bridge.
- **One person can't do all of this.** The gates decide when to hire. The makeover and Screenshot
  Import come first because they compound everything else.
- **A price rise can feel like a betrayal.** Existing subscribers keep their price; Pausely announces
  any change in its own Renewal Verdict.
- **App Review:** the concierge must never act without the person's explicit tap, and cancel help for
  Apple subscriptions must only link to Apple's page.

## 9. Done in this session, and what only the owner can do

**Done**
- Release signing fixed: the Release configuration had signing switched off, so archives were
  unsigned.
- iPad support restored. Apple refused build 7 (error 90101) because 1.0.1 ran on iPad and 1.0.3 had
  dropped it. Pausely now shows a phone-width column centred on iPad; 8 new 13-inch iPad screenshots
  are on the 1.0.3 listing.
- **Build 1.0.3 (8) uploaded, validated by Apple and attached to 1.0.3** (not submitted).
- Universal links fixed: the app claimed `pausely.app` (which doesn't resolve) instead of
  `pausely.pro`. The site now serves `apple-app-site-association` for `/r/CODE` referral links, and
  Apple's CDN already has it. A 404 page sends anyone without the app to the App Store.
- Rating prompt moved from "first subscription added" to the 1st, 3rd and 10th cancellation on the
  Savings Receipt.
- New pausely.pro landing page staged on the `site-next` branch; it goes live with 1.0.3 because it
  describes 1.0.3 features.
- UI tests made independent of what earlier runs leave on the simulator (`--reset-state`).
- Checked the 164 cancel links: 78 answer normally, 32 return 404 to an anonymous visitor and the
  rest block bots or need sign-in. They need a hand check before any become public web pages.

**Owner checklist**
1. Paste `supabase/APPLY_2026-10-22.sql` into the Supabase SQL editor (account deletion needs it).
2. Reset the review@pausely.app password and enter it in App Store Connect's App Review fields.
3. Then say **"go"** to submit 1.0.3 (build 8 is attached and ready).
4. Say yes to the 16-day Billing Grace Period; Claude turns it on with one command.
5. Brother (Account Holder): Small Business Program; check FinanceKit eligibility.
6. Get Google security-review (CASA) quotes; never pay before reviewing them together.
7. Decide: the price step to $39.99/$6.99 at Gmail launch, and a Plus/Family tier.
8. Delete the old Resend key and revoke the old GitHub token.
9. Fill in App Privacy in App Store Connect; add the business name and address to the policies.
