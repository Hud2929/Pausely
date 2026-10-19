# Pausely - App Store Listing (English master)

> **Generated file. Do not edit by hand.** Source of truth: `scripts/store_copy.py` (copy) and `scripts/store_locales.py` (per-locale name, subtitle, keywords).
> Regenerate with `python3 scripts/store_copy.py --write`; verify with `python3 scripts/store_copy.py --check` and `asc metadata validate --dir ./metadata --subscription-app`.
> Everything below describes only what the app does today. See **APP_STORE_LISTING_PLAN.md** for the full store, ASO and account plan.

## App information (en-US)

| Field | Value | Length |
|---|---|---|
| Name | Pausely: Subscription Tracker | 29/30 |
| Subtitle | Trial & Renewal Reminders | 25/30 |
| Keywords | `cancel,find,alert,manager,manage,forgotten,hidden,bill,cost,recurring,payment,price,increase,track` | 98/100 |
| Promotional text | see below | 151/170 |
| Primary category | Finance (Personal Finance) | |
| Secondary category | Productivity | |
| Price | Free, with in-app subscription (Pausely Pro) | |
| Support URL | https://pausely.pro/support.html | |
| Marketing URL | https://pausely.pro | |
| Privacy Policy URL | https://pausely.pro/privacy.html | |
| Terms of Use (EULA) | https://pausely.pro/terms.html (linked in the description; also set as a custom EULA or keep Apple's standard) | |

## Promotional text
```
Never be surprised by a renewal again. Track every subscription, get alerts before free trials end and prices rise, and see what each one really costs.
```

## Description
```
Know exactly what you pay for, and when it renews.

Pausely keeps every subscription in one calm, simple place. It warns you before free trials end, prices go up, or a renewal catches you off guard.

WHAT YOU GET
• One clear dashboard with your weekly, monthly and yearly spend, your next payment and the bills due this week
• 1,000+ popular services to add in seconds, or paste a link and Pausely recognizes the service
• Renewal reminders 1, 3 or 7 days before, whichever you choose
• Free-trial protection: track trial end dates and get alerted before you are charged
• Price history for every subscription, with an alert when a price goes up
• Direct links to the cancellation page for 900+ services, plus difficulty ratings from other users
• Cheaper alternatives for the services you already pay for
• Cost per hour of use, so you can see what is really worth keeping
• 140+ currencies with automatic conversion
• Home Screen widgets, Shortcuts actions and Face ID sign-in
• Your Subscription Wrapped: a year of subscriptions at a glance
• Export your data whenever you like

FREE AND PRO
Track up to 2 subscriptions for free. Pausely Pro unlocks unlimited subscriptions, savings insights, cheaper alternatives and the guided cancel flow.

PRIVATE BY DESIGN
No ads, no third-party trackers, and we never sell your data.

Available in English, French, Spanish, German, Japanese and Arabic.

SUBSCRIPTION INFO
Pausely Pro is an auto-renewing subscription, billed monthly or yearly. Payment is charged to your Apple ID account at confirmation of purchase. The subscription renews automatically unless it is canceled at least 24 hours before the end of the current period. You can manage or cancel it in your Apple ID account settings after purchase.

Terms of Use: https://pausely.pro/terms.html
Privacy Policy: https://pausely.pro/privacy.html
Support: pausely@proton.me
```

## What's New (version 1.0.3)
```
Welcome to Pausely. Track your subscriptions, get renewal and free-trial alerts, and see what each one really costs.
```

## Screenshot captions (en)
1. Every subscription in one calm place
2. Alerts before trials end and prices rise
3. See what each one really costs
4. Add 1,000+ services in seconds
5. Find cheaper alternatives
6. Your year in subscriptions

## Pausely Pro (auto-renewing subscription group `com.pausely.premium`)

| Product | ID | Period | Price (USD, intended) |
|---|---|---|---|
| Monthly | `com.pausely.premium.monthly` | 1 month | 9.99 |
| Annual | `com.pausely.premium.annual` | 1 year | 79.99 |

The 7-day free trial is configured as an introductory offer in `appstore_products.json`. **Whether it exists in App Store Connect is unverified**; check before using the word "trial" in screenshots or the description's offer wording. Verify the live prices in App Store Connect (an earlier check found $4.99 monthly with a scheduled change to $9.99).

## App Review notes (paste into App Store Connect; credentials go ONLY in the App Review Information fields there)
```
Pausely helps people keep track of their subscriptions and avoid surprise renewals. FREE: track up to 2 subscriptions with renewal reminders. PRO (auto-renewing subscription): unlimited subscriptions, savings insights, cheaper-alternative suggestions and the guided cancel flow. Subscription auto-renews unless cancelled at least 24 hours before the end of the period; manage or cancel in Settings > Apple ID > Subscriptions. Sign in with Apple or email is available; a review account is provided in the App Review Information section of App Store Connect (credentials are NOT stored in this repository).
```

## What this listing must never claim
- "Smart Pause", automatic pausing, or "AI-powered" anything: the app does not do these.
- User counts, ratings, awards, press quotes, testimonials, or average-savings numbers: unreleased app, nothing is measured.
- Gmail / email receipt scanning, until Google approves the restricted `gmail.readonly` scope and the feature ships to everyone.
- Importing subscriptions "from the App Store": iOS does not allow one app to read another app's subscriptions.
- Competitor or Apple trademarks in any field; the word "free" or "app" in the keyword field.
- Prices in the description (Apple shows the localized price from the in-app purchase).

## Other languages
Each locale has its own name, subtitle and keywords (see the matrix in APP_STORE_LISTING_PLAN.md). Files: `metadata/app-info/<locale>.json` and `metadata/version/1.0.3/<locale>.json`.

| Locale | Name | Subtitle | Keywords |
|---|---|---|---|
| en-US | Pausely: Subscription Tracker | Trial & Renewal Reminders | 98 chars |
| en-CA | Pausely: Subscription Tracker | Trial & Renewal Reminders | 98 chars |
| en-GB | Pausely: Subscription Tracker | Trial & Renewal Reminders | 98 chars |
| en-AU | Pausely: Subscription Manager | Find & Stop Hidden Charges | 99 chars |
| fr-CA | Pausely: Suivi d'abonnements | Gestionnaire et rappels | 100 chars |
| fr-FR | Pausely: Suivi d'abonnements | Gestionnaire et rappels | 96 chars |
| es-MX | Pausely: Gestor Suscripciones | Control y recordatorio de pago | 96 chars |
| es-ES | Pausely: Gestor Suscripciones | Control y recordatorio de pago | 96 chars |
| de-DE | Pausely: Abo Tracker & Manager | Abos verwalten & kündigen | 96 chars |
| ja | Pausely - サブスク管理・解約リマインダー | 更新日と値上げを通知・固定費を見える化 | 57 chars |
| ar-SA | Pausely: إدارة الاشتراكات | تذكير التجديد، تتبع الفواتير | 65 chars |
