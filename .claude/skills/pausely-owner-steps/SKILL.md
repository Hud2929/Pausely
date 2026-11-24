---
name: pausely-owner-steps
description: Use before telling the owner to do something by hand (run a command, paste SQL, deploy the waitlist function, check a dashboard setting), and when the owner has asked for work on the live Supabase project. Gives the tested procedure for each step, how to verify it, and which steps stay with the owner.
---

# Carrying out the owner's steps

On 2026-11-11 the owner was handed a two-item to-do list (paste a SQL file into Supabase, deploy the
waitlist function) and answered: "do these anything you ask me to do that you CAN do then do and make
that a skill". Both steps could be done from this Mac, because the Supabase CLI here is signed in and
the project is linked. This skill records how, so a step is not handed back when it can be carried out.

## Before handing a step to the owner

1. Check the table below. If the step is there and the owner has asked for that work, carry it out with
   the procedure given and report the evidence.
2. A change to the live project is made only when the owner has asked for that change in the current
   conversation. A general "do everything" from another day does not count.
3. If the session's safety check refuses a step, stop. Do not look for another route. Tell the owner
   what was refused and the one line that would approve it.
4. If the step is the owner's by nature (last section), hand over one step with the exact command or
   link and what they will see when it has worked.

## Procedures that were carried out on 2026-11-11

| Step | Procedure | Evidence that it worked |
|---|---|---|
| Change the live database | Put the change in the newest `supabase/APPLY_*.sql` (and a migration). Then, in order: `bash scripts/dbtest/run.sh`, `python3 scripts/db_apply.py state`, `rehearse`, `apply`, `verify`. | The rig passes; the rehearsal's checklist is all "ok"; `verify` is all "ok". |
| See the live database's shape | `python3 scripts/db_apply.py state` (read-only: tables, policies, triggers, functions, row counts). | It prints. If it differs from the rig's "live" state, update `scripts/dbtest/live_extras.sql`. |
| Deploy the waitlist function | `bash scripts/dbtest/waitlist_function.sh`, then `supabase functions deploy waitlist-signup --project-ref ddaotwyaowspwspyddzs --use-api --no-verify-jwt`. | A GET answers 405 and a POST with a malformed address answers 400. Neither writes anything. |
| See the live sign-in settings | `python3 scripts/auth_settings.py show` (read-only). | Every line says "ok". |
| Push | When the owner says so. For a change to `main` while another branch is checked out, use a separate worktree. | `git ls-remote` shows the new commit. |

## Steps the safety check refused on 2026-11-11

The owner had not asked for these by name. They are prepared so that approving one costs a single line.

| Step | What the owner can say or run | Why it matters |
|---|---|---|
| Set the live sign-in settings (6-digit codes, the email wording, the app's return addresses) | "apply the sign-in settings", or `! python3 scripts/auth_settings.py apply` | Without it the account email carries a link to localhost and no code. |
| Switch on Sign in with Apple | "switch on Apple sign-in", or `! python3 scripts/auth_settings.py apple` | The app shows the button and the server refuses it. |
| Deploy a function other than the waitlist one | Name the function and say "deploy it". | It is new code on the live project. |

## The owner's by nature

- **Anything that needs their password, payment or a new account.** The mail key for account email
  (`RESEND_API_KEY=... python3 scripts/auth_settings.py smtp`, or Supabase dashboard, Authentication,
  SMTP), an LLM key for Strix, a CAPTCHA key, anything the Apple account holder must sign.
- **Decisions.** Whether the repository stays public, prices, what ships.
- **The "go" to submit for App Review.** Never assumed, whatever else has been approved.

## Safety rules

- The rig comes first and the rehearsal comes before the apply. A database change that was not proven
  on the rig's "live" state does not go to the live project.
- Never `supabase db push`: the live project's migrations were applied by hand, its history table does
  not know that, and a push would replay every migration from the first.
- The owner's own email address is never put into a request to any outside service, the project's own
  backend included, without asking.
- Nothing that sends mail to real people, deletes rows that are not test rows, or spends money is done
  unless the owner asked for that thing.
- Report what was done and what was not, with the evidence, including anything that was refused.
