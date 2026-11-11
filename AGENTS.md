# Working in this repository

Everything an agent or a new contributor needs is in three files:

- `CLAUDE.md`: what the app is, how to build and test it, the architecture, the launch arguments.
- `ENGINEERING_RULES.md`: the rules for money, renewal dates, reminders and what Pro unlocks. Read
  it before touching any of those.
- `GOLD_STANDARD.md`: the quality bar and the checks that hold it (`scripts/gold_check.sh` prints 0).

Limits that always apply: nothing is pushed or merged to `main`, submitted to App Review, or written
to the live Supabase database or App Store Connect without the owner saying so.
