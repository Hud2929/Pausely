# Pausely

A subscription tracker for iPhone and iPad (SwiftUI, iOS 18 and later). It reminds you before every
renewal and asks one question each time: keep it or cancel it.

## What it does

- **Reminders before every charge**, and before a free trial turns into a paid plan.
- **Renewal Verdict**: each reminder opens a keep-or-cancel decision with the facts for that
  subscription (what it costs a year, what its renewals have come to, a price rise, the last day to
  cancel).
- **Savings Receipt**: every cancellation is recorded with the charges it avoids over twelve months,
  backed up to your account when you sign in.
- **On-device screenshot import**: pick screenshots of Apple Subscriptions or recurring charges to
  import services, prices, and renewal dates without uploading images or connecting a bank.
- **Pause Plan**: rotate streaming services one month at a time instead of paying for all of them.
- **Everyday details**: split shared family plans, track billing methods and notes, spot overlapping
  services, or use Pausely locally without an account.
- Totals in your own currency, widgets, and six languages (English, Arabic, German, Spanish, French,
  Japanese).

Free: up to five subscriptions (you choose which five), with reminders, verdicts, cancel help,
single-screenshot import and the Savings Receipt.
Pausely Pro: unlimited subscriptions, Pause Plan, batch screenshot import, and cancellation & refund
email drafts. The single list of what Pro unlocks is `Pausely/Services/ProFeature.swift`.

Pausely has no ads, does not sell data and does not connect to bank accounts.

## Building

Open `Pausely.xcodeproj` and run the `Pausely` scheme (Xcode 26, iOS 18 SDK or later). From the
command line:

```bash
xcodebuild build -scheme Pausely -destination "id=<simulator id>" -derivedDataPath /tmp/PauselyBuild
xcodebuild test  -scheme Pausely -destination "id=<simulator id>" -derivedDataPath /tmp/PauselyBuild \
  -only-testing:PauselyTests -parallel-testing-enabled NO
```

Debug builds show "Test without an account" on the welcome screen, so the app can be explored without
a server. To use your own Supabase project, change `SUPABASE_URL` and `SUPABASE_ANON_KEY` in the Pausely
target's build settings (they reach the app through `Configuration/Info.plist`).

## Where things are

| | |
|---|---|
| `CLAUDE.md` | Architecture, commands and launch arguments. Start here. |
| `ENGINEERING_RULES.md` | The rules for money, renewal dates, reminders and what Pro unlocks. |
| `GOLD_STANDARD.md` | The quality bar, how it is measured, and the current scorecard. |
| `REVOLUTION_PLAN.md`, `REDESIGN_PLAN.md`, `INBOX_PLAN.md` | Where the product is going, the design system, finding subscriptions in email. |
| `docs/` | Reference notes: pricing research, store listing plan, App Privacy answers, Google verification. |
| `scripts/gold_check.sh` | The mechanical checks. It must print a total of 0. |
| `supabase/` | Database migrations and the four edge functions. |
| `pausely.pro/` | The website and the published policies. |

## Licence

No licence is granted. The source is published so that what the app does with your data can be read;
all rights are reserved.
