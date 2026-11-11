# The gold standard, and the plan to reach it

Started 2026-11-11. The founder's bar: every screen, the experience as a customer meets it, and the
codebase itself each score **9.5 or more, with no exceptions**. This file is the standard, the plan
and the running scorecard. `REDESIGN_PLAN.md` and `INBOX_PLAN.md` hold the history that led here.

Limits that stay in force: nothing is pushed, merged to `main`, submitted, or written to the live
Supabase database or App Store Connect. Money goes through `Core/Money`; dates and reminders follow
`ENGINEERING_RULES.md`; no dark patterns.

## 1. How anything is scored

- 0 to 10, **never rounded up**. A score needs evidence that can be pointed at: a capture that was
  opened and read, a test that can fail, a number a script printed. "Not seen" is not a score.
- A thing's score is the mean of its dimensions, **capped at its weakest dimension plus 0.5**.
  So 9.5 needs every dimension at 9.0 or more.
- What the numbers mean: **9.5** a design-award jury or a senior reviewer finds nothing to fix in
  five minutes, and a first-time user does the job without stopping to think. **9.0** one small flaw
  a professional would notice. **8** flaws an ordinary user notices. **7** it works but looks or
  reads unfinished. Below that it is not shippable.
- If something cannot reach 9.5 for a reason outside the code (an approval that hasn't come, a
  device that isn't here), it is listed as such with its true score. It is never rated up.

## 2. The standard for a screen (eight dimensions)

| Dimension | 9.5 means |
|---|---|
| Purpose | One job, understood in three seconds; one main action. |
| Truth and need | Every sentence and number has a source; nothing could be removed without loss (`pausely-design`, "Truth and need"). |
| Hierarchy | The eye lands on the one thing that matters, then the action; nothing competes. |
| Identity | Unmistakably Ink and Paper: ink ground, paper only where money is decided or proven, mint only for money kept, serif for the question or number, mono for proof. |
| Craft | Spacing on the scale, edges aligned, type consistent, every state designed (empty, loading, error, full). |
| Accessibility | VoiceOver reads it as sentences; works at the largest text size without clipping; targets 44 pt; contrast AA; passes the system accessibility audit. |
| Reach | Correct in Arabic (right to left) and the four other languages; correct on iPad. |
| Feel | Responds at once; motion and haptics only where they mean something; honours Reduce Motion. |

Evidence a screen needs before it is called done: opened and read in English, Arabic, the largest
text size and iPad, in every state it has; the system accessibility audit passes on it.

## 3. The standard as a customer (role-played, in rounds)

Six people, each walked through the real app from captures of the real flows:

1. **The searcher**: found it searching "subscription tracker", has nine subscriptions, pays for nothing yet.
2. **The sceptic**: was burned by an app that sold data; reads every privacy sentence; decides whether to connect email.
3. **The Arabic speaker**: phone in Arabic, pays in riyals.
4. **The low-vision user**: largest text size, VoiceOver for some steps.
5. **The returner**: thirty days in; a reminder arrives; keeps one, cancels one, looks at what was saved.
6. **The buyer**: at the paywall, deciding whether $29.99 a year is worth it.

Each rates seven things: the first 90 seconds, trust, effort, clarity of what it does for me, would
I pay, would I come back, would I tell someone. Every persona's journey must reach 9.5. A round is:
walk, write down every hesitation and doubt, fix them, walk again. At least three rounds.

## 4. The standard for the codebase (ten dimensions)

| Dimension | 9.5 means | How it is measured |
|---|---|---|
| Truth | No data or copy the app cannot stand behind (invented prices, plans, scores, steps). | Truth audit ledger at zero; claims tests. |
| No dead code | No unused declaration, file, asset, string key, entitlement or document. | `scripts/gold_check.sh` dead-code and clutter checks. |
| Correctness | The engineering rules hold everywhere; no known bug. | Guard tests; engineering audit ledger at zero. |
| Tests | Every piece of logic has a test that can fail; nothing skipped on every run; all green three runs in a row, serially. | Test run output. |
| Translation | Every string a person can see exists in all five languages. | A guard test over every literal, not only `L10n.string`. |
| Accessibility | Every screen passes the system audit. | The screen tour runs the audit. |
| Privacy and security | No secret in the repository; every privacy sentence held by a test; no entitlement the app doesn't use. | `InboxPrivacyTests`, secret scan, entitlement check. |
| Naming and consistency | Names say what things are; one pattern per job. No "Revolutionary", "Luxury", "Genius". | Hype-name check. |
| Size and simplicity | No file is large without a reason; data files hold only what is used. | Line counts in the scorecard. |
| Repository | The root holds what a newcomer needs and nothing else; every document is current. | Clutter check. |

## 5. The plan

Each phase ends in commits, a green test run, and an updated scorecard (section 7). Every finding
from the scan goes into the ledger (section 6) and is closed there, so nothing is fixed from memory.

### 5.1 The run to 9.5 (set on the evening of 2026-11-11)

The founder's instruction: "dont come back unless everything is above a 9.5 no exeptions ... i dont
care how long it takes". This is the order of work until section 7 shows 9.5 or more on every line.
The phases further down are the same work seen by kind; this is the order it is done in.

**How every slice is done.** One ledger item, or one tight group, at a time. A slice is finished only
when all five are true: (1) a test that fails without the fix, (2) the affected test classes green,
serially, (3) the ledger row closed with its evidence, (4) a commit that holds only that slice,
(5) section 5.2 updated. No parallel agents. Nothing is scored from memory: a score is written from a
capture that was opened and read, or from what a script printed. A step the session's safety check
refuses is written into 6.7 with the one line that would allow it, and the run goes on to the next
slice; a refusal is never routed around. The live project is changed only where the founder asked.

**Stage A. Getting in (6.1a).** G3 with B15 and B16 as one piece of work: after sign-out, account
deletion or a reinstall, nothing of the last person is left and the app starts signed out. G4: leaving
"Create your account" returns to the reveal with the list intact. Exit: a clean install walked on the
simulator from the first screen to the home screen, and a reinstall that opens on the first screen.

**Stage B. Data that can be lost or exposed (6.2).** The sync queue as one design, not four patches
(B2, B3, B4, B10): changes are kept in order per subscription and joined (an edit after an unsent add
becomes one add; a delete after an unsent add becomes nothing), the queue drains after every change,
on foreground and when the network returns, a failure backs off and is shown, and nothing typed is
dropped when the server answers. Proven against a stand-in transport that can fail, stall and answer
out of order. Then B5 (rates read and written on one actor) and T62 (cancel help by exact service,
never "name contains"). Exit: the 6.2 table is empty.

**Stage C. Money, dates and claims (6.3).** One definition of "active" used by Home, Insights, the
paywall and the year slip (B17, T41). The billing anchor is never overwritten by Pause Plan (B9).
`startDate` saved (B14). Paywall retries, notices refunds and expiry while running, and prices
Pausely's own line from the store (B11 to B13). Stale rates are said to be stale and converted totals
say "about" (B18, T95). A renewal date the person never entered is never saved as theirs (T71, T75).
"Went up" only for a real price rise (T5, T45 to T47). Forecasts worded as forecasts (T15 to T19, T23,
T43). "Open cancellation page" opens the service's page or says there is none (T59, T66, T72 to T74).
Pause Plan lists streaming only (T96). The rule breaks listed in 6.3. Exit: the 6.3 table is empty and
`CurrencyGuardTests` is green.

**Stage D. Truth and words (6.4).** The in-app Privacy Policy and Terms are removed in favour of the
website's (T50 to T56), which also ends the translation guard's 36 failures. Cancel steps, phone
numbers and the rating sheet cut to what is sourced and visible (T60, T61, T63). First-run prices
either sourced from the service's page or shown as typical and never saved as confirmed (T42, T76).
The catalog cut to what is true and used (Scope C). "Deep savings analysis" rebuilt on real figures or
removed (T25 to T33). Paywall wording (T34 to T38). Every string a person can see in all five
languages, with plural forms (T97 to T99, T80 to T86, T70, T67, T89). Unused keys deleted (T101). One
name for each thing (T102 to T108). Exit: the truth ledger is at zero and the translation guard is green.

**Stage E. Every screen (6.5).** A launch argument for each of the 136 states. The tour run in four
variants (English, Arabic, the largest text size, iPad), Apple's audit inside it brought to zero
issues, the system-wide items fixed (accent colour, Reduce Motion, the iPad column, one way to leave a
sheet, sentence case, formats in the app's language, the serif in Arabic and Japanese). Each screen is
then scored on the eight dimensions from contact sheets that were opened, and repaired or rebuilt
until it reaches 9.5. Exit: section 7 lists every screen at 9.5 or more, each with its evidence.

**Stage F. What makes it worth paying for.** The first customer round scored "would I pay" at 6
because the verdict shows the price times twelve and nothing more. Before the customer rounds are run
again, the verdict gets the facts a person cannot work out alone and that the app truly has: hours
typed in against the price (cost per hour), the price history ("$2 more than a year ago"), how many
times it has been kept, and what cancelling has saved so far. Nothing invented, nothing estimated
without saying so. Exit: the buyer and the returner (section 3) score "would I pay" at 9.5.

**Stage G. Engineering hygiene (6.6).** Test bundles get their own bundle ids, the scheme runs
serially, strict concurrency on, one owner of StoreKit state, the large files split where there is a
reason to, the hype names renamed. Exit: `gold_check` prints zero.

**Stage H. Customer rounds (section 3).** All six people, each from a clean install, against the live
project where the flow touches it, three rounds at least, fixes between rounds. Exit: every journey at
9.5 on all seven counts.

**Stage I. The store page and the proof.** Listing text and screenshots brought into line with the app
as built (local files). Then three serial green test runs in a row, Debug and Release builds, the
rigs in `scripts/dbtest/` green, and the final scorecard.

**What cannot reach 9.5 from here, however long the run.** These are scored at their true value in
section 7 and listed in 6.7, never rated up: a sign-up by someone outside the project team seen to
work (the automated test was refused; it needs one person with an outside address), VoiceOver and
Sign in with Apple on a real device, and anything that waits on App Review.

### 5.2 Where the run is

Updated at every commit, so the work can be picked up from this file alone.

- Done before the run began: the live database fix, the waitlist function, sign-in settings, mail
  delivery, Apple sign-in (all in 6.1 and 6.1a); B1, B7, B8; G5, G6.
- Now: Stage A, first slice: G3 with B15 and B16.
- Next: G4, then Stage B.

**Phase 0. Scan (read-only).** Four independent audits (dead code, truth, design rules on every
view, engineering) plus mechanical scans. Output: the ledger.

**Phase 1. Gates before fixes.** Write the checks that turn the standard into something a script
prints, and let them fail: `scripts/gold_check.sh` (old UI, dead code, clutter, hype names, design
lint), a translation guard over every literal, the accessibility audit inside the screen tour, a
launch argument for every screen and state so each can be captured.

**Phase 2. Purge.** Dead code and files, stale documents, leftover folders and scripts, unused
assets and string keys, unused entitlements, hype names. Largest first.

**Phase 3. Truth.** Catalog and service data cut down to what is true and used; engine text,
notifications, widgets and shortcuts translated and checked; the claims people rely on (paywall,
privacy, help) each tied to a test.

**Phase 4. Engineering.** Every bug and rule break from the audit, bugs first, each with a test.

**Phase 5. Screens.** Every screen and state through the four-variant tour and the audit; rebuild
or repair until each reaches 9.5; scores recorded only from what was seen.

**Phase 6. Customer rounds.** The six personas, three rounds or more, fixes between rounds.

**Phase 7. The store page (local files only).** Listing text and screenshots brought into line
with the app as built; pushing them is the owner's step.

**Phase 8. Proof.** Everything green three serial runs in a row; Debug and Release build; the final
scorecard; what is left for the owner.

## 6. The ledger

Every finding from the scan, grouped, with its status. The full reports (file and line for each
finding) are kept on the founder's Mac in `private/audits/2026-11-11/`, outside the public repository,
because some describe security bugs: `engineering.md` (B1 to B18 and rule breaks), `truth.md`
(numbered findings), `ui.md` (136 screens and states, findings per file), `dead_code.md`,
`best_apps.md`, `overlooked.md`, and `accessibility_audit_en.txt` (what Apple's audit reported on 94
captures). Numbers below refer to those reports.

### 6.1 Closed

| Date | What | Evidence |
|---|---|---|
| 11-11 | Repository root: 143 stale files and 6 leftover folders removed; the founder's marketing notes moved to `private/` (on disk, not tracked). README rewritten: it claimed bank linking, Firebase analytics, 95% test coverage and an MIT licence. | `gold_check` clutter 90 → 0 |
| 11-11 | Live Activity removed. It could never start (its Info.plist key was in the widget, its switch defaulted to off with no screen), and a 14-day countdown is not what a Live Activity is for. | build, widget tests |
| 11-11 | Entitlements and Info.plist: Screen Time entitlement and usage string, background fetch, an unused background-task id and a misspelt orientation key removed; three duplicate entitlement files deleted; iPhone is portrait only. | Debug and Release build |
| 11-11 | The widget's Info.plist was ignored by git, so a fresh clone could not build. Now tracked. | `git ls-files` |
| 11-11 | Widget "next charge" showed the first subscription in list order with the saved anchor date (a date in the past read "today" every day). Now the soonest real charge; cleared when nothing is active. (truth 90) | `WidgetDataStoreTests` ×4 |
| 11-11 | Referral system removed: a link stored a code that nothing ever used, with live network calls behind it. | `DeepLinkTests` |
| 11-11 | Account links (which carry sign-in tokens and an email) were written to the device log in release builds. (B6) | `DeepLinkManager` |
| 11-11 | Dead code: 100 declarations, 9 files, 34 of 38 saved settings. | `gold_check` dead 96 → 33 |
| 11-11 | Gates written: `scripts/gold_check.sh`, a translation guard over every screen, Apple's accessibility audit inside the screen tour. | 280 → 115 |
| 11-11 | The live database: anyone could mark themselves Pro, read the affiliate record, and read through three old payment views that join account emails. Account deletion was not installed. Fixed by `supabase/APPLY_2026-11-11.sql`, rehearsed on the live project and then applied. | `db_apply.py verify`: 29 of 34 checks failed before, 0 after; the rig passes 565 checks over six starting states |
| 11-11 | The waitlist function could be used to email strangers in bulk. Hourly ceiling, optional CAPTCHA, one reply for every address; deployed (version 24). | `scripts/dbtest/waitlist_function.sh`, 23 checks |
| 11-11 | Security audit (`private/audits/2026-11-11/security.md`): three crash paths on bad server input, formula cells in the CSV export, `swift-crypto` advisory, six private notes on public `main`, an old migration that failed on a fresh database. | tests named in the report; 522 of 523 unit tests pass |

### 6.1a Open: a new customer cannot get in (before everything else)

Found on 2026-11-11 by installing the app clean and signing up against the live project, and by reading
the live settings (`python3 scripts/auth_settings.py show`). Until G1 is closed, no screen's score
matters to a stranger: the customer round below scores "getting in" at 1.

| Id | What | Status |
|---|---|---|
| G1 | The live project still has Supabase's default sign-in settings. Account emails carry a link to `localhost` and no code, codes are 8 digits (the app takes 6), and the built-in mailer delivers only to members of the project, two emails an hour. A stranger pressing "Create account" sees "The email couldn't be sent". Five accounts exist in total. | Closed on the server on 11-11, not yet proven from outside. Account email now goes through Resend with the founder's key (kept in this Mac's Keychain, never in the repository), 100 an hour; `scripts/auth_settings.py show` reads "ok" on every line. An automated sign-up from an outside mailbox was refused by the session's safety check, so the proof still owed is one sign-up with an address that is not a member of the Supabase project. Earlier that day: the codes, wording and return addresses were applied at the founder's word (`scripts/auth_settings.py apply`; all twelve settings read "ok", the previous values are saved in `private/audits/`). Still open: delivery. The built-in mailer reaches project members only, two emails an hour, so a stranger still cannot sign up. Two ways to close it. (a) `supabase/functions/auth-email` sends the email through the mail key the project already holds; it is written and passes 20 local checks (`scripts/dbtest/auth_email_function.sh`) but is not deployed, because the session's safety check refuses a deploy the founder has not named: "deploy auth-email", then `python3 scripts/auth_settings.py hook`, then a sign-up from an outside mailbox. (b) Put the mail key in the project's SMTP settings: `RESEND_API_KEY=... python3 scripts/auth_settings.py smtp`. |
| G2 | "Sign up with Apple" is on both account forms; the Apple provider is switched off on the live project. | Switched on 11-11 at the founder's word (`scripts/auth_settings.py apple`): the provider is on for the app's bundle id. Not yet exercised from a device signed in to an Apple account. |
| G3 | Deleting the app and installing it again opens it on the age check, still signed in: the Keychain outlives the app's files. | open (belongs with B15 and B16) |
| G4 | Cancelling "Create your account" after the first-run reveal lands on a generic "Welcome to Pausely / Get Started" screen, as if the guess and the list had never happened. | open |
| G5 | The sign-up error told people to "check the address" when the address was correct and the mailer had refused it. | closed 11-11: only a malformed address is blamed; three tests |
| G6 | Two of the twelve first-run services showed a letter instead of a logo (ChatGPT Plus had no entry; Google One pointed at a host with a 32-pixel icon). | closed 11-11 in the logo table; to be re-seen on the next capture |

### 6.2 Open: can lose, expose or corrupt a customer's data (first)

| Id | What | Status |
|---|---|---|
| B1 | History file unreadable on a locked phone → "Keep it" from a notification can overwrite the whole Savings Receipt history | closed 11-11: `DeviceFile` tells "missing" from "unreadable"; nothing is saved until the history has been read; six tests |
| B2 | Sync queue drops changes queued while it is sending | open |
| B3 | Edits, cancels and deletes made before a failed add has synced are silently undone | open |
| B4 | The queue only drains on launch or pull-to-refresh, while the app says "It will sync when you're back online"; failures retry forever, silently | open |
| B5 | Currency rates are written off the main thread while every screen reads them (data race) | open |
| B7 | Any `pausely://auth/...` link is accepted without the app having asked for one (sign-in into someone else's account, then the local history is wiped) | closed 11-11: `AuthLinkGate`, seven tests |
| B8 | A password typed on an abandoned sign-up is applied to whichever account next signs in by email | closed 11-11: saved only on the address it was typed for |
| B10 | Fields are dropped the moment an add reaches the server; an edit made meanwhile is overwritten | open |
| B15 | Signing out offline leaves the cached session: the next launch shows the signed-out person's list | open |
| B16 | Name and email are left on the device after sign-out and account deletion | open |
| T62 | Cancel help matches by "name contains": Loom shows Bloomberg's steps, link and phone number (34 wrong companies measured) | open |

### 6.3 Open: wrong money, dates or claims

| Id | What | Status |
|---|---|---|
| B9 | Pause Plan overwrites the billing anchor with "a month after today" | open |
| B11, B12, B13 | Paywall never retries prices after one failure; a refund or expiry is not noticed while the app runs; Pausely's own line can be created at USD launch prices for any country | open |
| B14 | `startDate` is never saved, so "lifetime" always starts the day the row was added | open |
| B17, T41 | Four definitions of "active": Home, Insights, paywall and the year slip show different yearly totals for one list | open |
| B18, T95 | Stale rates are never reported; converted totals are not marked "about" | open |
| Rules | Unconverted fallback in `convertToSelected`; groups ranked in mixed currencies; dates not normalised on update; pause reminder outside the planner; demo flags readable in release; rate host hard-coded; a writable no-op `isPremium` and a dormant client-side Pro grant | open |
| T71, T75, T-RenewalDates | Renewal dates the person never entered are saved as theirs (Shortcut add, add sheet pre-fill, "Add date" = today + 14) | open |
| T5, T45–47 | "Went up" on a currency change or typo fix; year slip counts by `updatedAt` and raw category strings | open |
| T15–19, T23, T43 | Estimates and forecasts stated as fact ("this year", "Back in your pocket", "avoided") | open |
| T59, T66, T72–74 | "Open Cancellation Page" opens a web search for 794 of 994 names; a "pause" that pauses nothing and stops reminders; Shortcuts report wrong status | open |
| T96 | Pause Plan counts Audible, PlayStation Plus and Kindle as streaming | open |

### 6.4 Open: truth and need on screen, translation, the listing

| Id | What | Status |
|---|---|---|
| T60, T61, T63 | 717 unsourced English cancel steps; 68 US phone numbers shown worldwide; a rating sheet whose ratings nobody can see | open |
| T42, T76 | 21 of 27 first-run prices come from press round-ups, not the service's page, and are saved as if confirmed | open |
| Scope C | Catalog: 1,379 invented plan prices, invented descriptions (Pausely's own says "bank sync"), invented websites used for logos, plan variants listed as services | open |
| T25–33 | "Deep savings analysis": English only, invented thresholds, a figure that always equals the price, overlap matched by substring on cancelled items too | open |
| T50–56 | In-app Privacy Policy and Terms: untrue lines (analytics, push, price alerts, a licence to use data), English only, a second copy beside the website's | open |
| T34–38 | Paywall: cancelling Apple's sheet raises "Purchase Error"; restore outcomes all read "Purchase failed"; "Apple ID" path is out of date; two different last days to cancel | open |
| T97–99, T80–86, T70, T67, T89 | Untranslated: the welcome screen's six lines, edit-screen rows, age gate buttons, every Shortcut result, a notification, every widget string; 15 counts with no plural forms ("1 subscriptions") | open |
| T101 | About 940 unused string keys, some carrying old false claims in six languages | open |
| T102–108 | Seven names for Find in Email; "Renewal Verdict" exists only in the listing; five names for Insights; "watch" and "track" | open |
| T109–111, generator | Listing: "with their plans and prices", "900+ cancel links", "weekly spend"; `scripts/store_copy.py` would put "cheaper alternatives" back if run | open |

### 6.5 Open: screens

| What | Status |
|---|---|
| 136 screens and states; 95 cannot be opened by a launch argument, so have not been seen in Arabic, at the largest text or on iPad | open |
| Apple's audit, English tour: 307 issues (105 Dynamic Type, 98 contrast, 51 clipped text, 36 elements not detected, 13 hit regions, 4 descriptions) | open |
| Not rebuilt: both widgets, Pause Plan, age check, policy pages, error banner and toast, demo banner | open |
| System-wide: accent colour is iOS blue; `Motion.unlessReduced` still moves; `StateMark` does not grow; iPad column is 680 pt wide; five ways to leave a sheet; Title Case and sentence case mixed; "iPhone" said on iPad; prices and dates not formatted in the app's language in 43 places; the serif is missing in Arabic and Japanese | open |
| Per-file findings (colour, type, layout, Dynamic Type, right to left, VoiceOver, motion, haptics, states) in `ui.md` | open |

### 6.6 Open: engineering hygiene

Test bundles share the app's bundle id; the shared scheme runs tests in parallel; strict concurrency is
off; project backups and per-user Xcode data are tracked; an empty build-file entry; development
signing identity on Release; the xcconfig files are decoration (real values sit in the project file);
two classes own StoreKit state; 7 Swift files over 700 lines; 17 hype names.

### 6.7 For the owner (cannot or should not be done from here)

- The repository is public. Its history still holds business notes (growth, monetisation, data
  monetisation research) and a committed `backend/.dev.vars`. The values looked like scaffold
  defaults, but if any was ever real, rotate it. Decide whether the app repository should be private
  (the website can live in its own public one).
- The README now says no licence is granted. It used to say MIT with no licence file. Confirm.
- Everything already on the list in memory: Supabase email templates and redirect URLs, the pending
  SQL, the edited listing text and review notes, Microsoft client id, the "go" for 1.0.3.

## 7. Scorecard

Measured, not felt. A score is written only when its evidence exists.

| Area | Now | Evidence | What holds it down |
|---|---|---|---|
| Screens | not scored | 41 of 136 states captured in English only | 95 states unseen; 307 audit issues |
| Customer round 1: the searcher (English, iPhone 17 Pro, clean install, live backend) | **1.5** today; 6.5 once people can get in | Walked 11-11: first run, sign-up against the live project, home, the verdict, cancelling, the confirmation. Captures read one by one. Scores: first 90 seconds 8.5, getting in 1, trust 7, effort 8, clarity 8.5, would pay 6, would come back 7, would tell someone 6. | G1 and G2 (nobody can create an account). After that: the verdict offers the price times twelve and nothing a person couldn't work out alone; "isn't watched" is jargon; the age wheel sits between the reveal and the account. The other five personas and rounds 2 and 3 are not run. |
| Codebase: truth | open findings: about 70 | `truth.md` | 6.3, 6.4 |
| Codebase: dead code and repository | `gold_check` 115 (was 280) | script output | 33 declarations, 940 string keys, data files |
| Codebase: correctness | 16 known bugs open | `engineering.md` | 6.2, 6.3 |
| Codebase: tests | 504 pass, 1 fails by design (36 untranslated lines), 7 need a mail server | test run 11-11 | the failing guard; parallel scheme |
| Codebase: translation | 36 literals + about 60 strings outside the catalog + all widget text | guard test, `truth.md` | 6.4 |
| Codebase: accessibility | 307 audit issues | tour audit | 6.5 |
