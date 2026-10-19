# Pausely: App Store Listing, UI and ASO Plan

Status date: 2026-10-19. Scope: everything a visitor sees on the App Store product page, plus search (ASO) for every language, each tuned to its own country.

**Nothing in this plan has been applied to App Store Connect.** All copy lives in the repo and is validated locally. Applying it needs (1) the Apple account blocker below to be cleared and (2) the owner's OK.

Source files (single source of truth, do not hand-edit generated output):

| File | Role |
|---|---|
| `scripts/store_copy.py` | All store copy in six languages, limits, banned terms, generators |
| `scripts/store_locales.py` | Per-locale name, subtitle, keywords, with the reasoning |
| `metadata/app-info/<locale>.json`, `metadata/version/1.0.3/<locale>.json` | Generated, in the layout `asc metadata push` reads |
| `AppStoreMetadata/<locale>/*.txt` | Generated plain text for proofreaders and translators |
| `APP_STORE_LISTING.md` | Generated English master (what to paste, what never to claim) |
| `ASO_KEYWORD_PLAN.md`, `scripts/aso_scan_*.json` | Competitor research and raw evidence |

Check everything: `python3 scripts/store_copy.py --check` (11 locales, 0 problems) and `asc metadata validate --dir ./metadata --subscription-app --output table` (22 files, 0 errors, 0 warnings).

---

## 1. Blocker first: the Apple Developer account

**What is wrong.** Every App Store Connect API call returns `A required agreement is missing or has expired.` That is an account-level block, not a bug in this repo. It stops metadata upload via `asc`, in-app purchase and subscription setup, and (until fixed) submission and selling anything.

**Importance: critical.** Nothing else in this plan can ship until it is cleared. It is also the cheapest item: a few minutes for the right person.

**Who can fix it.** Only the **Account Holder** of the developer team can accept agreements. Admins and the API key cannot. The team in `Pausely.xcodeproj` is an *individual* membership, so the Account Holder is a single named person and that name becomes the public seller name on the App Store. Confirm that the person signing in to developer.apple.com is that Account Holder (see section 9, decision 1).

**What to do (Account Holder, about 15 minutes):**

1. Sign in at https://developer.apple.com/account with two-factor authentication. Accept any banner reading "Review the updated Apple Developer Program License Agreement".
2. Open Membership details and confirm the membership is **active and not expiring** (annual renewal). An expired membership produces this same API error.
3. Sign in to https://appstoreconnect.apple.com, then **Business** (Agreements, Tax, and Banking). Accept anything marked "New Terms". Under Paid Apps Agreement, complete: contact roles, bank account, tax forms. **Subscriptions cannot be sold without an active Paid Apps Agreement.**
4. Re-run `asc apps list`. When it returns the app instead of the error, the block is cleared.

**What I will do next once it is clear** (and only with the owner's OK, since it changes a live account):

1. `asc apps list`, then `asc metadata pull` to see what is currently in App Store Connect and diff it against `metadata/`.
2. `asc metadata push --dry-run`, review the plan, then push.
3. Create or fix the subscription group, localizations, prices and the 7-day introductory offer (section 5).

---

## 2. What was wrong with the old listing, and what changed

The old `APP_STORE_LISTING.md`, `AppStoreMetadata.md` and `PromotionalText.md` promised things the app does not do. Apple's App Review Guidelines (2.3 accurate metadata, 3.1.2 subscription disclosure, 5.6 developer conduct) treat that as a rejection reason, and after launch as a removal risk.

| Old claim | Reality | Now |
|---|---|---|
| "Smart Pause", pause recommendations | Not shipped | Removed everywhere, including in-app text (Pro card, Help FAQ) |
| "Join thousands of users" | Unreleased app | Removed |
| Testimonials (named people) | Fabricated | Removed |
| "AI-powered" alternatives, "AI insights" | Rule-based | Removed from metadata, onboarding and the sandbox StoreKit file |
| "$240/year average savings" | Never measured | Removed |
| Gmail / email scanning | Under Google review | Not mentioned until Google approves |
| `pausely.app` URLs, support@pausely.app | Wrong domain | `pausely.pro` pages that exist (privacy, terms, support) |
| Review password in a public repo | Security leak | Removed. **Rotate it** (section 9, decision 3) |

Claims that remain are each backed by code: 1,000+ catalog services, 900+ cancel links with difficulty ratings, 140+ currencies, renewal reminders, trial tracking, price history, cheaper alternatives, cost per hour, widgets, Shortcuts, Face ID, Subscription Wrapped, data export, and a free tier of 2 subscriptions.

---

## 3. ASO: how each country is handled

Rules that drive every decision:

- Only **name (30), subtitle (30) and keywords (100)** are indexed. The description is not, so it is written to convert, not to rank.
- Words are never repeated across name, subtitle and keywords (no benefit, wastes characters). Keywords are singular, comma-separated, without spaces.
- Apple indexes **two localizations per storefront**. So paired storefronts get complementary vocabularies, which roughly doubles the searchable words:
  - United States: `en-US` + `es-MX`
  - Canada: `en-CA` + `fr-CA`
  - United Kingdom and Australia: `en-GB` + `en-AU` (deliberately different keyword sets)
  - Germany: `de-DE` + English
- Apple publishes no search volume. Difficulty here is a proxy: the **median rating count of the top 5 results** for each term, measured live from the iTunes Search API on 2026-10-19 (`scripts/aso_scan_*.json`). Low number means a new app can realistically rank.
- No competitor names, trademarks, "free" or "app" in any field.

### Per-locale matrix

| Locale | Storefronts | Name | Subtitle | Keywords (extra vocabulary) | Why (evidence, median ratings of top 5) |
|---|---|---|---|---|---|
| en-US | United States | Pausely: Subscription Tracker | Trial & Renewal Reminders | cancel, find, alert, manager, forgotten, hidden, bill, cost, recurring, price, increase, track… | Head terms are brutal (`subscriptions` 171k, `save money` 289k) so the name carries one head term and the subtitle targets winnable ones: `trial tracker` 0, `renewal reminder` 0, `subscription reminder` 0, `subscription cost` 0 |
| en-CA | Canada | same as en-US | same | same | `trial tracker` 0, `recurring payments` 0, `subscription reminder` 0; primary market |
| fr-CA | Quebec | Pausely: Suivi d'abonnements | Gestionnaire et rappels | annuler, essai, renouvellement, facture, recurrent, paiement, cache, oublie, prix, hausse, alerte, cout, trouver (accents omitted: search ignores them) | `suivi abonnements` 0, `rappel facture` 0, `gérer abonnements` 11: essentially open |
| en-GB | United Kingdom | Pausely: Subscription Tracker | Trial & Renewal Reminders | same as en-US | `trial tracker` 0, `renewal reminder` 0, `subscription reminder` 0; `track subscriptions` 27 reachable |
| en-AU | Australia (and extra UK words) | Pausely: Subscription Manager | Find & Stop Hidden Charges | cheaper, alternative, monthly, yearly, spend, saver, unused, waste, payments, money, credit, card, direct, debit | Different name and subtitle from en-GB on purpose: `subscription tracker` 13, `hidden subscriptions` 16, `track subscriptions` 3 |
| fr-FR | France | Pausely: Suivi d'abonnements | Gestionnaire et rappels | resilier first (France says "résilier"), then annuler, essai, renouvellement… (accents omitted) | `suivi abonnements` 1, `annuler abonnement` 1 |
| es-MX | Mexico, Latin America, US Hispanic | Pausely: Gestor Suscripciones | Control y recordatorio de pago | cancelar, renovación, prueba, pagos, recurrentes, rastreador, administrar, gastos, mensual, precio, alerta | `gestor de suscripciones` 0, `recordatorio de renovación` 0, `pagos recurrentes` 0 |
| es-ES | Spain | same as es-MX | same | same (description uses "coste", not "costo") | `recordatorio de renovación` 0, `rastreador de suscripciones` 0, `gestor de suscripciones` 5 |
| de-DE | Germany, Austria, Switzerland | Pausely: Abo Tracker & Manager | Abos verwalten & kündigen | erinnerung, probeabo, verlängerung, wiederkehrend, zahlung, kosten, preis, erhöhung, versteckt, vergessen | Germans say "Abo": `probeabo erinnerung` 0, `abo erinnerung` 1, `kosten abos` 3, `abo manager` 6 |
| ja | Japan | Pausely - サブスク管理・解約リマインダー | 更新日と値上げを通知・固定費を見える化 | サブスクリプション, 定額, 固定費, 解約, 支払い, 契約, 家計簿, 節約, トライアル, 通知, 値上げ… | `サブスク` alone is 1.3M (avoid). `サブスク管理` 286, `サブスク 解約` 0, `解約 リマインダー` 0 |
| ar-SA | Saudi Arabia, UAE, other Arabic storefronts | Pausely: إدارة الاشتراكات | تذكير التجديد، تتبع الفواتير | إلغاء, تجربة, تنبيه, سعر, ارتفاع, دفعات, متكررة, مصاريف… | `إدارة الاشتراكات` 0, `تتبع الاشتراكات` 0, `تذكير الفواتير` 0: the largest relative opportunity |

Exact keyword strings are in `scripts/store_locales.py` and `metadata/version/1.0.3/<locale>.json`.

### Strategy by market
- **Win where competition is ~0:** French (Canada and France), Spanish, German, Japanese long-tail, Arabic. These are low-cost, high-relative-share, and a small app can be #1 for several terms within days of launch.
- **Be selective in English:** compete on trial, renewal and reminder terms that nobody owns, not on `subscription tracker` (1k to 171k ratings).
- **Review translations before launch.** All non-English copy is machine-drafted. Native-speaker review is mandatory for fr, es, de, ja and ar (Arabic also needs a right-to-left screenshot check).
- **Seasonality:** promotional text can change any time without a review (`AppStoreScreenshots/PromotionalText.md`). Keywords and name change only with a new version.

---

## 4. App Store UI: what the product page needs

| Asset | Plan | Status |
|---|---|---|
| App icon | 1024 x 1024, no transparency, no text. Check it reads at small size next to competitors | Exists; re-check |
| Screenshots, iPhone 6.9" | 1320 x 2868, up to 10 per locale; the first three show in search, so they carry the pitch. Order and captions: see below | To produce |
| Screenshots, iPad 13" | Not needed: 1.0 is **iPhone-only** (decided 2026-10-19; `TARGETED_DEVICE_FAMILY = 1`). iPad owners can still install it in compatibility mode | Done |
| App Preview video | 15 to 30 s, in-app footage only (guideline 2.3.4). Script already corrected in `AppStoreScreenshots/PreviewVideoScript.md` | To record |
| Promotional text | 170 chars, per locale, seasonal | Done |
| Description | Per locale, no unsupported claims, Terms and Privacy links, auto-renew disclosure | Done |
| Subscription display names and descriptions | Must exist in **every** metadata locale (today only en-US, es-MX, fr-CA, de-DE exist in `appstore_products.json`; add en-CA, en-GB, en-AU, fr-FR, es-ES, ja, ar-SA) | To do |
| Introductory offer | 7-day free trial exists in the sandbox file; **unverified in App Store Connect** | Verify |
| App Privacy ("nutrition labels") | Must match the code and `privacy.html`: account email, subscription data, age-consent timestamp, purchases. Gmail data is processed on-device only. Build with the `asc-privacy-nutrition-labels` skill | To do |
| Age rating | Answer Apple's current questionnaire honestly; the in-app 16+ gate is a data-consent rule, not the store rating. Earlier notes said 17+: let the questionnaire decide | To do |
| Categories | Primary Finance, secondary Productivity | Set |
| Review information | Notes written (no secrets). Create a **dedicated review account inside App Store Connect only**, never in the repo | To do |
| Custom Product Pages | After launch: variants for the trial-protection and price-hike stories, linked from campaigns | Later |
| In-App Events | After launch: e.g. a "trial season" event around Black Friday | Later |

### Screenshot story (same six frames in every language; caption text is in `CAPTIONS`, localized)
1. Every subscription in one calm place (dashboard)
2. Alerts before trials end and prices rise
3. See what each one really costs (per year, per hour)
4. Add 1,000+ services in seconds
5. Find cheaper alternatives
6. Your year in subscriptions (Wrapped)

Rules: real in-app screens with demo data (use the DEBUG demo launch flags, never a real person's subscriptions); no device frames claiming features that are not there; no Gmail screens until Google approves; localized UI plus localized caption per locale. Generate with the `asc-shots-pipeline` skill after the app is final.

---

## 5. Rollout, measurement and iteration

1. **Before submission:** clear the account block; fix the decisions in section 9; native-review translations; record screenshots and preview; create the review account; set privacy labels and age rating; verify prices and the trial offer; `asc metadata validate`, then dry-run, then push.
2. **At launch:** ship all 11 localizations together. A locale left empty adds no extra indexing for its storefront pair, so the English-only store would lose the paired vocabulary.
3. **Week 1 to 4:** read App Store Connect Analytics (Sources: App Store Search impressions, product page views, conversion rate). Check rank for the winnable terms with `python3 scripts/aso_scan.py --track`. Do not change keywords more than once per version.
4. **Version 1.0.4 and later:** replace keywords that earn no impressions with the next candidates in `ASO_KEYWORD_PLAN.md`. Use a free Apple Ads (Search Ads Advanced) account for keyword **Search Popularity** scores to replace the rating-count proxy with real demand.
5. **Reviews:** follow `AppStoreScreenshots/ReviewPromptStrategy.md` (fixed to not promise anything the app does not do).

---

## 6. Risks and open items

- **Account block** (section 1): critical.
- **Public repository:** it contains internal strategy and, historically, the review password. See decision 3.
- **"Scan from App Store" in the app** (Apple Subscriptions import) could never see other apps' subscriptions, because iOS does not allow it. **Removed from the Subscriptions tab on 2026-10-19.** The unused screens (`AutoDetectView`, `AppleSubscriptionScanner`, `ForgottenSubscriptionsSection`) remain as dead code and can be deleted.
- **Remaining in-app copy** that over-promises (separate from metadata): Help FAQ says data is "encrypted end-to-end"; Profile and Help mention pausing. Audit before submission. Dead screens that still mention Smart Pause or AI (`SmartPauseAlertView`, `FinancialAdvisorView`, `ReferralSuccessView`, `PerksView`, `MVFeaturesScene`) are unreachable but should be deleted.
- **Gmail:** do not market it until Google approves the `gmail.readonly` scope (under review since early October; a security assessment may be required).
- **Prices:** intended $9.99 monthly and $79.99 yearly; App Store Connect was last seen at $4.99 with a scheduled change. Verify.
- **Machine-translated copy:** native review needed in five languages.

---

## 7. Apply commands (after section 1 is cleared and the owner says go)

```bash
asc apps list --output table
asc metadata pull --app APP_ID --version 1.0.3 --platform IOS --dir ./metadata_remote   # see what is live
asc metadata validate --dir ./metadata --subscription-app --output table
asc metadata push --app APP_ID --version 1.0.3 --platform IOS --dir ./metadata --dry-run --output table
asc metadata push --app APP_ID --version 1.0.3 --platform IOS --dir ./metadata
```

Regenerate any time with `python3 scripts/store_copy.py --write`. Never edit the generated JSON by hand.

---

## 8. Done in this pass

- 11 locales of store copy written, limit-checked and validated by Apple's own tool.
- Old English listing, metadata and promo files replaced; outdated docs flagged or corrected.
- In-app Smart Pause and AI claims removed from the Pro card, Help FAQ and onboarding; app builds.
- Keyword and competitor evidence saved (`scripts/aso_scan_locales_2026-10-19.json`).

## 9. Decisions needed from the owner

1. ~~Who is the Account Holder?~~ **Resolved:** a family member. The owner must ask them to sign in and accept the agreements (section 1), or to add the owner as an Admin / Finance role so the owner can help. Only the Account Holder can accept the legal agreements.
2. ~~iPad~~ **Resolved:** iPhone-only for 1.0.
3. **Public repository:** a scan on 2026-10-19 found no live API keys or tokens in tracked files or history (the Supabase anon key in the project file is public by design). The only leak is the old review password in 3 old commits, with 0 forks and 0 stars. Fix: delete or reset the `review@pausely.app` user in Supabase Auth, and create the real review account in App Store Connect only. Keep the repo public (the website and the Google verification pages are served from it); rewriting history would not add protection once the account is gone.
4. **Seller name:** an individual membership shows a personal name on the App Store. If a company name is wanted, plan an organization enrollment (needs a D-U-N-S number).
5. ~~"Scan from App Store" feature~~ **Resolved:** removed.
6. **Pricing:** see `PRICING_PLAN.md` once the owner picks a launch price. The paywall's "Save 17%" badge is computed from hard-coded numbers and must read real StoreKit prices.
