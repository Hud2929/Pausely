# Pausely

A subscription tracker for iPhone and iPad (SwiftUI, iOS 18 and later). It reminds you before every
renewal and asks one question each time: keep it or cancel it.

## What it does

- **Reminders before every charge**, and before a free trial turns into a paid plan.
- **Renewal Verdict**: each reminder opens a keep-or-cancel decision with the facts for that
  subscription (what it costs a year, how long you have paid for it, the last day to cancel).
- **Savings Receipt**: every cancellation is recorded with the charges it avoids over twelve months.
- **Pause Plan**: rotate streaming services one month at a time instead of paying for all of them.
- Totals in your own currency, widgets, and six languages (English, Arabic, German, Spanish, French,
  Japanese).

Free: up to five subscriptions, with reminders, verdicts, cancel help and the Savings Receipt.
Pausely Pro: unlimited subscriptions, Pause Plan and the full savings analysis. The single list of what
Pro unlocks is `Pausely/Services/ProFeature.swift`.

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
a server. To use your own Supabase project, copy `Configuration/Development.xcconfig.template` to
`Configuration/Development.xcconfig` and fill in the project URL and anon key.

## Where things are

| | |
|---|---|
| `CLAUDE.md` | Architecture, commands and launch arguments. Start here. |
| `ENGINEERING_RULES.md` | The rules for money, renewal dates, reminders and what Pro unlocks. |
| `GOLD_STANDARD.md` | The quality bar, how it is measured, and the current scorecard. |
| `REVOLUTION_PLAN.md`, `REDESIGN_PLAN.md`, `INBOX_PLAN.md` | Where the product is going, the design system, finding subscriptions in email. |
| `docs/` | Reference notes: pricing research, store listing plan, App Privacy answers, Google verification. |
| `scripts/gold_check.sh` | The mechanical checks. It must print a total of 0. |
| `supabase/` | Database migrations and the waitlist function. |
| `pausely.pro/` | The website and the published policies. |

## Licence

No licence is granted. The source is published so that what the app does with your data can be read;
all rights are reserved.
