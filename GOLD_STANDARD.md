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

### 6.2 Open: can lose, expose or corrupt a customer's data (first)

| Id | What | Status |
|---|---|---|
| B1 | History file unreadable on a locked phone → "Keep it" from a notification can overwrite the whole Savings Receipt history | open |
| B2 | Sync queue drops changes queued while it is sending | open |
| B3 | Edits, cancels and deletes made before a failed add has synced are silently undone | open |
| B4 | The queue only drains on launch or pull-to-refresh, while the app says "It will sync when you're back online"; failures retry forever, silently | open |
| B5 | Currency rates are written off the main thread while every screen reads them (data race) | open |
| B7 | Any `pausely://auth/...` link is accepted without the app having asked for one (sign-in into someone else's account, then the local history is wiped) | open |
| B8 | A password typed on an abandoned sign-up is applied to whichever account next signs in by email | open |
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
| Customer rounds | not run | | waits for the screens |
| Codebase: truth | open findings: about 70 | `truth.md` | 6.3, 6.4 |
| Codebase: dead code and repository | `gold_check` 115 (was 280) | script output | 33 declarations, 940 string keys, data files |
| Codebase: correctness | 16 known bugs open | `engineering.md` | 6.2, 6.3 |
| Codebase: tests | 504 pass, 1 fails by design (36 untranslated lines), 7 need a mail server | test run 11-11 | the failing guard; parallel scheme |
| Codebase: translation | 36 literals + about 60 strings outside the catalog + all widget text | guard test, `truth.md` | 6.4 |
| Codebase: accessibility | 307 audit issues | tour audit | 6.5 |
