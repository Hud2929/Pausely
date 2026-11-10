# Pausely redesign and Pro growth plan

Written 2026-11-09. Status: **approved in principle 2026-11-10, build order changed to put value first (section 7). Decisions in section 9 are still open.**
Builds on `REVOLUTION_PLAN.md` (section 6, the makeover) and replaces its screen-by-screen notes.

Contents: 1 What I found · 2 Research · 3 Design direction and system · 4 Screens and signature
moments · 5 Getting people to pay · 6 Measuring without trackers · 7 Build order · 8 The plan,
criticised · 9 Founder decisions · 10 What I could not verify · Sources

---

## 1. What I found

Method: built Debug on iPhone 17 Pro (iOS 26.5), ran `ScreenTourTests` (71 screenshots plus
accessibility trees), then captured the key screens again in Arabic, German, the largest text size
and on iPad Pro 13". Each screen is rated with the 7-dimension harsh method (accuracy 30%, flow 20%,
polish 15%, copy, accessibility, errors 10% each, speed 5%), as a skeptical first-time user. Demo
data throughout, so real-data edge cases are not covered here.

### Ratings today

| Screen | Score | Weakest dimension and why |
|---|---|---|
| Find in Email results | 8.4 | Best screen in the app. Off in release builds. |
| Renewal Verdict | 7.8 | Polish: reads as a settings list, not a decision. The locked "Pro shows a cheaper option" row sits among facts. |
| Pause Plan | 7.7 | Flow: the saving is clear, the rotation itself is not shown. |
| Savings Receipt | 7.6 | Polish: it is a list, not a receipt. Nothing to share. |
| Cancel flow | 7.4 | Polish: a large red X badge for something that saves money. |
| Add (catalog) | 6.8 | Accuracy: Netflix shows $14.99 here and US$15.99 once added; "992 services" under "Search 1,000+". |
| Subscriptions list | 6.6 | Polish: letter avatars here while Home shows real logos; price colours (red, orange, mint) have no legend. |
| German | 6.5 | Copy: "Monthly", "Annual", "Save 50%", "Today", tab names and one Pro row stay English; "Entscheid…" is cut off. |
| iPad | 6.5 | Polish: a phone column in a black field. Acceptable, not designed. |
| Home | 6.4 | Flow: the same charge (ChatGPT Plus) appears four times above the fold; 9 to 11 cards; the total is small. |
| Paywall | 6.3 | Copy and compliance: generic feature list, nothing from the user's data; "Free" is larger than the billed price. |
| Subscription detail | 6.2 | Accuracy: "You just got billed, wait 3 more days" on a subscription 40% through its month; mixed currencies in one card. |
| Profile | 6.0 | Flow: Savings Receipt filed under Settings; "User"; two stat tiles that say 7 and 7. |
| Wrapped | 5.8 | Accuracy: "This year, you spent" is monthly total × months elapsed, whatever the start dates. |
| First launch | 5.5 | Flow: a splash, a feature list, a date-of-birth wheel, then sign-up, then an empty dashboard. |
| Analysis | 5.2 | Accuracy: forecast shows $208.57 now, $22.55 "with suggested changes" (an 89% cut) to free users. |
| Arabic | 5.0 | Polish: letter-spaced labels break Arabic letter joining; tab names, "Today", "in 6d", plan names in English. |
| Largest text | 4.5 | Accessibility: currency pill stacks to "C / A / D"; list rows truncate to "Ch…"; the total wraps mid-number. |

Nothing reaches 9.0. The decision flow (verdict, cancel, receipt) is sound and honest; everything
around it is a generic dark dashboard.

### Things that are untrue or risky today (fix before any redesign work)

1. **Analysis forecast** suggests cutting spending by 89% with no stated basis (`SpendingForecastCard`).
2. **Wrapped** states money was "spent" that may not have been (`WrappedStats.totalSpent`).
3. **Cancel Timing** copy contradicts its own progress bar, and adds converted amounts under a
   price in another currency.
4. **Paywall price prominence.** Apple: "the amount that will be billed must be the most prominent
   pricing element". Today "Free / for 7 days" is the largest. The Monthly/Annual switch is fine
   (Apple is rejecting trial on/off toggles, which this is not).
5. **Store listing against the app:** the listing says "Cancel steps and direct links for 900+
   services" and "1,000+ popular services"; the app shows 992 services and project notes say 164
   written guides. Needs a count before the next submission (see section 10).
6. **"Keep until retirement: $8,116.52"** in red on the detail screen is guilt copy, against the brand.
7. Confetti and a "Purchase Successful!" alert after buying Pro; a 3-second splash with the tagline
   "Smart Subscription Manager".

### The biggest structural problem

A new user meets: splash → feature list → date of birth → account → empty dashboard → manual entry.
There is no number, no insight and no reason to pay in the first 90 seconds. The best moment in the
app (the email results screen: "We found 7 subscriptions, $143.44 a month") is switched off in
release.

---

## 2. Research

**The market.** Listing is free (Apple Card, banks, chatbots; see `REVOLUTION_PLAN.md` section 1).
Bobby, the best-loved manual tracker, is praised for design and simplicity (4.7★, about 7.9k
ratings) and criticised for manual-only entry and inaccurate renewal notifications [1][2]. Rocket
Money's recurring complaints are the 35–60% negotiation fee, cancellation friction and charges
after a trial [3][4]. Review roundups name missed renewal alerts and tedious manual entry as the
top complaints in this category [5] (weak sources; treat as direction).

**What people don't know about their spending.** C+R Research (2022): people guess $86 a month and
pay $219; 42% pay for something they forgot [6]. CNET/YouGov 2026: $111 a month on average, about
$252 a year on unused subscriptions [7]. Self Financial 2026: 70% have forgotten to cancel a trial [7].

**Conversion benchmarks (RevenueCat 2026, 115k apps)** [8]: hard paywalls convert 10.7% against
2.1% for freemium, with nearly equal one-year retention (27% vs 28%); 55% of 3-day-trial
cancellations happen on day 0; longer trials convert better (42.5% for 17–32 days vs 25.5% under 4
days); 72% of annual subscribers cancel in year one and 35% of those in month one; 14% of App Store
cancellations are billing failures.

**Paywall evidence.** A trial timeline with a promised reminder lifted Blinkist's trial starts
about 23% and cut complaints 55% (secondary sources; one independent replication saw +23–25%,
another saw only +4% and lower paid conversion) [9]. Multi-step onboarding paywalls converted 37%
better than single-page in Superwall's own data [10]. Personalised paywalls: vendor figures of
+13–41% [11]. All vendor data; direction only.

**Apple's rules.** Billed amount most prominent; trial length and the price after it stated; restore,
terms and privacy on the purchase screen [12]. Since January 2026 Apple rejects paywalls with a
free-trial toggle [13].

**What the best-designed apps have in common** (principles only; nothing copied): one job per
screen; the interface built from the platform's own materials (the 2026 Apple Design Award for
interaction cited "easy onboarding and best-in-class Liquid Glass integration") [14]; a physical
object the user recognises; numbers that are right; motion that explains a change.

---

## 3. Design direction and system

### Direction: Ink and Paper

Pausely has one object nobody else has: a receipt that proves money was kept. The identity is built
on it. The app is **ink**: near-black, quiet, typographic. **Paper** appears in exactly three
places, where money is decided or proven: the verdict slip, the Savings Receipt and the share card.
**Mint means money kept** and nothing else, so the first time a screen turns mint, it has earned it.
Questions are set in a serif, as if Pausely is asking out loud; proof is set in monospace, like a
till roll. The pause mark's two bars become the two answers: Keep, Cancel.

### Tokens

| Token | Value | Use |
|---|---|---|
| `ink` | #0A0B0D | Background |
| `inkRaised` | #15171A | The few remaining cards |
| `line` | white 8% | Hairlines in place of card borders |
| `paper` | #ECE7DC (warm, not white, to avoid glare on dark) | Slip, receipt, share card |
| `paperInk` | #1A1A17 | Text on paper |
| `kept` (mint) | #34D399 | Money kept; the Keep button |
| `decide` (amber) | #F2B24B | A decision is waiting |
| `due` (coral) | #F26B5E | Charged today or tomorrow |
| `paused` (sky) | #7CB7F0 | Paused |

Every state also has a symbol, so colour is never the only signal. All pairs meet WCAG AA; an
Increased Contrast set is included. **Spend totals turn white**: today the monthly spend is mint,
which says "kept" about money that is leaving.

- **Type.** System fonts only, so all six languages and Dynamic Type work. New York (serif) for
  questions and the one number per screen; SF Pro for everything else; SF Mono for receipt lines.
  Arabic and Japanese fall back to the system face. No letter-spacing on localised text (this is
  what breaks Arabic today). Weights stop at bold.
- **Layout.** 4-pt grid; 20-pt side margin; radius 28 for sheets, 18 for cards, 10 for tiles; no
  glows, no gradients behind text; lists use hairlines, not a card per row.
- **Motion.** Springs only. Numbers roll (`numericText`). Paper prints line by line, 40 ms apart.
  Reduce Motion: cross-fades and no printing.
- **Haptics.** Selection on choices; a soft tick per printed line; a firm single tap on Keep; a
  two-stage tear on Cancel; success once when a line lands on the receipt. Nothing else vibrates.
- **Glass.** On iOS 26, Liquid Glass on the tab bar, toolbars and the decision bar only
  (`#available`); iOS 18 keeps the current capsule bar with solid fills.
- **Accessibility.** Every layout switches to a vertical stack at accessibility sizes; every
  gesture has a button and a VoiceOver action; rows read as one sentence.

---

## 4. Screens and signature moments

### Signature moments (the parts someone would screen-record)

1. **The Tally (first run).** "What do you think you pay for subscriptions each month?" A dial, one
   thumb. Then a grid of the 30 most common services for the user's country: each tap prints a line
   on a paper slip with a tick, and the total rolls. Then the reveal: "You guessed $40. It's about
   $112 a month. $1,344 a year." The slip folds into the app as the user's list. Prices are
   labelled "typical price" and can be changed with one tap; the reveal says "about" until they are
   confirmed.
2. **Tear to cancel.** The verdict is a paper slip: logo, the question in serif, the price, at most
   three facts. Keep: the slip stamps "KEPT until Dec 27" and slides away. Cancel (after the user
   confirms they cancelled with the service): the slip tears along a perforation with a two-stage
   haptic, and the torn half drops onto the Savings Receipt, where the total rolls up.
3. **The receipt is a receipt.** One continuous roll: each cancellation a printed line with its
   avoided charges, the Promise as a stamp at the foot ("Pausely cost you $29.99. It kept you
   $527.64."). A Share button renders it as an image, with a "hide amounts" switch.
4. **Pausely on its own slip.** Starting the trial adds Pausely to the user's list, and two days
   before the trial ends the user gets the same verdict as for any other subscription: "Keep
   Pausely? It has kept you $0 so far. Cancel now and you won't be charged." No competitor can
   afford to copy this.
5. **The 30-day horizon.** Home shows the next month as one line: a dot per charge, sized by amount,
   coloured by state. Drag along it and the header number becomes "what leaves by then".

### Screen by screen

- **First run.** Tally → reveal → reminder permission that names a real charge ("Remind me before
  Netflix charges $15.99 on Nov 27") → paywall (skippable, section 5) → account. Age confirmation
  moves next to account creation. Splash under 0.6 s, no tagline.
- **Home.** Four things: the number (white, large, serif); the next decision (amber, only when one
  is waiting); the 30-day horizon; "Kept with Pausely" (mint, only when above zero). Removed: Next
  Payment and Bills This Week (the horizon replaces both), Biggest Expenses and Lifetime Spend (move
  to Insights), the "healthy" card.
- **Subscriptions.** Grouped by time: Needs a decision, This week, This month, Later, Paused,
  Cancelled. Real logos everywhere. One price colour; state is shown by the group and a symbol.
- **Subscription detail.** Price, next charge, a plain cancel-window bar ("Cancel by Nov 26 to avoid
  the next charge"), then tools. Lifetime cost stays, in neutral colour, without the retirement line.
- **Verdict, cancel, receipt.** As above. The cheaper-alternative row leaves the facts card and
  becomes a quiet line below the buttons.
- **Pause Plan.** A 12-month strip showing which service is on each month; the saving stays.
- **Paywall.** Section 5.
- **Insights (was Analysis).** One sentence, then ranked bars: what costs most, cost per hour where
  usage exists, what went up. The donut, health score, coffee equivalents and the forecast go.
- **Profile.** Account, plan, settings. Savings Receipt and Wrapped move to Home and Insights.
- **Wrapped.** Counts only charges the renewal engine says happened this year; ships for December.
- **Tab bar.** System `TabView` with glass on iOS 26; translated labels; scales with text size.
- **iPad.** Same column, with the receipt and horizon allowed to widen to the readable width.

---

## 5. Getting people to pay

Principle: people pay when the saving is larger than the price and they can see it. Every idea
below has a reason, evidence, and a measure. Impact and effort are my estimates.

| # | Idea | Why it should work | Evidence | Measure | Impact | Effort |
|---|---|---|---|---|---|---|
| 1 | **The Tally reveal in the first 90 seconds** | The gap between guess and reality is the product's whole argument, shown with the user's own list | People underestimate by $133 a month [6]; most trial starts happen on day 0 [8] | Share of new users who reach the reveal; subscriptions added in session one (target 5+) | Very high | 3 days |
| 2 | **"Pays for itself" paywall from the user's data** | The value case is their number: "You track 9 subscriptions, $1,344 a year. Pro is $29.99. Cancelling one month of Peloton covers it." | Personalised paywalls +13–41% (vendor) [11]; multi-step +37% [10] | Trial starts ÷ paywall views, against today's paywall | High | 2 days |
| 3 | **Honest trial timeline, with Pausely on its own slip** | Removes the fear of a forgotten trial, which is the fear this audience has most | Blinkist +23% trial starts, −55% complaints; mixed replications [9]; 70% have forgotten a trial [7] | Trial starts; trial-to-paid; refund requests | High | 1.5 days |
| 4 | **The free limit meets the Tally** | The Tally counts everything; free watches 5. "You pay for 9. Free watches 5: pick them, or Pro watches all 9." The limit arrives when its value is obvious, not as an error | Hard paywalls convert 5× freemium with equal retention [8]; this is the honest middle | Share choosing Pro at this step; share who pick 5 and stay | High | 1 day |
| 5 | **Promise meter for subscribers** | "Pausely has kept you $212, 7× its price" on Home and at each Pausely renewal; when under 1×, it says so | 72% of annual subscribers cancel in year one, 35% of those in month one [8]; proof of value is the retention lever | Renewal rate of Pro users with a receipt above 1× against below | High (retention) | 1 day |
| 6 | **Shareable slips** (the reveal, a torn slip, the receipt) | Each carries the App Store link and, later, a referral code; amounts can be hidden | Share cards drive Wrapped's reach (no controlled data) [15] | Shares per 100 cancellations; installs from the campaign link | Medium, compounding | 1.5 days |
| 7 | **Screenshot Import** | Fixes the top complaint (manual entry) without Google's review: a screenshot of Settings › Subscriptions, read on device | Manual entry is the most cited weakness of trackers [1][5] | Subscriptions added per new user; share of imports accepted unchanged | High | 4 days |
| 8 | **The Sunday slip** | One notification a week: "3 charges this week, $47.93. One needs a decision." A reason to open without nagging | Reminders are the most praised feature in the category [5] | Weekly opens; decisions made within 24 h | Medium | 1 day |
| 9 | **Widgets and Live Activity redone** | "Next decision" on the Lock Screen keeps the product present at the moment of charge | Duolingo reports far better retention for widget users (no figure) [16] | Share of users with a widget; retention with and without | Medium | 2 days |
| 10 | **Recovery, quietly** | Billing grace period (on), win-back offer for lapsed subscribers, offer codes for creators | 14% of cancellations are billing failures [8] | Recovered renewals in App Store Connect | Low to medium | 0.5 day + ASC setup |

**Pricing.** Hold $4.99 / $29.99 through the redesign so its effect can be read. Annual stays the
selected plan with the yearly total as the largest price; monthly is one tap away. No lifetime
plan, no exit offer, no countdown. The price step in `REVOLUTION_PLAN.md` stays tied to email
import.

**What Pro unlocks** stays exactly as `ProFeature` lists (unlimited subscriptions, Pause Plan, deep
analysis, cheaper alternatives), so the paywall, the code and `metadata/` stay in agreement. The
free tier keeps reminders, verdicts, cancel help and the receipt.

**Not doing:** fake urgency, a hidden close button, guilt copy, pre-ticked extras, paywalls on the
verdict or the receipt, ads, data sales, bank linking.

---

## 6. Measuring without trackers

- **App Store Connect** (no code): first-time downloads, trial starts, trial-to-paid, renewals and
  refunds by app version. The redesign ships as its own version, so before and after are separable.
- **Campaign links and offer codes** for share cards and creators.
- **Anonymous daily counters** (needs a decision, section 9): the app adds one to a named counter
  ("reached reveal", "saw paywall", "started trial") through a Supabase edge function. No user id,
  no device id, no IP stored; only date, counter name, app version and a count.
- **On-device funnel log**, visible to the user in Settings › Privacy, so the claim "no trackers"
  can be checked by anyone.

Limits, stated plainly: with today's install numbers, a paywall change needs weeks to show a
difference that isn't noise, and there is no true A/B test without a server. Versions are compared
in sequence, and seasonality (December, January) will blur it.

---

## 7. Build order

**Reordered again 2026-11-10: the founder asked for everything to be redesigned.** Value still
leads, but nothing is built twice: the design system comes first, and the two screens that decide
whether people pay (the Tally and the paywall) are the first screens built in it. Screenshot Import
waits for real screenshots from the founder; its parser is done.

The honest limit stays: a redesign alone does not make Pausely worth paying for. Automatic finding
(Screenshot Import, mail import in release) does, and both are waiting on the founder.

Branch `redesign`, one commit per step, each ending with new screenshots, a re-rating, Debug and
Release builds and the serial test run.

| Step | Work | Days | Status |
|---|---|---|---|
| 0 | Truth fixes | 1.5 | **Done** (tour extension still open) |
| 1 | **Design system**: Ink and Paper tokens, type, motion, haptics, paper slip, buttons; old tokens mapped onto the new ones so every screen shifts at once; letter-spacing removed | 2 | **Done** |
| 2 | **First run**: Tally and reveal, account after value, splash 0.6 s, logos redrawn | 3 | **Done** except the reminder ask (moves to Home, step 4) |
| 3 | **Paywall** from the user's own numbers, trial timeline, Pausely on its own slip, free-limit choice, Promise meter | 3 | |
| 4 | Home: the number, next decision, 30-day horizon, kept | 2 | |
| 5 | Verdict slip, tear to cancel, receipt roll, share image | 3 | |
| 6 | Subscriptions list, detail, add and edit, catalog browser | 3 | |
| 7 | Insights, Profile, Settings, Pause Plan strip, Wrapped | 3 | |
| 8 | Sign in, sign up, age check, inbox import screens, empty and error states | 2 | |
| 9 | Tab bar and glass, widgets, Live Activity, Sunday slip | 3 | |
| 10 | Screenshot Import: text recognition and confirm screen (parser done) | 3 | Needs real screenshots |
| 11 | Outlook and iCloud mail import in release | 1 + owner | Blocked on `MS_CLIENT_ID` |
| 12 | Counters (if approved), share links | 1 | |
| 13 | Full pass in five languages, right to left, largest text, VoiceOver, iPad; Release build | 2 | |
| | **Total** | **32.5** | |

**Cut line:** steps 1 to 5 (13 days) are a shippable release: new identity, new first run, new
paywall, new core loop. Steps 6 to 9 finish every remaining screen.

**What step 0 changed**
- Forecast: a subscription with no usage logged is no longer treated as unused (it suggested an
  89% cut). Covered by `SpendingForecastTests`.
- Cancel Timing: the "wait for better timing" advice and the consumed/remaining amounts are gone.
  The card now states the next charge in the subscription's own currency and the day to cancel by.
- Lifetime Cost: the red "Keep until retirement" line is removed.
- Wrapped: says what the current list costs a year, not what was "spent".
- Paywall: the billed price is the largest price; the trial and per-month equivalent sit below it.
- Translations: plan names, "Save N%", tab names, "Today", "Tomorrow", "Overdue", "in N days" and
  the Pause Plan row now appear in all five languages. `LocalizationGuardTests` now understands
  a literal percent sign.

---

## 8. The plan, criticised

Written as the toughest reviewer I can imagine, with what changed in response.

- *"Paper is a gimmick, and white paper on a dark app will glare."* Paper is limited to three
  places and toned warm grey. If the first build of the slip does not rate 9.0, the metaphor is cut
  back to typography and a perforation line.
- *"A tear gesture is hidden, and unusable with VoiceOver."* Keep and Cancel are always buttons.
  The tear is the animation of the result, not the way to trigger it.
- *"The Tally shows catalog prices that are known to be outdated or invented."* It is the largest
  risk in the plan: a wrong number in the first minute destroys trust. So: only the top 30 services
  per storefront, each price checked by hand against the official page before shipping, labelled
  "typical price", editable in one tap, and the reveal says "about" until confirmed. Where no
  checked regional price exists, the service asks for the price instead of guessing.
- *"A paywall straight after the reveal is bait."* It is shown once, with "Continue free" at equal
  weight to the trial button and the close button where it is today. Nothing in the Tally is taken
  away for choosing free except watching more than five.
- *"Moving sign-up after the reveal fights the code: local data belongs to one account."* True
  (`LocalUserData.claim`). The Tally's list is held in memory until the account exists and is then
  saved through the normal path. Using the app with no account at all is out of scope.
- *"You cannot measure any of this."* Partly true; section 6 says what can and cannot be read.
- *"Twenty-five days for six languages is optimistic."* The cut line exists for that reason, and
  every step includes its own translations, so nothing piles up at the end.
- *"Ten monetization ideas is nine too many."* Ideas 1 to 5 ship with the redesign. Ideas 6, 8 and
  9 follow in steps 3 and 8. Idea 7 is separate work. Idea 10 is mostly App Store Connect setup.
- *"Dark only, in 2026?"* Light mode doubles the visual work. Paper gives the app its light
  moments. Light mode stays in `REVOLUTION_PLAN.md` for later.

---

## 9. Founder decisions

1. **Account after the reveal** (recommended) or before it, as today.
2. **Age check:** keep the date-of-birth wheel, placed at account creation, or change its form.
   This is a legal choice.
3. **Free limit:** keep 5 (recommended) or test 3.
4. **Anonymous daily counters** in Supabase: a new table, an edge function and one line in the
   privacy policy. Yes or no. Without them, measurement is App Store Connect only.
5. **Pausely adds itself to the list during its trial** and reminds two days before it ends
   (recommended). Also confirm in App Store Connect whether the monthly plan carries the trial.
6. **Prices:** hold through the redesign (recommended).
7. **Ship 1.0.3 first**, unchanged, and release the redesign as 1.1 (recommended).
8. **Public material** changes after the build: app icon, screenshots, listing text. I will propose
   them; nothing is pushed to App Store Connect without a go-ahead.
9. **The "900+ cancel guides" and "1,000+ services" claims** in the listing: correct them to the
   real counts in the next submission, once counted.

---

## 10. What I could not verify

- **Empty states, the add flow and the sign-up form** were not captured: demo mode always has data
  and the tour did not find the add button. Step 0 fixes the tour.
- **The onboarding carousel:** the tour showed one static welcome screen on every swipe. Either the
  UI-test flag skips the carousel or swiping does nothing; I have not determined which.
- **Real logos on the Subscriptions list:** letter avatars may be a simulator network effect.
- **Paywall prices** came from the StoreKit test configuration (USD), not a real storefront.
- **The cancel-guide and catalog counts** behind the listing claims.
- **Benchmarks** marked "vendor" or "secondary" above are direction, not proof. The Blinkist figure
  has no primary source.
- **Real devices:** haptics and the tear moment can only be judged on an iPhone.

---

## 11. Coverage: no old UI may remain

`scripts/old_ui_check.sh` lists every Swift file that still uses a pre-redesign colour, font,
gradient, glow, glass card, button style or haptic. The redesign is finished when it prints
"0 files" and every screen is rated 9.0 or more (the `pausely-design` skill has the method).

| Date | Files with old UI | Note |
|---|---|---|
| 2026-11-10 | 71 | After steps 1 and 2. New and clean: first run, splash, service logos, design gallery. The onboarding carousel is deleted. |

Rated on screen so far (English; Arabic and largest text checked for the reveal):

| Screen | Score | Weakest point |
|---|---|---|
| Guess | 8.7 | System slider is plain; nothing on screen moves until touched |
| Tally | 8.8 | A few logos fall back to a letter; grid is competent, not distinctive |
| Reveal | 9.1 | At the largest text size the bottom bar takes a third of the screen |

Typical prices on the tally come from news round-ups dated April to September 2026, not from each
service's own price page, and local prices outside the US are a single factor per currency
(CAD 1.05, AUD 1.1, GBP 0.75, EUR 0.8). Currencies without a factor get no guess: the person
types the price. The founder should check the 27 prices before release.

---

## Sources

1. MacStories, Bobby review: https://www.macstories.net/reviews/bobby-subscription-tracking-made-easy/
2. Bobby on the App Store: https://apps.apple.com/app/bobby-track-subscriptions/id1059152023
3. Rocket Money fee explained: https://www.fincomparelab.com/reviews/rocket-money-review/
4. Rocket Money on Trustpilot and ComplaintsBoard: https://br.trustpilot.com/review/rocketmoney.com · https://www.complaintsboard.com/rocket-money-b133631
5. Tracker roundups (vendor sites): https://www.subtracker.io/best/best-subscription-tracker-apps · https://resubs.app/resources/best-subscription-tracker-apps
6. C+R Research via CNBC: https://www.cnbc.com/2022/09/06/consumers-underestimate-monthly-subscription-costs-by-at-least-100.html
7. CNET 2026 survey: https://www.wfsb.com/2026/07/16/average-american-now-spending-111-month-subscriptions-study-finds/ · CNET 2025: https://thedesk.net/2025/05/cnet-subscription-survey-2025/ · Self Financial and West Monroe figures as reported at https://gcn.com/?p=21150
8. RevenueCat, State of Subscription Apps 2026: https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026 · https://www.revenuecat.com/state-of-subscription-apps-2026/
9. Blinkist trial reminder: https://b2bpricinginsights.substack.com/p/4-min-read-how-blinkists-new-paywall · replication: https://blog.curtisherbert.com/slopes-diaries-39-risky-business/
10. Superwall, multi-page onboarding paywalls: https://superwall.com/blog/new-postmulti-page-onboarding-paywalls-convert-37-better-than-single-page-heres-why.md
11. Adapty, personalised paywalls: https://adapty.io/blog/how-to-personalize-onboarding-and-paywalls-in-your-mobile-app/
12. Apple, auto-renewable subscriptions: https://developer.apple.com/app-store/subscriptions/
13. RevenueCat, toggle paywall rejections: https://www.revenuecat.com/blog/growth/rip-toggle-paywall
14. Apple Design Awards 2026: https://www.apple.com/newsroom/2026/06/apple-reveals-winners-of-the-2026-apple-design-awards/
15. Spotify Wrapped analyses: https://newsletter.levelingup.com/p/behind-scenes-spotify-wrapped-became-viral-sensation
16. Duolingo on its widget: https://blog.duolingo.com/widget-feature
