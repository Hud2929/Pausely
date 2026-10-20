# Pausely: pricing, value and launch-timing research

Written 2026-10-20. Question: are $9.99/month and $39.99/year (what is live today) too cheap or too expensive,
what does a consumer get for the money, and should Pausely ship before Gmail detection is approved?

## Short answer
1. **Too expensive for what the app does today, right for what it will do once Gmail detection ships.**
   Recommended launch prices: **$4.99/month and $29.99/year** (annual is the default plan, 7-day trial kept).
   Raise yearly to about $39.99 and monthly to about $7.49 when Gmail detection ships. Both rises fit Apple's
   no-consent window.
2. **Do not go as low as $2.99/month.** It needs 3.3x the paying customers to earn the same, and the price is hard to raise later.
3. **Publish now, do not wait for Gmail.** The live listing still carries false claims, ratings take time, and
   Google's approval date is not in your control. Ship Gmail as a 1.1 update.

## What a consumer gets today (and what they do not)
Value the app really delivers without Gmail: one place for every subscription, the true yearly total
(a six-subscription demo shows about $2,339 a year), renewal and free-trial reminders, cost per year/day, cheaper
alternatives, and cancellation links for 900+ services.

Value it **cannot** deliver without automatic detection: finding subscriptions the user forgot. You cannot type in
what you have forgotten. That is the biggest reason people want a tracker (42% say they pay for a service they no
longer use; about 55% have at least one unused subscription), and it is exactly what Gmail detection adds. Two
claims in the old copy implied detection or automatic price-hike alerts. Both were removed on 2026-10-20: the
price alert only compares the number the user typed last time with the number they type now.

## The consumer test (role-play: "Jordan", average American, about 6 subscriptions)
| Moment | Reaction | Worth |
|---|---|---|
| Sees "this year you'll spend $2,339 on subscriptions" | A real "whoa"; about 4 in 10 people drop a subscription after seeing their total | the app's strongest moment |
| Renewal and trial reminders | Prevents roughly one surprise charge a year | about $20-50 a year |
| Cancel links and difficulty ratings | Saves 10-15 minutes per cancellation | small, real |
| Has to type each subscription in | Friction. Apps that need manual entry lose users about 3x faster (vendor claim, treat as directional) | negative |
| Expects to be shown subscriptions they forgot | Not delivered until Gmail | the gap |

**What I would pay as Jordan:** tracking only, about **$20-30 a year** (or $2.99-4.99 a month). Nothing at
$9.99 a month: paying $120 a year to track your subscriptions feels absurd, and that is the exact reason the
closest competitor Bobby sells for a one-time $1-3. With automatic detection that finds even one forgotten
subscription, about $40-60 a year is fair, because one forgotten $10 subscription costs $120 a year.

## Evidence
**What competitors charge** (US App Store pages, read 2026-10-19; one-time packs versus subscriptions are mixed):
| App | Price points | Ratings |
|---|---|---|
| Bobby (manual tracker) | one-time packs $0.99-2.99 | 557 |
| Subscription Tracker | $2.99 | 258 |
| Skaffer | $2.99 | 90 |
| SubManager+ | $9.99 | 68 |
| Chronicle | $14.99 | 212 |
| Hiatus | $13.99-20.99 monthly, $35.99-59.99 yearly | 6,917 |
| Subscription Stopper | $5.99-11.99 monthly, $59-99 yearly | 682 |
| Rocket Money (bank sync, budgeting) | about $7-14 monthly, "pay what you think is fair" ([source](https://www.rocketmoney.com/learn/personal-finance/how-much-does-rocket-money-cost)) | 400k |

Manual-entry trackers sit at $0-3 one-time. Apps that detect subscriptions automatically and cancel for you sit at
$7-14 a month. Pausely at $9.99 a month was priced like the second group while delivering the first group's product.

**Industry benchmarks:**
- Productivity apps: median monthly price $8; most common monthly $10 and annual $30; monthly plans bring 77% of revenue ([RevenueCat 2026, Productivity](https://www.revenuecat.com/state-of-subscription-apps-2026-productivity)).
- Across all apps: median monthly about $10, yearly about $34.80; higher-priced apps convert better (2.8% versus 1.4% for low-priced) but that is correlation, not proof ([RevenueCat 2026](https://www.revenuecat.com/state-of-subscription-apps/)).
- Price tests can go either way: one app lowered its annual price from $59.99 to $44.99 and revenue per user rose 10% ([Superwall case study](https://superwall.com/case-studies/sellraze.md)).
- 55% of Americans plan to cut subscriptions in 2026 ([NerdWallet survey via local news](https://www.kold.com/2026/04/07/more-than-half-americans-plan-cut-subscriptions-2026-survey-finds/)). People underestimate their subscription spend by about $133 a month ([The Ascent](https://fool.com/the-ascent/personal-finance/articles/survey-finds-americans-spend-133-more-than-they-realize-on-monthly-subscription-fees/)).
- Ratings drive installs: 79% of users check them first, and going from 3 to 4 stars can lift conversion up to 92% ([AppFollow](https://appfollow.io/blog/ratings-and-reviews-part-1)). Pausely has 0 ratings today.

**The math** (Apple takes 15% under the Small Business Program; confirm enrollment):
| Plan | You keep per customer | Extra customers needed to match revenue after the cut |
|---|---|---|
| Monthly $9.99 | $8.49 | n/a |
| Monthly $4.99 | $4.24 | +100% |
| Monthly $2.99 | $2.54 | +234% |
| Annual $39.99 | $33.99 | n/a |
| Annual $29.99 | $25.49 | **+33%** |

Cutting the annual price is cheap (a third more buyers covers it); cutting the monthly price is expensive
(it needs twice the buyers). That is why $29.99 / $4.99 is the sweet spot: yearly is the plan you want people on
($2.50 a month, 8 cents a day), and monthly stays under $5.

## Options considered
| Option | Verdict |
|---|---|
| Keep $9.99 / $39.99 | Too high for a manual tracker with no ratings. Fine once Gmail detection ships. |
| $2.99 / $19.99 | Too cheap: 3.3x payers needed, signals a toy, hard to raise later. |
| **$4.99 / $29.99** | **Recommended now.** Matches the most common annual price ($30), under $5 monthly. |
| Add a lifetime option (about $59.99) | Worth testing. Subscription-weary users like owning things, it fits the brand, and it anchors yearly as the sensible choice. Gmail processing is on-device, so there is no heavy server cost. |
| Lower the free limit | No. Keep 5, so a typical user sees their real yearly total before the paywall. |

**Raising later:** Apple only needs a customer's consent when an increase is both over 50% and over about $5 a month
(or $50 a year), and only one increase per subscriber per 12 months ([Apple](https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions)).
Annual $29.99 to $44.99 and monthly $4.99 to $7.49 are both exactly +50%, so they stay inside the window.
**Lowering is the one-way door:** a decrease applies to existing subscribers at once and cannot be reversed.

## Should we publish before Gmail?
**Yes.**
- The live listing (1.0.1) still says "Smart Pause" and "AI". Only a new version can replace it.
- Ratings and search ranking take weeks to build. Waiting for Gmail means a blank, claim-ridden listing longer.
- Gmail timing is outside your control: Google's review takes weeks and may require a paid security assessment.
- A Gmail launch is stronger as a 1.1 update: new "What's New", new promo text, the price rise, and a reason for existing users to return.
- Risk: manual entry loses users. Mitigate with fast onboarding (catalog of 1,000+ services, paste a link) and by not
  marketing "find hidden subscriptions" until it is true. A bridge worth building: the bank-statement CSV import
  that already exists in the code but no screen opens.
- Hard rule: keep Gmail hidden in release builds until Google approves it. A reviewer who taps it would hit Google's "unverified app" wall.

## Decision checklist
1. Check Sales and Trends for current subscribers (a price cut moves them to the lower price immediately).
2. Choose prices. Recommended: $4.99 / $29.99, applied with the 1.0.3 release.
3. Decide whether to sell Pro outside the US and Canada (today it is sold only there).
4. Submit 1.0.3. Plan Gmail as 1.1 when Google approves.
