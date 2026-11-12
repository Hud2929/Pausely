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
- Stage A is done (G3, G4, B15, B16), walked on the simulator from a clean install.
- Stage B, sync queue (B2, B3, B4, B10): done. Every change to a subscription goes through
  `SyncQueue`: one pending intent per subscription (add, change or remove), sent as the phone's copy at
  that moment; an add is an upsert so a repeat is harmless; an edit never brings back what another
  device deleted; one account's unsent changes are never sent into another account
  (`LocalUserData.belongs`). Found on the way and fixed: the five change functions were marked as able
  to fail and never could, so seven error paths and three alerts that could never show are gone; a
  hand-typed add at the free limit showed an "Error" alert in English and now opens the paywall (seen
  on the simulator). Proof: 47 tests in three classes against a stand-in account that can be offline,
  refuse and be changed mid-send; the queue's three requests run against the database rules in
  `scripts/dbtest/run.sh` (619 checks); whole suite 559 tests, one failure, the known translation
  guard (D). Not proven: a sync against the real account from the app (needs a signed-in session on
  the simulator, which needs the owner's password or a test account).
- B5 done (currency rates stored on the main thread; see its row).
- T62 done, and T59 with it (see their rows). On the way: the catalog service carried a remote-catalog
  path that could never run (an admin token read from a file that does not exist on a phone); it is
  gone, and the catalog is built in and ready at first use, so the cancel screen and logos no longer
  depend on the browse screen having been opened. Whole suite: 574 tests, one failure, the known
  translation guard (D).
- Stage B is done. Stage C (6.3), top to bottom: B9 done; B11, B12, B13 done, and T34–38 with them
  (one owner for StoreKit). Whole suite 592 tests, one failure, the known translation guard (D).
  Learned: never create an `SKTestSession` or call `AppStore.sync()` in a unit test here. Purchases
  fail with "notEntitled", the real entitlement list never answers, and the simulator is left asking
  for an Apple Account until a plain test pass puts its local store back.
- B14 and B17/T41 done (see their rows).
- B18/T95 done (see its row). Whole suite 594 tests, one failure, the known translation guard (D).
- Rules row: the unconverted fallback and the mixed-currency ranking are done (596 tests, one known
  failure).
- The "pause" that paused nothing is removed (T66, T72–74, T71). Found on the way and fixed: the
  Delete Shortcut removed the first subscription whose name contained what was said ("Apple" with
  Apple One and Apple Music); it now needs a name that means exactly one. 595 tests, one known failure.
- The Rules row is closed. 598 tests, one failure, the known translation guard (D).
- T75 and the "Add date" default are done: no screen fills in a renewal date. 599 tests, one known failure.
- T5 and T45–47 are done (one price history; the year slip counts from the history). 608 tests, one
  known failure.
- Stage C is done: every row of 6.3 is closed. 609 tests, one failure (the translation guard, which
  Stage D closes); Debug and Release build.
- Stage D (6.4) has begun. T50–56 done first because it ended the suite's one failure: 609 tests, 0
  failures.
- T60/T61/T63 done (cancel help holds only what can be checked). 606 tests, 0 failures.
- Every cancellation link was requested and the dead ones repaired (T60's row): 416 of 1,120 were
  dead. 609 tests, 0 failures.
- T42/T76 done: first-run prices are only ones read from the service's own page.
- Scope C done (see its row). The run stopped here on 11-11 when the usage limit was reached.
- 11-11, 23:30: the run resumed. Before any change, the overlooked report was checked against the
  code (rows O1 to O41 in 6.3a) and the rest of the run was planned as one piece: section 5.3. The
  order there replaces the list that stood here.
- D0, first slice: O1, O23, O38, O40 closed (see their rows).
- O36 closed (see its row). Found on the way, for D5: the website exists in three places (the live
  `gh-pages` branch, `site-next`, and the `pausely.pro/` folder on this branch, which lacks files the
  live site has). The privacy correction of 11-11 was made in the folder, so it is in none of the two
  branches a push would publish.
- O39 built (see its row; live only after the owner's key and a deploy). D0 is done. Next: D1, the
  scan of the areas nobody has read (engineering 2, 3, 4, 6, 7, 10; overlooked 5 to 9).
- D1 done: every area is read (scan status under 6.3b). Rows S1 to S16. Fixed at once because they
  lose or expose data: S1, S2, S9, S10, S11. The rest are placed in D3 to D5 and G.
- Whole suite after D0 and D1: 634 tests, 0 failures (7 need a mail server and are skipped).
- D2, typed amounts: O8, O9, O10 closed (see their rows).
- D2, the billing calendar and the day that survives a flight: O2, O3, O4, O5, O7 closed (see their
  rows). S17 closed. Whole suite 660 tests, 0 failures; Release builds. D2 is done.
- D3 begun. The record's unused fields are gone (Scope C's row); the "paused" status (S13) and the
  dead error text (S3) too. "Deep savings analysis" is replaced by what was real in it (T25–33's
  row). The names are decided (T102–108's row) and are applied in D5. D3 is done.
- D4 begun: the free plan counts what is charging (O37).
- D4, notifications: O21, O22, O25, O26, S7 closed; O24 waits on a capability (6.7); O27 accepted.
- D4, widgets: rebuilt (S15's row closes O28 to O30, O33, O34, S6; O35 still to be seen). 695 tests,
  0 failures.
- D4, Shortcuts: rewritten (S16's row closes O31, O32).
- D4, the paywall and the plan: O17 to O20 and O41 closed.
- D4, the verdict's facts (Stage F's build) and S19: the verdict now adds what the renewals have come
  to since the subscription was added (each at the price of its day, never across currencies), takes
  this month's hours right there and turns them into a cost per hour, says "not used this month"
  when that was entered, and promises only what is certain ("Cancel before Nov 17 and you won't be
  charged" replaces "you usually keep it until"). Seen on the simulator. Whether that makes it worth
  paying for is scored by the buyer and the returner in Stage H, not here. 700 tests, 0 failures.
  D4 is done.
- D5 begun, with its foundation: one locale (O11 closed), day wording by the system (part of O12),
  and one unsourced sentence gone from the cancel-timing card ("Most services let you keep using it
  until then"). 705 tests, 0 failures.
- D5, second slice: plural forms (O12), the names applied in the app (T102–108), 1,147 unused keys
  deleted and ten missing ones translated (T101), one more unsourced sentence gone ("Most people pay
  for several streaming services and watch one"). `gold_check` 79 (was 93). Next in D5: the export
  (S14), the German form of address, price and period joined in code (O14), currency names (O13),
  then the listing and the website (T109–111).
- D5, third slice: the export (S14 closed) and one form of address in German (92 sentences, with a
  guard that had to be widened once: commands carry no pronoun). 709 tests, 0 failures. Found while
  doing it, and next: three tab names that mean "house", two words for a subscription in German and
  in Japanese, and Apple's own button named differently from Apple's page in Japanese and Spanish
  (checked against support.apple.com/118428 in each language). So each language is read in full
  before O14 and O13.
- D5, fourth slice (part): the word-by-word read of all five languages, strings 1 to 203 of 784
  read so far. Fixed: the first tab ("Start", "Inicio", "Accueil"), one word for a subscription in
  German ("Abo") and Japanese ("サブスク"; the long forms only where Apple's Settings menu is named),
  cancelling a subscription is "résilier" in French and "解約" in Japanese, never the word for
  dismissing a dialog, the status "Cancelled" ("Storniert" was a reversed payment), Apple's button
  as Apple's own page names it in Japanese and Spanish, one formal Spanish sentence.
  `OneLocaleTests.testASubscriptionAndTheFirstTabHaveOneWordInEachLanguage`. 710 tests, 0 failures.
  Left in this slice: strings 204 to 784 (the dump is rebuilt by the snippet in this session;
  corrections go through a per-language setter), then in English: "payment date" and "renewal
  date" are one thing with two names, "Add Custom", and Title Case on a few buttons and cards.
- D5, fourth slice, finished: all 784 strings read in the five languages (about 190 values
  corrected, list in the T97–99 row) and English brought to one name per thing and sentence case
  (the T102–108 row). German Profile opened on the simulator: tabs read Start, Abos, Einblicke,
  Profil. 711 tests, 0 failures; `string_usage` 0; `gold_check` 78. Next in D5: price and period
  joined in code (O14), currency names (O13), then the listing and the website (T109–111).
- D5, O14 closed: one function gives a price with its period as a phrase in the reader's order.
  713 tests, 0 failures. Next: O13, then T109–111.
- D5, O13 closed: currencies named and found in the reader's language. 714 tests, 0 failures.
  Next: the listing and the website (T109–111), which ends D5.
- D5, the listing (T109–111) closed: eleven locales rewritten to what the app keeps, the stale
  generator deleted, `StoreListingTests` holds it. 721 tests, 0 failures. Next: the website, in
  its three copies (the folder, the live branch, the next-site branch), as local commits only.
- D5, the website: the policy pages, the waitlist page and its welcome email corrected to what the
  app does, `WebsiteTruthTests`, and the three copies brought in line as local commits (`gh-pages`
  and `site-next`, which now descends from it; nothing pushed, nothing deployed). 727 tests, 0 failures;
  `gold_check` 78. **D5 is done, and with it Stage D.** Next: Stage G (hygiene: `gold_check` to 0,
  the scan the other session never did, strict concurrency), then E, H, I.
- Stage G begun: dead code and the TODO check (see 6.6). 727 tests, 0 failures; `gold_check` 61.
  Next in G: hype names (9), then the design lint (colours 18, fonts 13, animations 5, radii 11),
  files over 700 lines (5), strict concurrency, the project file, S4, S5.
- G: hype names closed (6.6). `gold_check` 52. Next: the design lint, one rule at a time.
- G: the design lint closed (6.6). `gold_check` 5. 727 tests, 0 failures. Next: the five long
  files, then strict concurrency, the project file, S4, S5, and the audit sections nobody did.
- G: long files closed (6.6), with the measure's change stated there. **`gold_check` 0.** Next in
  G, none of which the script sees: strict concurrency (58 warnings), the project file (test
  bundle ids, a serial scheme, the ActivityKit leftover, signing on Release), S4, S5, and the six
  audit sections nobody did.
- G: the project file closed (6.6). 730 tests, 0 failures; Release builds. Next in G: S4, S5,
  one owner of StoreKit state, strict concurrency, then the six audit sections nobody did.
- G: S4 closed (its row). 732 tests, 0 failures. Next: S5.
- G: S5 closed (its row). 733 tests, 0 failures. Next: one owner of StoreKit state, strict
  concurrency, then the six audit sections nobody did.
- G: one owner of StoreKit state was already true and is now written down: the tier is set in one
  place (`PaymentManager.updateCurrentEntitlements`, from what `StoreKitManager.entitledTier()`
  says plus the account's grant); `StoreKitManager` keeps products and nothing about what is owned.
- G: strict concurrency closed (S12's row): 58 warnings to 0, and the app and widgets build in the
  Swift 6 language mode. Search results now show the price as one phrase and are found by words in
  the reader's language (they said "$15.49 • Monthly" with English keywords for everyone).
- The note above about six audit sections nobody did is from before D1; D1 read all sixteen areas
  (scan status under 6.3b). Nothing is owed there.
- **Stage G is done**: `gold_check` 0, Swift 6 mode, 734 unit tests and 15 UI tests green, Release
  builds. Not done in G and said in 6.6: the signing identity on Release (the owner's archive).
- **Stage E begun** (11-12, late). Baseline with today's build: the English tour opens 41 screens
  (97 captures, in `/tmp/pausely_tour_en_1112b`, no crash on the Swift 6 build) and Apple's audit
  lists **336** issues: Dynamic Type 105, contrast 88, element not detected 68, text clipped 64, hit
  region 8, description 3. By screen: Insights 54, Home 38, catalog 55, Find in Email 26, Profile
  25, first run 24. Contact sheets are made by `contact_sheet` (a small Swift tool kept in the
  session's scratch folder; four captures a sheet, labelled). Seen on the first sheet: on Home,
  scrolled content runs under the status bar and the clock is drawn over it (as on Insights).
  Order inside E: (1) the audit to zero by cause: status-bar backdrop on the four tabs; disabled
  buttons that fail contrast (40% opacity); top-bar buttons and pills that stop growing with text
  size; clipped pills, rows and fields; text the audit sees but VoiceOver does not; four small hit
  regions; one unreadable label (`spendTotal`). (2) The same tour in Arabic, at the largest text
  and on iPad, sheets read, faults fixed. (3) A launch argument for each state the inventory in
  `private/audits/2026-11-11/ui.md` marks NO and that still exists (several are gone: deep
  analysis, paused, the rating sheet, in-app policies, Live Activity). (4) Each screen scored on the
  eight dimensions from sheets that were opened; section 7 rewritten from that.
- E, first slice (11-12): the four tabs keep the status bar's strip solid (seen on the simulator:
  scrolled Insights no longer draws a row through the clock; the first attempt, a zero-height
  strip, did nothing and was caught by looking); a button that isn't available yet keeps readable
  text on its own fill instead of the enabled colours at 40%; VoiceOver reads the Home total as a
  sentence; the paywall's three links and the age check's link have a 44-point place to tap; the
  big amount fields grow all the way with text size; the logo's stand-in letter is a picture to
  the audit. Found in a capture and fixed: Insights showed the stored name "AI Tools" beside
  translated categories; a known category now reads in the reader's language whichever of its
  names was saved (`CategoryTotalsTests.testAKnownCategoryIsNamedInTheReadersLanguageWhateverWasSaved`).
  The tour can capture a chosen subset (`PAUSELY_TOUR_ONLY`). 736 tests, 0 failures.
  The same tour at the largest text size (95 captures, `/tmp/pausely_tour_big_1`, audit 131) shows
  what is next: on Home the "Coming up" amount breaks across two lines ("$147." / "92"), the
  "Each month" switch and the count wrap word by word, and the state marks stay small; on
  Subscriptions the subtitle breaks into four lines and pinned section headers stack up.
  Top-bar buttons (Done, Cancel, Save) are system bar items, which iOS does not scale and offers
  the Large Content Viewer for; the audit lists them as "partially unsupported" (about 40 of the
  105) and they will be reported separately, not hidden.
- E, second slice (11-12): the four tabs at the largest text size. A design-system layout,
  `SideBySide`, puts a name and its value side by side and one above the other at accessibility
  sizes; it carries Home's "Coming up" total (which no longer splits a price across lines),
  the Insights rows (names broke mid-word: "ChatG-PT Plus") and the "When to cancel" header.
  Subscriptions puts its count and total under the title with the full width (two lines, not
  four); Home keeps "Each month" and "7 subscriptions" on one line each; state marks and Profile's
  row icons grow with the text. Read from captures at the largest size (`sheets/big2`, `ax3`).
  The audit on the four tabs at that size: Dynamic Type, clipped text and undetected text all 0
  (they were 39, 20 and 8 across the whole tour); 27 contrast findings remain there. Not held by a
  unit test: a layout at a text size is proven by its capture, and the audit count is the number.
  736 tests, 0 failures. Next: contrast (what the audit measures against what the palette
  computes), then the other 37 screens at the largest size, then Arabic, then iPad.
- E, third slice (11-12): what the audit's contrast findings are, and more of the largest size.
  Every named contrast finding on the four tabs was looked up by its frame: each one sat behind
  the floating tab bar or under the status bar's strip at that scroll position (the audit
  measures a row through the bar). The tour now writes three files: `audit.txt` (counted),
  `audit_behind_bars.txt` and `audit_system_bar.txt` (navigation-bar button titles, which iOS
  does not grow), each with its reason in the code; nothing is dropped. Whole English tour on
  this build (`/tmp/pausely_tour_en_4`, 97 captures): **173 counted** (336 at the start), 17
  behind bars, 39 system bar. Of the 173: Dynamic Type 82, contrast 47, clipped 39, undetected 5;
  the catalog holds 73 and first run 22. The catalog's "cannot change font size" findings are
  contradicted by its capture at the largest size (the rows do grow); its clipped-text findings
  were real and are fixed: "Add your own" was cut to "Add yo…", names broke mid-word ("Spoti-fy")
  and "Added" letter by letter, so at accessibility sizes the rows are words only and the button
  sits under the title. Also fixed from captures at that size: Profile's row values were cut
  short (they stack now); the shared text field had no room above and below its text; a receipt
  line was truncated ("On your sl…") where space was tight; the first-run slip keeps to its count
  and its button so the services stay reachable. 736 tests, 0 failures. Next: rerun the tour for
  the new count, then Arabic, then iPad, then the states with no launch argument.
- E, fourth slice (11-12): Arabic. The whole tour in Arabic with the audit
  (`/tmp/pausely_tour_ar_1`, 92 captures: 119 counted, 15 behind bars, 38 system bar), every capture
  opened on contact sheets, and a new scan of what the screens really show,
  `scripts/tour_untranslated.py` (it reads the tour's element trees): 32 findings before (6 English,
  21 Latin digits, 5 left-to-right sentences), 0 on the screens toured again afterwards
  (`/tmp/pausely_tour_ar_2`, `_ar_3`). What was wrong, each now held by a test:
  1. The edit screen's four row names and its reminder choices were English in every language
     since the day the screen was built ("Billing cycle", "Next renewal", "Category", "Remind me",
     "3 days before"), and so was "Sign out" on the age check. The catalog had the translations;
     the words were handed to a parameter typed `String`, where no translation is looked up
     (`testNoTranslatedWordsAreHandedToAPlainStringParameter`, `testReminderLabels` in three
     languages; new keys "Remind me", "Off", "%lld days before").
  2. An Arabic sentence that begins with a Latin name ("Pausely Pro بسعر …") was laid out left to
     right: on two lines the name sat at the end of the first and the full stop at the start of
     the second. Paywall, age check, mail screens. Eleven translations now begin with a
     right-to-left mark (`testAnArabicSentenceThatBeginsWithANameIsStillReadRightToLeft`), and
     "Disney+" inside a sentence no longer shows as "+Disney". A logo tile then took the mark for
     the name's first letter and went blank: the letter is the first letter or digit now
     (`testALogoTileShowsTheNamesFirstLetter`).
  3. Latin digits typed into Arabic sentences beside Arabic-Indic amounts ("خلال 12 شهرًا",
     "5 سنوات", "8 أحرف", "6 أرقام", "24 ساعة", "9 صباحًا"). 38 values spell their numbers, which
     reads right in every Arabic region whichever digits it uses
     (`testArabicSentencesSpellTheirNumbers`). Counts the code put on screen bare (section counts,
     the year slip's "7" and "3", the cancel steps, "On your slip") go through `L10n.number`
     (`testACountIsWrittenInTheReadersDigits`).
  4. "Done" in Arabic ("تم") is 15 points wide and text buttons were sized by height alone. One
     rule, `tapArea`, on 20 buttons (`ScreenRulesTests`); the audit's hit-region findings on the
     receipt, the year and the subscription screen are gone.
  5. The paywall and the subscription screen scrolled their text under the clock. Every screen that
     draws its own top row uses `inkScreen()` now (18;
     `testAScreenWithoutANavigationBarKeepsTheStatusStripSolid`).
  6. The notifications page drew its rows and its footnote at half strength while reminders were
     off, and the footnote could not be read: the audit's contrast failure there was real, not the
     grey. The words are at full strength; iOS greys the switches itself.
  7. From the first half of the slice: `textMuted` and `textFaint` are lighter (#B4B6BC, #9C9EA5),
     What's new scrolls with its button pinned, the add-your-own name wraps, first-run services
     are rows at accessibility sizes and the hint that repeated the heading there is gone. The tour
     types a price where the slip asks for one, so the reveal and the account step are seen in
     every currency and at the largest size (`/tmp/pausely_tour_big_3`).
  Seen and left as they are, with the reason: dates follow the iPhone's calendar (Hijri on a Saudi
  simulator) while billing arithmetic and the age check stay Gregorian (`Calendar.billing`);
  StoreKit's price keeps the store's digits; an amount in "ر.س." before a full stop reads "..";
  Home's rows after the chosen day fade while a day is selected; the add-your-own placeholder is
  cut at the largest size (what is typed wraps). New rows: Cur-1 (two retired currencies offered,
  one current one missing), and the two below. 744 tests, 0 failures; Release builds; gold_check 0;
  string_usage 0. Next: the export formats against the policy (the app makes CSV, PDF and JSON;
  the policy names one and the JSON file has no test), "iPhone" said on iPad, the retired
  currencies, then the English tour for the new count and the iPad tour.
- Export (11-12, found while reading the Arabic export screen): the screen offers CSV, PDF and
  JSON; the policy promised "a CSV spreadsheet file" and nothing tested the other two. The policy
  now names what the screen makes, and a test holds the sentence to `ExportFormat.allCases`. The
  JSON file is built by a pure function and reads back as the same list and history (price as
  entered: `"amount" : 15.49`); each format writes the file it names, with cancelled ones left out
  when asked. 746 tests, 0 failures. The policy page is synced to the two local site branches,
  not pushed (6.7).
- iPad (11-12): on an iPad the app says "iPad". Sixteen sentences said "iPhone" on both devices
  ("Same as iPhone" for the language, "Saved on this iPhone", "Your email never leaves your
  iPhone", "this iPhone's Keychain") and two said "phone". Each has its own wording for the iPad in
  all six languages, as the catalog's per-device wording (compiled to
  `NSStringDeviceSpecificRuleType`), so both `Text` and `L10n.string` get it.
  `testOnAnIPadTheAppSaysIPad` fails for any text that says "iPhone" without an iPad wording beside
  it. The tests that judge translations read every wording of an entry through one helper
  (`CatalogTexts`). Seen on the iPad Pro 13-inch simulator (`/tmp/pausely_tour_ipad_1`, the whole
  tour, 97 captures): the language page, the mail screens, the code screen and the catalog all say
  iPad. 747 tests, 0 failures.
- Cur-1 (11-12): the currency list offers what people are charged in today. The Bulgarian lev is
  gone (Bulgaria took the euro on 2026-01-01 at 1 EUR = 1.95583 BGN, Council Regulation (EU)
  2025/1409; the lev stopped being legal tender on 2026-02-01) and so is Sierra Leone's old leone
  (redenominated 1000 to 1 as SLE on 2022-07-01; ISO 4217 amendments 171 and 172); the new leone
  is offered. What was saved in either still converts, at the fixed rate and not at whatever a feed
  says or leaves out (`CurrencyRates.retired`, applied wherever rates are built); a display
  currency saved as the lev, or an iPhone whose system still names it for Bulgaria, becomes the
  euro (`CurrencyManager.current`). The public feed was read once to check it (read-only): it
  still carries BGN at exactly 1.95583 times its euro and SLL at 1000 times SLE.
  `testARetiredCurrencyConvertsAtItsFixedRate`, `testNoRetiredCurrencyIsOfferedAndItsSuccessorIs`.
  130 currencies, as the listing says. 749 tests, 0 failures.
- iPad tour and what it showed (11-12). The whole tour on the iPad Pro 13-inch simulator with the
  audit (`/tmp/pausely_tour_ipad_1`, 97 captures), the first capture of every screen read on
  contact sheets. Counted 180, of which 124 were the four titles of iPad's own tab bar on every
  tab capture (bare `UILabel`s the system sizes itself): the tour now files those with the other
  system-bar titles, which leaves 56. One real fault, on every device: the empty Insights tab had
  a black band down each side in Arabic, at the largest text size and on iPad. A scroll view is
  only as wide as what it holds; with two short lines it shrank, sat in the middle and left the
  navigation stack's black beside it. The content is full width now, `inkScreen()` paints the
  whole width whatever it is put on, and two instruments find the fault again:
  `scripts/tour_black_bands.swift` reads the captures for unpainted bands (it finds the old ones
  and nothing in today's four tours), and the tour itself reports a scroll view narrower than its
  screen. The tour is also repeatable now: the tabs open on the demo list every time (they showed
  whatever the test before had left: the iPad's Home was a first-run list of four), and a demo
  launch takes in no tally an earlier run left waiting (an "empty" Home once opened on a Netflix).
  Seen on iPad and right: the 680-point column, the tab bar at the top, sheets, the keyboard.
  749 tests, 0 failures; Release builds; gold_check 0. Next: the states with no launch argument
  (a richer demo list, then the dialogs, error lines and data-dependent rows through the tour),
  the parts not yet rebuilt (Pause Plan, the notice toast), then the four whole tours for the
  counts and the scores.
- Two more sentences that were English in every language (11-12), found reading the age check's
  code for the state pass: its lockout line ("You can try again in about 3 hours.", built by hand
  with an "s" added for the plural) and the mail server's fallbacks ("The server refused the
  request.", "Sign-in failed.", chosen when the server says nothing; the mail-error test could not
  see them behind their `?`). Both translated, the first with plural forms.
  `testNoEnglishSentenceIsAssignedReturnedOrChosenAsPlainText` reads every source line for a
  sentence that is assigned, returned or picked by a condition without reaching the catalog; it
  finds these two as they were and nothing else in the app. `testTheLockoutLineIsInTheReadersLanguage`.
- E, the states (11-12, first part). Most states could not be opened by a launch argument, so
  nobody had looked at them. Now: `--varied-demo-data` starts from a list with one of everything a
  list can hold (a charge tomorrow, one waiting for a decision, a free trial about to charge, one
  with no renewal date, one in another currency and yearly, a quarterly one, a cancelled one, four
  video services, more than eight entries, more than six charges in a month), with its history (a
  price rise, a cancellation, hours of use); `testTheVariedDemoListHoldsOneOfEverything` keeps it
  whole. `--demo-subscription=Name`, `--demo-verdict=Name`, `--demo-subscription-edit=Name`,
  `--demo-price-history=Name` and `--demo-cancel=Name` open that subscription; `--demo-receipt=plain`
  and `--demo-wrapped=list` show the list in use. The tour's `testStates` opens 45 states: the tabs
  with the varied list, the subscription screen for a trial, a cancelled one, an undated one and
  one in another currency, three verdicts, the empty receipt and year, both refusals of the age
  check, and 26 states behind a tap (dialogs, searches with no match, sheets behind a row, the kept
  and cancelled slips). A demo launch counts as signed in, so Home's rows and Keep can be followed.
  English run read in full (`/tmp/pausely_states_en_1`, 78 captures). Fixed so far from it: a free
  trial was said to "renew" on the subscription screen (it says when the trial ends, in the header
  and in the facts); a cancelled subscription showed a "next renewal" in the past, a yearly cost
  and what it would cost over ten years (it shows the day it was cancelled instead, and no usage
  row); the verdict said a yearly price twice ("€59.99 /yr … That's €59.99 a year": it now says
  only what it comes to in the person's currency; `testTheSlipDoesNotSayAYearlyPriceTwice`).
  Still to fix from the same reading: Insights' "Where it goes" drops categories after the fifth
  without saying; a price rise is marked amber in one place and coral in two; Pause Plan calls a
  cancelled service "paused" and says a trial "renews", and its blocks have two left edges; the
  year's page with an empty list ("about $0 a year", with a share button); the age check's
  refusals are centred in a bold sans title; the catalog still says "a custom subscription"; the
  plan sheet asks for a renewal date and a trial end; the dates sheet says "they" of one
  subscription; two tap areas (End Pause Plan, the catalog's clear button); "$54.99/mo" spoken as
  written. Then the same pass in Arabic, at the largest size and on iPad. 753 tests, 0 failures.
- E, the states (11-12, second part): the rest of what the English reading showed, each seen again
  on the simulator (`/tmp/pausely_states_en_2`). Insights' "Where it goes" showed five categories
  and dropped the others without a word: the rest is one last row, "Everything else", so the rows
  add up to the whole (`testTheRowsAlwaysAddUpToTheWhole`). A price rise has one mark (coral) on
  Insights, the verdict and the price history. Pause Plan: a cancelled service is "Cancelled", not
  "Paused now"; a trial's to-do says its free trial ends; one left edge; the empty state starts at
  the margin; End Pause Plan is a full tap target. The year's page with nothing listed and nothing
  cancelled says so and offers nothing to share (`hasNothingToShow`; everything cancelled is still a
  year worth printing). The age check is in the app's style: no picture, the serif for its
  question and its refusal, text from the margin. The catalog's empty search says "add your own",
  the name on its button. The plan sheet asks for one date on a free trial (the day it ends is the
  first charge), not two. The dates sheet speaks of one subscription as one. The catalog's clear
  button is a fingertip wide; "$54.99/mo" is read out as "$54.99 a month". Tapping a row on Home
  opens its verdict in a demo launch. 754 tests, 0 failures; Release builds; gold_check 0;
  string_usage 0. Next: the same pass in Arabic, at the largest size and on iPad.
- E, the states in Arabic and the parts not yet rebuilt (11-12). The state pass in Arabic
  (`/tmp/pausely_states_ar_1`, 78 captures, read on contact sheets): `tour_untranslated.py` prints
  nothing, `tour_black_bands.swift` prints nothing, no narrow scroll view. Everything fixed in
  English reads right in Arabic too (the trial that ends, the cancelled subscription's day, "البقية"
  for everything else, the one-subscription dates sheet, the age check's refusals from the right).
  Then the three parts that were still in the old style, each with a launch argument so the tour
  sees it (`--demo-link-problem`, `--demo-notice`, `--demo-banner`):
  the link-problem banner is stacked above the screen (laid over it, it cut the welcome screen's
  mark in half) in ink with the coral mark and a full-size close; the notice ("Saved on this
  iPhone…") sits above the tab bar instead of over each tab's one big number, is read out by
  VoiceOver, and stays as long as its sentence takes to read (4 to 9 seconds;
  `testANoticeStaysLongEnoughToRead`), not 4 seconds whatever its length; the demo banner is ink
  with the amber mark. And five things that ran through the whole app:
  1. The accent colour was unset, so every text cursor was iOS blue, and the launch screen was a
     dark purple that showed before the app's ink. Both come from the palette now
     (`testTheSystemsColoursComeFromThePalette`).
  2. Six transitions slid, scaled or shifted whatever Reduce Motion said. They go through
     `AnyTransition.arriving`, which only fades when it is on
     (`testNoTransitionMovesWithoutAskingReduceMotion`).
  3. Ten copies of the word that leaves a screen, and an X on the paywall. One part,
     `LeaveButton`, in one place and weight; the paywall says "Close" like the verdict. Screens
     with a navigation bar keep its button.
  4. The day picked on Home's line was view state cleared when the drag reported its end; a drag
     the scroll view takes over never does. It is gesture state now and lets go with the finger
     (`testTheDayPickedOnHomesLineLetsGoWithTheFinger`).
  5. The tour waits for a scroll to come to rest before it audits (rows were measured where they
     had been a moment earlier and their contrast called failed).
  Not changed, with the reason: the keyboard's blue search key is the system's; the serif in Arabic
  is SF Arabic because New York has no Arabic and iOS pairs them itself (Japanese to be looked at).
  758 tests, 0 failures; Release builds; gold_check 0; old_ui_check 0. Next: the state pass at the
  largest size and on iPad, the inventory brought up to date, then the four whole tours.
- Told by the other session at 22:04 (it has stood down and changed nothing): sections 2, 3, 4, 6, 7
  and 10 of the engineering audit were never done and there is no finished overlooked-details
  report. Those areas have been scanned by nobody; they are owed before Stage G can be called done.

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

### 5.3 The plan for what is left (written on the night of 11-11 to 11-12, before any further change)

The founder's instruction for this part: "plan before executing everything to make sure even the small
things are all interconnected to make the truthful 9.5", "use the internet and find sources".

**What was checked before writing this.** The overlooked-details report (`overlooked.md`) was only ever
a first save. Every "wrong" or "missing" line in it was looked up in today's code and given a ledger
row, O1 to O41 (6.3a). (O1 was written down wrongly at first: the two lines that log a whole link sit
inside `#if DEBUG`, so no release build has them. Corrected in its row.) Six parts of the engineering
audit and five of the overlooked report were never written, so nobody has scanned those areas.

**Seven threads.** A small thing reaches 9.5 only when everything on its thread does, so the work is
grouped by thread, not by file. Each thread ends in a guard that fails if the thread is cut again.

| Thread | What hangs on it | The guard |
|---|---|---|
| 1. One billing day | Renewal maths (27 uses of the device's calendar), reminder trigger dates, the age check, the usage month, the year slip, widget day counts, how a renewal day is stored and sent (O2 to O7, O16) | A test class that runs the engine under the Buddhist, Hijri and Japanese calendars and in Auckland, Tokyo and Honolulu and gets the Gregorian answers; a source guard like `CurrencyGuardTests` for `Calendar.current` in `Core/Renewals` |
| 2. One locale for text the code builds | Money and date text (about 70 calls), reminder text, plural forms, layout direction, tab titles, notification buttons, widget text, Shortcut answers, currency names, amounts typed with Arabic digits and marks (O8 to O14, T97–99, T80–86, T70, T67, T89) | `LocalizationGuardTests` widened to widgets and Shortcuts; a plural guard (every count string has the forms its language needs); a test that types amounts as each of the six locales writes them |
| 3. One count of what the free plan holds | The store, the browser, the first-run importer, inbox import, the paywall sentence, the listing (O37, T109–111) | One function, one test, and a source guard that nothing else compares a count with the limit |
| 4. One record, every field shown | The eight unused fields, the sync record, the export, the database columns (two-step drop), the insights engine (T25–33), the verdict's facts (Stage F) | A test that every stored field of `Subscription` is read by a screen, the export or the engine |
| 5. One wipe list | Every key and file the app writes: typed hours, corrections, the Pro flag, the waiting tally, Keychain names, Spotlight, widgets, reminders (O38, O23, O40) | A source guard: every `UserDefaults` key and file name in the app is either removed by `LocalUserData.wipe` or on a short list of device settings with a reason |
| 6. One name per thing | Catalog keys, the listing, the website, accessibility labels, Shortcut titles, widget names, type names (T102–108, 15 hype names) | A name check in `gold_check` (banned variants of each name) |
| 7. One way a screen is proven | Launch argument per state → tour in English, Arabic, largest text, iPad → Apple's audit → contact sheet opened → a score row | The tour fails on a state without an argument or with an audit issue |

**The order, and why.** Everything that adds, removes or rewords a string or a state comes before the
screens are scored, and hygiene comes before that too, so each screen is scored once, on the code that
ships. Leaks come first because they are live in the build attached to the store.

1. **D0. Leaks and dead claims.** O1 (log lines), O38 (wipe list, thread 5), O40 (biometric dead
   code), O36 (the universal-link claim: publish the association file with the site, or drop the
   entitlement), O39 (Sign in with Apple revocation: the app and SQL sides here; the Apple key is the
   owner's). Exit: thread 5's guard is green.
2. **D1. Finish the scan.** Engineering parts 2, 3, 4, 6, 7, 10 and overlooked parts 5 to 9, one area
   per slice, read by me, findings into the ledger with ids. No fix starts in an area before its scan,
   so nothing is fixed around an unknown. Exit: the ledger says "scanned" for all sixteen areas.
3. **D2. The billing day and typed amounts (threads 1 and 2's amount part).** O2 to O10, O16.
4. **D3. Cut before translating.** The unused record fields (thread 4), T25–33 (rebuild "Deep savings
   analysis" on figures the app has, or remove it), names (T102–108, thread 6). Nothing is translated
   that is about to be deleted.
5. **D4. Platform details that add words or states.** Notifications (O21 to O27), widgets, Shortcuts
   and Spotlight (O28 to O35), the paywall and the plan row in Settings (O17 to O20), the free count
   (O37, thread 3), the app-switcher cover (O41). Then Stage F as written in 5.1 (the verdict's facts).
6. **D5. Words (thread 2).** One locale (O11 to O14), plural forms, every untranslated string, then the
   unused keys (T101), then the listing and the website's own policy text (T109–111).
7. **G. Hygiene** as in 5.1, plus what D1 finds. Exit: `gold_check` prints 0 (93 tonight).
8. **E. Every screen** (thread 7), as in 5.1, on frozen code: after this only screen repairs.
9. **H. Customer rounds**, then **I. The listing files and the proof**, as in 5.1. Section 7 is
   rewritten from evidence at the end of each stage, never from memory.

**What each stage is measured against (read, not remembered).** The earlier research is in
`private/audits/2026-11-11/` with 131 sources. The rules this plan leans on, each read at its source:

- Contrast 4.5:1 for text up to 17 pt, 3:1 for 18 pt or bold; controls 44×44 pt; text enlargeable to
  at least 200%; with Reduce Motion, movement becomes a fade; never colour alone (Apple HIG,
  Accessibility: developer.apple.com/design/human-interface-guidelines/accessibility; WCAG 2.2 1.4.3,
  1.4.4, 1.4.11, 2.5.8: w3.org/WAI/WCAG22/quickref).
- Plural categories: Arabic has six (0; 1; 2; 3–10; 11–99; 100–102), German and Spanish one/other,
  French counts 0 and 1 as "one", Japanese has one form (Unicode CLDR, language plural rules:
  unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html).
- Account deletion: easy to find, deletes the whole record, says billing continues through Apple and
  how to cancel, and "apps that support Sign in with Apple should use the Sign in with Apple REST API
  to revoke user tokens" (developer.apple.com/support/offering-account-deletion-in-your-app).
- Universal links: `https://<domain>/.well-known/apple-app-site-association`, no extension, HTTPS, no
  redirects, one file per subdomain in the entitlement; Apple's CDN fetches it within 24 hours
  (developer.apple.com/documentation/xcode/supporting-associated-domains).
- Time Sensitive notifications "break through system controls such as Notification Summary and
  Focus": for "charges tomorrow" only (developer.apple.com/documentation/usernotifications/
  unnotificationinterruptionlevel/timesensitive).
- Widgets: accented and vibrant rendering, `widgetAccentable`, removable backgrounds,
  `isLuminanceReduced`; accessory families have no full colour (developer.apple.com/documentation/
  widgetkit/preparing-widgets-for-additional-contexts-and-appearances).
- Paywall, first run, permission priming, empty and error states, trust page, export and deletion:
  the "TAKE THIS" lists in `best_apps.md`, `part3a.md`, `part3b.md`, `part45.md` (Apple HIG and App
  Review 3.1.2 and 5.1.1, NN/g, RevenueCat's State of Subscription Apps, the FTC and UK subscription
  rules). Each list item becomes a line in the screen's score row in Stage E: met, or what is missing.

**What cannot reach 9.5 from here** (true scores in section 7, steps in 6.7): a sign-up by an outsider,
a real purchase and refund, VoiceOver and Sign in with Apple on a device, widgets in tinted and clear
mode on a device, the Apple key for token revocation, publishing the website, anything waiting on App
Review, and US prices for eleven first-run services.

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
| G3 | The Keychain outlives the app, so a copy installed after a delete would restore the last person's sign-in and keep their mail passwords. (The sighting on the simulator on 11-11 was a debug flag an earlier session had left there, since removed; the cause on a real phone is the Keychain.) | closed 11-11: on the first launch after an install the Keychain is cleared, the sign-in library's own stored session first; seen on the simulator after delete and reinstall; `InstallStateTests` |
| G4 | Cancelling "Create your account" after the first-run reveal lands on a generic "Welcome to Pausely / Get Started" screen, as if the guess and the list had never happened. | closed 11-11: leaving account creation, or closing the app there, comes back to the person's own reveal with the list; walked on the simulator |
| G5 | The sign-up error told people to "check the address" when the address was correct and the mailer had refused it. | closed 11-11: only a malformed address is blamed; three tests |
| G6 | Two of the twelve first-run services showed a letter instead of a logo (ChatGPT Plus had no entry; Google One pointed at a host with a 32-pixel icon). | closed 11-11 in the logo table; to be re-seen on the next capture |

### 6.2 Open: can lose, expose or corrupt a customer's data (first)

| Id | What | Status |
|---|---|---|
| B1 | History file unreadable on a locked phone → "Keep it" from a notification can overwrite the whole Savings Receipt history | closed 11-11: `DeviceFile` tells "missing" from "unreadable"; nothing is saved until the history has been read; six tests |
| B2 | Sync queue drops changes queued while it is sending | closed 11-11: the queue was rebuilt (`Services/Sync/SyncQueue.swift`); a change noted during a pass makes the pass go round again. `SyncQueueTests.testAnAddMadeWhileAnotherIsBeingSentIsSentToo` failed against the first version of the new queue and found exactly this |
| B3 | Edits, cancels and deletes made before a failed add has synced are silently undone | closed 11-11: one thing to send per subscription (add it, change it, remove it), and what is sent is the copy on the phone at that moment, so an edit before the add went up goes up with the add. Four store tests and three queue tests |
| B4 | The queue only drains on launch or pull-to-refresh, while the app says "It will sync when you're back online"; failures retry forever, silently | closed 11-11: sent after every change, when the app comes to the front, when the network comes back, and when a failed change is due again (2 s doubling to 5 min). The notice says "back online" only when offline is the reason; a refusal by the server gets its own sentence, in five languages. Not built: a standing "N changes waiting" line on the list (goes with the Subscriptions screen in Stage E) |
| B5 | Currency rates are written off the main thread while every screen reads them (data race) | closed 11-11: `CurrencyManager` moved to `Core/Money`; rates are stored on the main thread whoever asks, and the table every conversion reads is behind a lock. `testLiveRatesAreStoredOnTheMainThreadWhoeverAsks` fails with the fix taken out (`[false]`). Also: a live answer is used only when it is a full list priced in USD; rates refresh when the app comes to the front (at most hourly), not only at launch; unit tests no longer call the rates service |
| B7 | Any `pausely://auth/...` link is accepted without the app having asked for one (sign-in into someone else's account, then the local history is wiped) | closed 11-11: `AuthLinkGate`, seven tests |
| B8 | A password typed on an abandoned sign-up is applied to whichever account next signs in by email | closed 11-11: saved only on the address it was typed for |
| B10 | Fields are dropped the moment an add reaches the server; an edit made meanwhile is overwritten | closed 11-11: the server's answer is no longer written over the phone's copy (`testAnAddThatReachesTheAccountKeepsWhatOnlyThisIPhoneKnows`); a list fetched while a change was being made treats that change as newer than itself |
| B15 | Signing out offline leaves the cached session: the next launch shows the signed-out person's list | closed 11-11: the cache is cleared before the server is asked, whatever it answers. No test: it is the order of two calls that need the account service |
| B16 | Name and email are left on the device after sign-out and account deletion | closed 11-11: the unused saved email is no longer written and is removed; the kept name is removed on account deletion and when another account takes over the phone (sign-out keeps it, because Apple gives a name only once); `InstallStateTests` |
| T62 | Cancel help matches by "name contains": Loom shows Bloomberg's steps, link and phone number (34 wrong companies measured) | closed 11-11: `ServiceMatcher` matches a name only when it is that service (its name or another of its names, written any way, plus plan words). Measured over the 992 catalog names before and after: 39 names that got another company's help now get none of it (Allstate had Paramount+'s, a pet insurer AWS's, BarkBox and seven others Box's); 291 names find a service and every one was read and is the right company. `CancelHelpTests`, 12 tests. Apple One and Apple News+ had no steps at all and now have Apple's |

### 6.3 Open: wrong money, dates or claims

| Id | What | Status |
|---|---|---|
| B9 | Pause Plan overwrites the billing anchor with "a month after today" | closed 11-11: `PausePlanSchedule.restartAnchor`. A service started again renews on the day of the month it was started (31 Jan → 28 Feb, 31 Mar, 30 Apr; it used to become the 28th forever). A month later is stored only where that is the same schedule; otherwise the start day is stored and recorded as kept, so the day just paid is not asked about. One that is already on keeps its date. Six tests (`PausePlanTests`, `PausePlanStartTests`); the 31st ones fail on the old rule |
| B11, B12, B13 | Paywall never retries prices after one failure; a refund or expiry is not noticed while the app runs; Pausely's own line can be created at USD launch prices for any country | closed 11-11: one class owns StoreKit (`StoreKitManager`); `PaymentManager` keeps only the tier. B11: a failed or empty price load is not counted as loaded, and the paywall keeps asking while it is open. B12: every transaction update, purchase, restore and return to the app reads the entitlements again, so Pro is taken away as well as given. B13: Pausely's own line is added only from the App Store's stated price, currency and renewal day, never an estimate, and a line an earlier version priced wrongly is corrected. `StoreKitManagerTests`, `ProTierTests`, `PaymentManagerTests` (16 new tests). Not proven: an actual purchase and refund. Apple's local test store refuses purchases inside the unit-test host ("notEntitled") and the simulator has no Apple Account, so that needs a sandbox account on a device (6.7) |
| B14 | `startDate` is never saved, so "lifetime" always starts the day the row was added | closed 11-11: nothing ever asked the person when they started paying, so the field, the "lifetime spend" sum built on it and the store's lifetime total (which no screen showed) are removed. "Tracking since" shows the day it was added to Pausely, which is what it says |
| B17, T41 | Four definitions of "active": Home, Insights, paywall and the year slip show different yearly totals for one list | closed 11-11: one definition, `charging` (on, or a trial that will turn into a charge, and not paused), behind Home, the Subscriptions header, Insights by category, the paywall's yearly figure and comparison, the year slip, the widget, the Shortcuts and the PDF export. `testEveryTotalAndCountIsAboutTheSameSubscriptions` holds one list with a trial, a paused and a cancelled subscription against all of them. The unused `isActive` flag is gone. Still open under T66: Pausely's own "pause" does not pause anything real |
| B18, T95 | Stale rates are never reported; converted totals are not marked "about" | closed 11-11: a total that had to convert something is shown as "≈" (`MoneyFormat.total`, decided once by `isConverted`): Home, the paused row, Coming up, the Subscriptions header, both Insights lists, the widget, the Shortcut and the PDF export. A total all in one currency stays exact. Currency settings says which day the rates are from (seen on the simulator). The dead fallback branch and the error nothing could read went with B5. Four tests |
| Rules | Unconverted fallback in `convertToSelected`; groups ranked in mixed currencies; dates not normalised on update; pause reminder outside the planner; demo flags readable in release; rate host hard-coded; a writable no-op `isPremium` and a dormant client-side Pro grant | closed 11-11. Closed: `convertToSelected` returns nothing when there is no rate and its ten callers leave the amount out of a sum or show it in its own currency (it used to hand back the same number, which was then labelled with the display currency); groups without a date are ranked in one currency (`testGroupsOrderedByCostCompareInOneCurrency`); the no-op `isPremium` setter and the client-side grant path went with the StoreKit slice. The pause reminder went with T66. The store keeps a renewal day and a trial's last day at local noon on add and on edit (`testRenewalAndTrialDaysAreKeptAtNoonOnAddAndOnEdit`). Launch arguments are read in one place, `LaunchFlag`, which answers false in a release build; `LaunchFlagGuardTests` fails if any other file reads them (it found three more on its first run). The rates address is in `AppConfig` |
| T71, T75, T-RenewalDates | Renewal dates the person never entered are saved as theirs (Shortcut add, add sheet pre-fill, "Add date" = today + 14) | closed 11-11. T71: the Add Shortcut saves no date (`testAddingByShortcutDoesNotInventARenewalDate`). T75: both add screens show "Set date" and save none unless the person picks one (one shared control, `OptionalDatePicker`, also used by the edit screen; seen on the simulator); a trial needs the day it ends before it can be added, and when it ends that day becomes its renewal date if none was set (`testAnEndedTrialRenewsFromTheDayItEndedUnlessADateWasSet`). "Add date" opens on today instead of a guess two weeks out. What remains true: a picker that is opened and saved untouched saves today, which shows at once as "renews today" |
| T5, T45–47 | "Went up" on a currency change or typo fix; year slip counts by `updatedAt` and raw category strings | closed 11-11. T5: one price history, `PriceHistory`, read from the event log. A change counts only when the currency and billing period are the same before and after, the earlier price had stood for one billing period (so correcting a typo or the catalog's typical price is not "went up"), and it still stands. Found on the way: two older price trackers wrote different data under the same storage key and overwrote each other; both are deleted, with the Home row that told people about a price they had just typed. The history now records currency and billing-period changes too. `PriceHistoryTests`, 7 tests. T45–47: the year slip counts cancellations from the history (not from a date that moves on any edit), groups categories the way Insights does, compares in one currency, marks converted totals "≈" and calls the kept amount "Kept so far". `YearSlipTests`, 2 tests |
| T15–19, T23, T43 | Estimates and forecasts stated as fact ("this year", "Back in your pocket", "avoided") | closed 11-11, in five languages: the promise sentences say "your cancellations are on track to keep you … over 12 months" (not "Pausely is on track to save you … this year"); "Kept with Pausely" is "Kept since you cancelled"; "paid for itself N× over" is "on track for N× what Pausely costs a year"; one sentence for an empty receipt on both screens; "How we count" says the charges are what the renewal date and price entered say would have happened; "avoided over 12 months" is "on track over 12 months"; the Pause Plan slip says "About … a year" and what it assumes; the first run says "about … a year more" |
| T59, T66, T72–74 | "Open Cancellation Page" opens a web search for 794 of 994 names; a "pause" that pauses nothing and stops reminders; Shortcuts report wrong status | T59 closed 11-11 with T62: the button says what it opens. A known service: "Open Cancellation Page". A name the catalog lists: the catalog's own link for exactly that name, called "Open Website", with one line on where to cancel. Anything else: "Search How to Cancel" (and "&" in a name no longer cuts the search short). Seen on the simulator. T66, T72–74 closed 11-11: the "pause" set only by a Shortcut marked a subscription paused, stopped its reminders and took it out of the totals while it went on charging. It is removed: both Shortcuts, `pausedUntil`, the resume button, the paused row on Home and the reminder scheduled outside the planner. A subscription the person marks Paused themselves is still listed apart. The detail Shortcut reports the real status and no renewal for something that will not charge; the spend Shortcut says what it returns. The `paused_until` column stays in the database, unwritten, until it can be dropped by the two-step rule |
| T96 | Pause Plan counts Audible, PlayStation Plus and Kindle as streaming | closed 11-11: eligibility is an explicit list of video streaming services by name; being filed under "Entertainment" is no longer enough. `testOnlyVideoStreamingByNameIsEligibleWhateverItsCategory` (12 that must not be, 18 that must) |
| Cur-1 (found 11-12) | The currency list offers two currencies nobody is charged in any more and lacks one that people are: the Bulgarian lev (BGN; Bulgaria took the euro on 2026-01-01 at 1 EUR = 1.95583 BGN and the lev stopped being legal tender on 2026-02-01: evroto.bg, trade.ec.europa.eu), Sierra Leone's old leone (SLL; redenominated 1000:1 as SLE on 2022-07-01 and moved to ISO 4217's historic list: SIX amendments 171 and 172), and no SLE at all, so someone in Sierra Leone cannot choose their own money | closed 11-12: neither is offered, SLE is; old entries convert at the fixed rates (`CurrencyRates.retired`), and a saved or system choice of a retired currency becomes its successor; two tests in `MoneyTests` |

### 6.3a Open: from the overlooked-details check (each looked up in the code on the night of 11-11)

| Id | Weight | What | Status |
|---|---|---|---|
| O1 | low | Not what the report said: the two lines that log a whole incoming link are inside `#if DEBUG`, so no release build writes one. What was real: five log lines wrote the person's address or id (three of them in every build, through a logger that hides such values in release logs) | closed 11-11: all seven lines are gone, and `LogGuardTests` fails on any logging call that names a link, an address, a token or a code |
| O2, O3 | high | All renewal maths runs in the device's calendar (27 places); on a Hijri, Buddhist or Japanese-calendar iPhone "monthly" is a lunar month or the year is 2569. Reminder trigger dates carry no calendar | closed 11-12: every day the app or its widgets work out comes from `Calendar.billing` (Gregorian, the phone's time zone); 75 uses of the phone's calendar in 41 files are gone, and a source guard fails on a new one. A reminder's date is handed to iOS with its calendar. `BillingCalendarTests`, 10 tests, was then run with the simulator itself set to the Buddhist calendar (Thailand's default) and to the Islamic one: all pass in both, among them that iOS answers the planned moment when asked when a reminder will fire. Dates are still shown in the person's own calendar |
| O4 | medium | The age check counts years in the device's calendar: 16 arrives about six months early on a Hijri iPhone | closed 11-12 with O2: counted in Gregorian years (`testAgeIsCountedInGregorianYears`, run under the Islamic calendar too) |
| O5 | medium | A renewal day is stored as a moment (local noon): after a long flight, or on a second device far away, every renewal is a day off | closed 11-12: a day is saved as noon UTC on that day (on the server, in the copy on the iPhone, in the history) and read back as noon on that same day wherever the phone is (`BillingDay`). When the time zone changes, the days in memory are read again and the reminders rebuilt. What an earlier version saved is read as before on the phone it was typed on, and each such row is sent back once in the new form. `BillingDayTests`, 9 tests: a day typed in any of nine time zones is the same day in the other eight, and after a Toronto-to-Tokyo flight a renewal on the 15th is still the 15th with its reminder on the 14th. Not covered: an old version of the app in New Zealand, Fiji or Tonga reads the new form a day late until it is updated |
| O6 | medium | Trial end dates keep the time of day they were made | not a finding now: `withDaysAtNoon` sets both the renewal day and the trial end to noon on every add and change |
| O7 | low | The usage month and the year slip's year come from the device's calendar | closed 11-12 with O2; the year slip shows the Gregorian year it counts, in the reader's digits |
| O8 | high | An amount typed with the Arabic decimal mark is refused | closed 11-12 with O9 and O10: every amount field (edit, custom add, catalog add, first run) reads and shows amounts through one place, `Core/Money/AmountText`. Digits of any script and the Arabic and full-width marks are read; a single mark is read the way the reader's language writes numbers ("1.299" is 1299 in German and 1.30 in English). `SubscriptionEditDraftTests`, 17 tests, among them: what a field shows reads back as the same amount in seven locales and six currencies |
| O9 | high | Amounts above 100,000 are refused in every currency (rupiah, dong, rial prices are normal above it) | closed 11-12: the ceiling is what 100,000 US dollars come to in the currency, never less than 100,000, and going over it says so ("That is more than Pausely can track.") instead of "Enter a valid amount" |
| O10 | medium | The edit field always shows two decimals: dinar prices are rounded on save, yen shows "1500.00" | closed 11-12: a field shows the currency's own decimals with the reader's decimal mark, the placeholder too; opening a dinar price and saving something else leaves the price as it was (test). The three messages under the edit fields were English only and are translated |
| O11 | medium | The language chosen in the app has no region ("CA$" for a Canadian), does not set layout direction, and about 45 money and 25 date texts ignore it; tab titles and notification buttons are built once | closed 11-12: one locale for everything the code builds (`L10n.locale`): the chosen language with the iPhone's own region, so numbers and currency signs read as on an iPhone set to that language there. Money uses it by default; every date, duration and number names it (a source guard fails on one that doesn't); a chosen language sets the layout direction; the tab titles follow; changing the language rewrites the reminder buttons, the waiting reminders and the widgets. `OneLocaleTests` ×5. Seen on the simulator: Arabic chosen on an English iPhone, right to left, with Arabic day wording |
| O12 | medium | Count strings without plural forms (same work as T99) | closed 11-12: every "today / tomorrow / in N days / N days ago" is worded by the system with its plural forms, and the seven sentences that count subscriptions, dates or months have every form their language needs (six in Arabic, two in English, German, Spanish and French, one in Japanese). The rest say a label and a number ("Waiting: 3"), which needs no agreement. `testCountsTakeTheFormTheirNumberNeeds`; seen in Arabic on the simulator |
| O13 | low | Currency names are English and searched in English only | closed 11-12: names come from the system in the reader's language ("米ドル", "US-Dollar", "Dólar estadounidense", capitalised at the head of a row), on the currency screen and in the edit screen's menu; the search finds a currency by its code, its name in that language or its English name, without minding case or accents. Two fields nothing read (a flag and a locale on each of 131 rows) are gone. `OneLocaleTests.testCurrenciesAreNamedAndFoundInTheReadersLanguage`; the screen opened in Japanese on the simulator |
| O14 | low | A price and its period are joined in code ("$4.99" + "/month") | closed 11-12: `BillingFrequency.priced` returns the two as one phrase from the catalog, in the order the language wants ("$4.99 a month", "月¥500", "4,99 € pro Woche"); seven screens and two VoiceOver labels use it. Where a receipt line wants the compact form ("$4.99/mo") it comes from `pricedShort`, the one place the two sit side by side. `OneLocaleTests.testAPriceAndItsPeriodAreOnePhraseInTheReadersOrder`, and `testNoScreenJoinsAPriceToItsPeriodByHand`, which found an eighth on its first run. Left as they are, on purpose: rows that set the price large and the period small beside it (two `Text`s; the row follows the reading direction) |
| O15 | unclear | Whether a nine-digit total fits on Home, Analysis and the receipt | check in Stage E with rupiah data |
| O16 | unclear | If the live `next_billing_date` column were DATE, no fetched renewal would parse | not a finding: read from the live project on 11-12 (`db_apply.py state`, which now prints column types and reads nothing else): it is `timestamp with time zone`, as are the trial end and the created and updated times. The table also still has `start_date` and `paused_until`, which the app no longer uses (to drop by the two-step rule) |
| O17 | low | The paywall shows "Subscribe" and today's price for a moment before the trial is known | closed 11-12: the slip and the button wait until the App Store has said whether this Apple Account gets the trial; when another plan is picked they wait again. Not seen with real App Store products (6.7) |
| O18 | low | A failed card (billing retry, grace period) is never mentioned | closed 11-12 with O19: Profile has a Pausely Pro group for someone paying through the App Store. It says when the plan renews, when a trial ends, or when it ends once renewal is off; warns when Apple could not take the payment; and opens Apple's own sheets to manage the plan and to ask for a refund. Five languages. `testThePlanSaysWhenItRenewsOrEnds`. Not seen with a real purchase (6.7) |
| O19 | low | Manage, refund and offer codes go through a web link, not Apple's sheets | closed 11-12 for manage and refund (O18's row). No row for offer codes: none have been made in App Store Connect, so the row would lead nowhere |
| O20 | low | Two StoreKit test files ship inside the app | closed 11-12: the duplicate is deleted and the other moved out of the app's folder; the built app holds neither |
| O21 | medium | "Keep it" on an old reminder keeps whichever charge is next, not the one the reminder was about | closed 11-12: a reminder carries the day of its charge and "Keep it" keeps that charge, if it is still ahead; answered after the charge, it keeps nothing. `ReminderReachTests` ×4 |
| O22 | medium | Reminders are rebuilt only when the app opens: with twenty subscriptions the 60 slots last about three weeks | closed 11-12, in two parts. When there are more reminders than iOS holds, every subscription keeps the day-before reminder for its next charge before any keeps the others (the soonest sixty used to win, and whatever renewed late in the month got none). And the plan ends with one notification asking to open Pausely, the morning after its last reminder or before the first one left out, so reminders never stop without a word. `ReminderReachTests` ×6. Not done: waking in the background to plan more. iOS runs that least for an app that isn't opened, which is the case it would be for, and it can't be seen working from here |
| O23 | medium | A reminder tapped while signed out leaves a verdict waiting for whoever signs in next. With it: after sign-out the widgets, Spotlight, the reminders already on the Lock Screen and the Shortcuts all still showed the list | closed 11-11: signing out (or a session that has ended) empties the list from memory, the widgets and Spotlight and removes pending and delivered reminders, while the copy on the iPhone waits for the same person (`LocalUserData.hideWhileSignedOut`); a reminder tapped while signed out opens and records nothing. `LocalDataGuardTests` ×2 |
| O24 | low | "Charges tomorrow" is an ordinary notification: in a Focus it can arrive after the charge | open, for the owner (6.7): Time Sensitive delivery needs a capability switched on for the app's identifier in the developer account. With it on, it is one entitlement and one line for the two "tomorrow" reminders |
| O25 | low | "Reminders are on" is shown when banners are off or everything goes to the summary | closed 11-12: the page says "on" only when a reminder would be shown somewhere and at once. Allowed with every place switched off reads "allowed but hidden"; held for the Scheduled Summary reads "can arrive late"; both say what to change and open iOS Settings. Five languages, with Apple's own names for those settings. `testAllowedIsNotTheSameAsSeen`. Not seen on a device in those two states |
| O26 | low | Badge permission is asked for and never used | closed 11-12: no longer asked for |
| O27 | low | "Keep it" on the iPhone is unknown to the iPad | accepted, and said: decisions live in the history, which stays on the device (Privacy & Security says so). Someone with two devices is asked on each. Sharing them needs a table on the server, which is a product decision |
| O28 | medium | The app never tells widgets to reload: a change shows up to six hours late | closed 11-12 (S15's row) |
| O29 | medium | Widget lines such as "in 3 days" are written as finished text when the app last ran | confirmed, and closed 11-12 (S15's row) |
| O30 | high | Widget text is English only (same work as T89) | closed 11-12 (S15's row) |
| O31 | low | The Add Subscription shortcut takes zero and negative prices | confirmed, and closed 11-12 (S16's row) |
| O32 | low | No Siri phrases (`AppShortcutsProvider`) | closed 11-12 (S16's row) |
| O33 | low | A widget tap or a Spotlight result opens the app, not the subscription | closed 11-12 (S15's row) |
| O34 | low | Lock Screen widgets show amounts while the iPhone is locked | closed 11-12: names and amounts are marked private, which iOS hides on a locked phone. Not seen on a device |
| O35 | unclear | Widgets in tinted, clear and StandBy rendering | written for it on 11-12 (the system's own text styles whenever iOS takes the background away, the amount as the accented part); still to be seen, in Stage E and on a device |
| O36 | medium | Not what the report said: the live site (the `gh-pages` branch) does publish an association file. What was real: the file names only referral links, which the app no longer has; nothing in the app makes or needs a web link; and the entitlement listed www.pausely.pro, which redirects and so could never be verified | closed 11-11: the app claims no web links (the associated-domains entitlement and the `https` route are gone), so the file on the site is inert. `DeepLinkTests`: web links open nothing, and the two entitlement files hold exactly Sign in with Apple and the widgets' shared group |
| O37 | medium | The free plan's limit counts cancelled rows: cancelling, which is what the app is for, frees no room | closed 11-12: the free plan's five places are for subscriptions that are charging. One function answers for every screen and importer (`FreeTier.used`, `FreeTier.room`, `PaymentManager.hasRoom`); the paywall no longer takes a count from whoever opens it. `FreePlanTests` ×5: the sixth is refused, cancelling one makes room, something already cancelled can always be listed, an import fills only the places left, and no other file compares a count with the limit |
| O38 | medium | Wiping misses typed hours, merchant corrections, the Pro flag and the waiting tally: the next account inherits them. Found with it: a name typed on a sign-up nobody finished was given to whichever account next signed in by code (the same fault B8 fixed for the password) | closed 11-11: one list of the person's saved values (`LocalUserData.personalKeys`, plus everything under `usage_`), removed together with the saved logos; the name is kept with the address it was typed for and given to no other. `LocalDataGuardTests` reads the sources and fails on a value saved under a name that is neither on that list nor named there as a setting of the iPhone with its reason (6 tests) |
| O39 | medium | Deleting an account does not revoke the Sign in with Apple token (Apple asks for it) | built 11-12, not live. An account that signs in with Apple confirms with Apple before it is deleted, and the app hands Apple's one-time code to a new server function (`supabase/functions/apple-revoke`) that exchanges it and revokes at once; nothing is stored. Closing Apple's sheet stops the deletion; any other trouble does not. `AppleRevocationTests` ×3; `scripts/dbtest/apple_revoke_function.sh`, 22 checks against stand-ins for Apple that verify the signed client secret. Not live, and not seen on a device: it needs Apple's key and a deploy (6.7). Until then the function is absent, the app gets an error from it and deletes the account as before |
| O40 | low | Biometric lock is dead code, with a Face ID usage string in Info.plist for a feature that does not exist | closed 11-11: the code, the error case and the usage string are deleted |
| O41 | low | The app switcher shows amounts | closed 11-12: the app switcher shows the app's name on ink (`PrivacyCover`), and the screen is back as it was on return. Seen on the simulator, both ways |

### 6.3b From the scan finished in D1 (found by reading, each checked in the code)

| Id | Weight | What | Status |
|---|---|---|---|
| S1 | high | Started in the background before the phone's first unlock after a restart (a reminder's "Keep it" on the Lock Screen, or iOS warming the app up), saved settings read as empty with no error. The app took itself for a new install: it tried to clear the Keychain and the mail passwords and to sign out, and whatever it then saved could replace the real settings: the list kept on the iPhone, the changes still waiting to be sent, typed hours (sources: christianselig.com/2024/10/beware-userdefaults; developer.apple.com/forums/thread/667959). An interaction with G3's fix of 11-11 | closed 11-12: the app looks before it trusts an empty answer. If the settings file is on disk and can't be read, storage is locked: a background launch ends there, before anything is read or saved, and "first launch after an install" now also needs the file to be absent. `InstallStateTests` ×3. Not provable on the simulator, which has no data protection: one check on a device (6.7) |
| S2 | medium | What the app keeps in the Keychain (who is signed in) was readable only while the phone was unlocked. A reminder's "Keep it", pressed on a locked phone, started the app unable to tell who was signed in | closed 11-12: readable after the first unlock, like the session the sign-in library keeps; an item saved by an earlier version moves over the next time it is saved. `InstallStateTests` |
| S3 | low | Dead error text: four cases of `PauselyAuthError` nothing throws, its English descriptions that no screen shows, and `SubscriptionLimitError`'s ("free tier limit") likewise | closed 11-12: the five unused cases and every English description are gone, with a branch in sign-in that matched an error nothing raises. The free-limit error did have one reader, a Shortcut that adds at the limit; it now says the paywall's own sentence, in the reader's language |
| S4 | medium | Debug builds only: an empty saved list is filled with demo subscriptions, and the next sync uploads them to whichever real account is signed in | closed 11-12: the demo set fills an empty list only in a demo launch, with sync off; a saved demo list is marked, shown offline in later demo launches, and thrown away by the next ordinary launch before anything loads it. `SubscriptionStoreTests.testAnEmptyListIsNotFilledWithTheDemoSetInAnOrdinaryLaunch` (fails on the old code) and `testTheDemoSetIsOnlyForDemoLaunchesAndNeverOutlivesThem`. Seen on the simulator: marker true after a demo launch, gone after an ordinary one; the demo list still shows in a demo launch. A demo list saved by a build from before today carries no mark and cannot be told from a real one |
| S5 | low | The receipt-facts file is written "only while unlocked" and a failed read counts as empty, so a save after it writes over the facts (a rescan rebuilds them) | closed 11-12: the ledger tells "nothing saved yet" from "can't be read now"; a scan that ends while the facts can't be read keeps what it found for itself and writes nothing, and disconnecting an inbox leaves an unreadable file alone. The file stays readable only while unlocked (nothing in the background needs it). `MailboxProvidersTests.testFactsThatCannotBeReadAreNotWrittenOver`, with a file whose reading is refused standing in for a locked iPhone |
| S6 | low | A widget drawn before the first unlock reads nothing and shows the empty state until its next refresh (up to six hours for the trial widget) | closed 11-12 (S15's row) |
| S7 | low | A reminder that fails to be scheduled is dropped without a trace | closed 11-12: logged |
| S8 | low | A catalog seed file for a backend the project does not use (39 KB of invented plans and descriptions) | closed 11-12: deleted |
| S9 | medium | The privacy manifest declared two protected APIs the app does not use (boot time, and disk space under a reason code that does not exist), did not declare the settings it shares with its widgets (reason 1C8F.1), and listed a name and usage data as collected though both stay on the iPhone. The widgets had no manifest at all, though they read shared settings (Apple asks one of every bundle that uses these APIs) | closed 11-12: both manifests rewritten from what the code does; `PrivacyManifestTests` ×3 fails when a declared API is unused or a used one undeclared, and pins what is collected (address, account id, the list and its prices, when age was confirmed) |
| S10 | low | iPad multi-window was switched on, though the app is one phone-width column and nothing was built or tried for two windows | closed 11-12: off |
| S11 | medium | A change of mine on 11-11 (hide the list at sign-out) had two gaps: a Shortcut could add to the hidden list, saving a list of one over the saved copy; and a relaunch while signed out loaded the saved list back, so reminders returned | closed 11-12: signed out, every Shortcut says to sign in and an add is refused; a launch that finds nobody signed in hides the list again. `PauselyAppIntentsTests`, `LocalDataGuardTests` |
| S12 | medium | Threading: built once with complete checking, 58 warnings in 14 files (list in `private/audits/2026-11-12/strict_concurrency.txt`). One is a live fault: the export screen reads the list, the history and the Pause Plan on a background thread | closed 11-12. The export fault first (it runs on the main thread, where what it reads lives). Then the rest, by cause, 58 to 0: the account manager's hand-made table of requests in flight is gone (one refresh loop needs none); shared objects have a stated owner (the usage log, Apple revocation and the reduce-motion check on the main actor; the credentials reader and the notification delegate hold nothing and say so; the currency manager's lock is declared, as `@unchecked`, with the reason beside it); Spotlight receives plain values and builds the system's items on the far side; the three mailbox adapters live on the main actor with the scanner that drives them, which also makes Gmail's twenty-at-a-time fetch touch the adapter from one place. The app and the widgets are now built in the **Swift 6 language mode**, where a new data race is a build error. `ProjectFileTests.testTheAppAndTheWidgetsAreBuiltWithDataRaceChecking`. Debug suite 734 tests, 0 failures; the UI tests (first run to account, sign-in, tabs, add, remove) 15 run, 0 failures on the Swift 6 build, which matters because that mode checks at run time too and a system callback arriving off the main thread would crash; Release builds |
| S13 | medium | "Paused" is a status nothing can set any more (the pause that paused nothing was removed on 11-11), yet it has a section in the list, a switch on the export screen, a colour and a mark; a row an older version left paused is stuck there | closed 11-12: a subscription is active, in a free trial or cancelled. A row an earlier version left "paused" is read as active (that pause paused nothing at the service, so it is still charging), "expired" as cancelled, and neither stops the saved list from loading (`testStatusesSavedByEarlierVersionsAreStillRead`). The list section, the status chip, the export switch and its option are gone |
| S14 | medium | The export: the PDF is English throughout, statuses and frequencies are English words, dates in the spreadsheet file follow the phone's short style (11/12/26 reads two ways) | closed 11-12: the spreadsheet has headings in the reader's language, days as 2026-11-12 (read one way everywhere), the next renewal rather than the anchor, an empty cell where there is none, and status and period words from the catalog; the printed page is black on white, in the reader's language and direction, with the same money text as the screens. `SubscriptionExporterTests` (`testTheSpreadsheetIsReadableByAnySpreadsheetAndAnyReader`, `testThePrintedPageIsInTheReadersLanguage`). Not yet seen: the page opened in Files in Arabic (Stage E) |
| S15 | medium | Widgets, read line by line: "days until" counts whole 24-hour periods, so from noon the day before a charge the small widget says "today"; once the published charge has passed, the widget keeps showing it as "today" until the app is next opened; one timeline entry reloaded every 15 minutes (the system throttles that); an English fallback line | closed 11-12 with O28 to O30, O33, O34 and S6: both widgets are rebuilt. The app hands them the days each subscription charges on for about a year ahead (`WidgetFeed`, in a folder both targets compile), every time the list changes and every time the app opens, and asks them to redraw. A widget works out what is next on the day it draws and draws again at each midnight, so it is right on days the app is not opened: a charge that has passed gives way to the next, and "tomorrow" is tomorrow at any hour. Ink ground, the serif for the one number, due and soon marked by a symbol as well as a colour, names and amounts hidden on a locked phone. Days are worded by the system in every language; the widgets' fifteen sentences are in their own catalog in five. A tap opens that subscription, also when the tap starts the app (the request is held until the main screen exists; the same now goes for a Spotlight result). Nothing readable yet (a phone not unlocked since a restart) says "Open Pausely" and looks again in fifteen minutes. `WidgetFeedTests` ×13, `WidgetWordsTests` ×4. Seen on the simulator: small, medium, large and the trial widget in the gallery, and a link opening Spotify from a cold start. Not seen: the three Lock Screen sizes, tinted and clear Home Screens, StandBy, Arabic |
| S18 | low | A unit test sometimes failed because the test app's own return to the foreground started a real download of exchange rates under it | closed 11-12: the app's automatic refresh stands down under tests (`refreshRatesWhenDue`); the suite no longer touches the network for rates |
| S17 | medium | Two subscriptions count as equal whenever their ids match, whatever else differs. Nothing in the app is wrong because of it today, but every test that compares lists of subscriptions checks ids only, so those tests cannot fail on a wrong price or date; and the Analysis tab reruns only when the count changes, not when a price does | closed 11-12: two subscriptions are equal when every field is. Run against the whole suite, every list comparison still held, so those tests were right and can now fail; the one test that pinned the old rule is replaced by its opposite |
| S19 | medium | A cancelled subscription cannot be brought back: there is no "I'm paying for this again". The only ways are Pause Plan (Pro) or adding it a second time, which leaves two rows | closed 11-12: a cancelled subscription's page has "I'm paying for this again". It charges from today, on this day of the month, which closes its line on the Savings Receipt; on a full free plan the upgrade page opens and nothing changes. `StartAgainAndVerdictFactsTests` ×3 |
| S16 | low | Shortcuts, read line by line: results are English with hand-made plurals (T86), Delete asks for no confirmation, Add takes zero, negative and empty values (O31 confirmed) | closed 11-12 with O31 and O32: the Shortcuts are rewritten. Four remain (what renews next, what it all costs a month, one subscription's details, add one); counting and deleting by voice are gone, the first because it told nobody anything, the second because it has no undo. Every answer and every refusal is in the reader's language, days are worded by the system, and one answer no longer formats two amounts two ways. Adding takes what a form takes: a name, and a price above zero and under the ceiling. Two questions can be asked of Siri ("What renews next in Pausely", "What do my subscriptions cost in Pausely"), with their phrases in five languages built into the app. `PauselyAppIntentsTests` ×13. Not seen: the Shortcuts app and Siri themselves |

Scan status (16 areas). Done before the run resumed: engineering 1, 5, 8, 9; overlooked 1 to 4. Done
on 11-12 by reading, with what was found in the table above: engineering 3 (concurrency, measured by a
build with complete checking), 4 (error handling: every `try?` and every `catch`), 6 (persistence:
every saved key, file and Keychain item), 7 (backend files), 10 (widget and App Intents, every line);
overlooked 5 (links), 7 (account lifecycle), 8 (privacy manifest, Info.plist, entitlements), 9 (launch
states, windows). Engineering 2 (correctness) was read where no test reaches: the notification
delegate, the export, the root view's start-up; logic with tests was not re-read. Overlooked 6 (plans
and limits) is O37 and nothing else was found.

### 6.4 Open: truth and need on screen, translation, the listing

| Id | What | Status |
|---|---|---|
| T60, T61, T63 | 717 unsourced English cancel steps; 68 US phone numbers shown worldwide; a rating sheet whose ratings nobody can see | closed 11-11. The service data keeps only each service's cancellation link and names (4,225 lines to 428; 202 services). The unsourced steps, phone numbers, e-mail addresses and chat links are gone, with the "Call support" rows. Steps are shown only where they can be checked: a subscription Apple bills gets Apple's own four steps, read from support.apple.com/118428 (published 2026-09-29), in five languages, and Apple's link opens the person's subscriptions. Everything else gets the link and one sentence saying cancelling happens on that service's own site. The rating sheet and its service are deleted (the `cancel_difficulty_ratings` table stays until it can be dropped by the two-step rule). Seen on the simulator for Apple One and Netflix. The links: `scripts/links/check_links.py` requested all 1,120 on 11-11. 416 were dead (404, or no such domain), 44 of them among the known services: more than one tap in three on "Open Cancellation Page" would have met "page not found". Each dead link now points at its site's front page where that answers (the screen then says "Open Website"), and is removed where the whole site is gone (40 uses; Showtime's entry with it). Six of the most used (Amazon Prime, Paramount+, HBO Max, Strava, Coursera, Box) were given their account page after each was requested and seen to lead to sign-in for that page. 1,018 links now: 809 answer, 184 exist behind sign-in or a robot check, 25 gave no clear answer (kept, to be asked again), none gone. `LinkCheckTests` fails if the app offers a link that was never requested or is recorded as gone. Honest limit: a request shows a page exists, not that it is the right page |
| T42, T76 | 21 of 27 first-run prices come from press round-ups, not the service's page, and are saved as if confirmed | closed 11-11: every price on the first-run grid (and so every price the plan sheet suggests) now names the page it was read from and the day. Each of the 21 was looked up on the service's own page: ten could be read (seven in US dollars, three in Canadian, since pages are served for Canada from here), and two of the eight US figures were wrong in the app (PlayStation Plus 10.99, not 9.99; Disney+ 12.49, not 11.99). The eleven whose pages could not be read (YouTube Premium, Amazon Prime, ChatGPT Plus, Hulu, Peacock, Duolingo, Crunchyroll, Kindle Unlimited, DashPass, Walmart+, Planet Fitness) have no price: the person is asked. `testEveryPriceNamesThePageItWasReadFromAndTheDay`. Cost, said plainly: a US customer now types the price for eleven popular services instead of seeing a figure; reading those pages from a US connection would give them back |
| Scope C | Catalog: 1,379 invented plan prices, invented descriptions (Pausely's own says "bank sync"), invented websites used for logos, plan variants listed as services | closed 11-11, except the subscription record's own unused fields. A catalog row is a name, a category and a link that was requested and answered: the 1,379 plan prices, the descriptions, bundle ids, invented websites and the validator are deleted (about 5,500 lines of data become 863), Pausely no longer lists itself, and plans of one service are not rows of their own (993 rows to 848). Logos come from Pausely's own list of sites, else from the site of the checked link, and are asked only of the service's own site (the lookup service that was told each address is no longer used). The plan choice nothing offered is gone with `selectedTier`, `userPriceUSD` and `isPriceOverridden`. `CatalogTests`, 5 tests; 614 in the suite, 0 failures; Release builds; browse screen seen on the simulator. The record's own unused fields: closed 11-12. Fourteen of its 25 fields were read by nothing (the eight named before, and the owner's id, a bundle id, "detected", and a changed-at time that was only ever written). They are gone from the model and from what is sent; a subscription has eleven fields and `SubscriptionFieldTests` fails on one that nothing reads. Pausely's own line is known by its name, on every device, where it was known by a mark only the phone that added it held. The live table needs only owner, name and amount on insert (read on 11-12), so nothing else has to be sent; it still has twenty columns nothing uses, to drop by the two-step rule when the owner says. 662 tests, 0 failures |
| T25–33 | "Deep savings analysis": English only, invented thresholds, a figure that always equals the price, overlap matched by substring on cancelled items too | closed 11-12: the engine is deleted (368 lines: thresholds, "confidence" figures and English sentences nobody could source). What was real in it is kept as plain arithmetic on the person's own figures (`UsageFacts`): Insights shows what an hour of use cost this month for each subscription they typed hours for, and which ones they entered as not used, for everyone, in five languages; hours can be typed in any keyboard's digits. `UsageFactsTests` ×8; seen on the simulator (Netflix, 2 h 20 min, $6.85 an hour). Pro therefore lists the two things it has, unlimited subscriptions and Pause Plan (`testProUnlocksExactlyWhatExists`): a third reason to pay has to be built, not written (Stage F and the owner's call) |
| T50–56 | In-app Privacy Policy and Terms: untrue lines (analytics, push, price alerts, a licence to use data), English only, a second copy beside the website's | closed 11-11: the in-app copies are deleted. Each policy has one copy, on the website, shown inside the app from Privacy & Security and from account creation (`LegalPage`; seen on the simulator). With the name placeholder on the add screen translated, `testEveryScreenIsTranslated` passes: the unit suite is fully green for the first time (609 tests). Still to check under the listing rows: that the website's own text is true |
| T34–38 | Paywall: cancelling Apple's sheet raises "Purchase Error"; restore outcomes all read "Purchase failed"; "Apple ID" path is out of date; two different last days to cancel | closed 11-11: each outcome has its own words in five languages (`PaywallNotice`), and closing Apple's sheet says nothing (seen on the simulator: cancel, no alert). The path reads "open Settings, tap your name, then Subscriptions" on the paywall and in the delete-account warning. The slip says "Cancel by" the day before the first charge, which agrees with the 24-hour line under the button (seen: first charge Nov 18, cancel by Nov 17) |
| T97–99, T80–86, T70, T67, T89 | Untranslated: the welcome screen's six lines, edit-screen rows, age gate buttons, every Shortcut result, a notification, every widget string; 15 counts with no plural forms ("1 subscriptions") | part done on 11-12: every Shortcut result (S16), every widget string (S15), the three messages under the edit fields (O10), the status words. Then the welcome screen, the lifetime-cost labels and the plural forms (T101, O12). The build's own list of strings now matches the catalog exactly, so nothing a `Text` or `L10n.string` shows is missing a translation. The export now goes through the catalog (S14). German addresses the reader formally throughout: 71 "du" sentences and 21 commands without a pronoun ("Tippe auf …") rewritten, one in the widgets; `OneLocaleTests.testGermanAddressesTheReaderOneWay` reads all three catalogs and checks its own rule. French is "vous" throughout and Spanish "tú" but for one sentence. Closed 11-12 by a word-by-word read of all 784 strings in the five languages (app, widgets, Shortcuts): about 190 values corrected. The first tab was "Zuhause", "Hogar" and "Maison"; German and Japanese had two words for a subscription and for a trial; French and Japanese used the word for dismissing a dialog where a subscription is cancelled; Spanish mixed "mantener" and "conservar", "quitar" and "eliminar", Spain's and Latin America's words, and two genders for "it"; quotation marks were mismatched in German and plain in Arabic; Apple's, Google's and iOS's own labels checked against their pages (support.apple.com/118428 in each language). Held by `OneLocaleTests` (`testGermanAddressesTheReaderOneWay`, `testASubscriptionAndTheFirstTabHaveOneWordInEachLanguage`). What a test cannot hold: whether a sentence reads well to a native speaker. That is one person's read per language and belongs to the owner (6.7) |
| T101 | About 940 unused string keys, some carrying old false claims in six languages | closed 11-12: 1,147 keys that no source line uses are deleted (the catalog went from 1,902 keys to the 765 in use; 64,000 lines to 27,000), and ten that were in use but missing are translated, among them the welcome screen's six lines. `scripts/string_usage.py` compares the catalog with what the build extracted from the sources, both ways, and is a line of `gold_check` (0 now) |
| T102–108 | Seven names for Find in Email; "Renewal Verdict" exists only in the listing; five names for Insights; "watch" and "track" | applied in the app on 11-12 (the listing and the website follow with T109–111): "watches" is "tracks" in the eleven sentences about the free plan, the email feature is "Find in Email" on Home, the catalog and Profile. Decided 11-12 (each changed sentence needs its five translations). The names: **Find in Email** (the feature that reads receipts, everywhere); **Home**, **Subscriptions**, **Insights**, **Profile** (the tabs; never "dashboard" or "analysis"); **Your year in subscriptions** (never "Wrapped"); **Free** and **Pausely Pro** ("Pro" after the first mention on a screen); the free plan **tracks** five subscriptions ("watches" read as jargon in the first customer round); the keep-or-cancel question has no name in the app, so the listing describes it in the app's words; "subscription", never "sub"; sentence case except for these names. Applied 11-12 (second pass): the day a subscription renews is the **renewal date** on every screen (it was the "payment date" on three and "Next payment" on four), **Add your own** replaces "Custom" and "Add Custom", the cards are **When to cancel** and **Cost over time** ("Lifetime Cost" promised a lifetime), "Export Data" is **Export your list**, and 45 labels left Title Case and all-capitals. The button that opens iOS Settings says "Open Settings", so French can say "Réglages" there and "Paramètres" for the app's own. Stored category names are untouched. `OneLocaleTests.testEnglishLabelsAreInSentenceCaseAndTheRenewalDateHasOneName` |
| T109–111, generator | Listing: "with their plans and prices", "900+ cancel links", "weekly spend"; `scripts/store_copy.py` would put "cheaper alternatives" back if run | closed 11-12 for the listing (the website is the next row down in 5.2). The eleven locale files were rewritten: 800+ services (848 counted) and no prices, the cancellation page of 500+ services (522 counted; a link to a front page is not one), no weekly total, Pro is "tracks all of them and adds Pause Plan" (it claimed "savings analysis"), "in one tap" gone (Pausely cannot cancel), "Your Subscription Wrapped" is "Your year in subscriptions", "Renewal Verdicts" described in the app's words, what's new mirrors the in-app sheet, the search words "find", "hidden" and their translations gone, the German subtitle no longer says Pausely cancels. The generator and its two pointer documents are deleted; `metadata/` is the only copy. `StoreListingTests` (7 tests): limits, keywords, every number counted from the code and equal in all languages, Pro equal to `ProFeature`, banned claims, the app's own names per language, the same bullets everywhere. `asc metadata validate`: 22 files, 0 errors. Nothing was pushed to App Store Connect |
| Website (found 11-12) | The policy pages the app links to said things the app does not do: reading Screen Time, collecting crash logs and "session duration", data kept in "your region", an export as JSON, deletion requests to pausely.app, two minimum ages (16 and 17), Pro with "deep savings analysis and cheaper alternatives", a referral programme. The waitlist page and its welcome email promised early access, "advanced analytics" and perks, and "unsubscribe" with nothing to unsubscribe with. The three copies of the site had drifted | closed 11-12 in the repository; **not live until the owner publishes (6.7)**. The eight pages in `pausely.pro/` corrected against the code (hosting region read from the project: United States; hours of use and history on the device; no analytics software; CSV export; one minimum age; Pro as `ProFeature`; one answer time, 48 hours). The welcome email says what the next version does, that it is the only email, and how to leave the list; a reply now reaches the support inbox (`reply_to`). `WebsiteTruthTests` (6 tests) reads the pages and the email. `scripts/site_check.sh` shows where the folder, `gh-pages` and `site-next` differ (a line in `gold_check`, 0) and `--sync` commits the folder onto both local branches; both are in line, unpushed. `site-next`'s landing page lost "one tap", "cheaper alternatives", "deep spending analysis", "step-by-step" and "most people". The waitlist rig passes. Legal wording beyond these facts was not rewritten: that review is the owner's |

### 6.5 Open: screens

| What | Status |
|---|---|
| 136 screens and states; 95 cannot be opened by a launch argument, so have not been seen in Arabic, at the largest text or on iPad | in progress 11-12: the tour's `testStates` opens 45 more through a varied demo list, named demo screens and taps; read in English, the other three variants to come. Not opened from here and listed for the end: states that need the network or a purchase to fail (sign-in errors, a wrong code, StoreKit not answering), the system's own sheets, widgets on a Home Screen |
| Apple's audit, English tour: 307 issues (105 Dynamic Type, 98 contrast, 51 clipped text, 36 elements not detected, 13 hit regions, 4 descriptions) | open |
| Not rebuilt: Pause Plan, age check, policy pages, error banner and toast, demo banner (both widgets were rebuilt on 11-12: S15) | closed 11-12: the age check, the banner, the notice and the demo banner are rebuilt and seen in English and Arabic; Pause Plan's wording, edges and tap areas are fixed from its captures (setup, running, empty, the end dialog); the in-app policy pages no longer exist (the policies are on the website); `old_ui_check` prints 0 |
| System-wide: ~~accent colour is iOS blue~~ (done 11-12, from the palette); ~~`Motion.unlessReduced` still moves~~ (done 11-12: `AnyTransition.arriving`); ~~`StateMark` does not grow~~ (done in E slice 2); iPad column is 680 pt wide (seen on the iPad tour and kept: a readable column); ~~five ways to leave a sheet~~ (done 11-12: `LeaveButton`, or the navigation bar's own button); ~~Title Case and sentence case mixed~~ (done 11-12, held by a test); ~~"iPhone" said on iPad~~ (done 11-12, held by a test); prices and dates not formatted in the app's language in 43 places; the serif is missing in Arabic and Japanese | open |
| Per-file findings (colour, type, layout, Dynamic Type, right to left, VoiceOver, motion, haptics, states) in `ui.md` | open |
| Seen in passing on 11-12: on Insights, scrolled content runs under the status bar and the clock is drawn over it | closed 11-12: `inkScreen()` on the four tabs (E first slice) and on every other screen that draws its own top row (E fourth slice); `testAScreenWithoutANavigationBarKeepsTheStatusStripSolid` |
| Arabic, whole tour read (11-12): untranslated rows on the edit screen and the age check, left-to-right sentences, Latin digits in sentences, a 15-point "Done", text under the clock, an unreadable footnote | closed 11-12 (E fourth slice): each held by a test; `scripts/tour_untranslated.py` prints nothing for the screens toured again. Still to do in Arabic: a whole tour on the final build for the count, and one native reader (6.7) |
| Empty Insights tab: a black band down each side in Arabic, at the largest text size and on iPad (found 11-12 on the iPad tour) | closed 11-12: the scroll content is full width and `inkScreen()` paints the whole width; `scripts/tour_black_bands.swift` and the tour's own "scroll view narrower than its screen" finding catch it again |
| "iPhone" said on iPad in 16 strings ("Same as iPhone", "Saved on this iPhone", "Your email never leaves your iPhone" …) and "phone" in two more | closed 11-12: per-device wording in the catalog for all 18, six languages; `testOnAnIPadTheAppSaysIPad`; read on the iPad tour's captures |
| Export: the app makes CSV, PDF and JSON; the policy names CSV only and the JSON file has no test | closed 11-12: the policy names the two machine-readable copies and the PDF (`WebsiteTruthTests` ties the sentence to `ExportFormat.allCases`); the JSON file is a pure function that reads back as the same list and history, with the price as entered (`testTheFullFileReadsBackAsTheSameListAndHistory`), and each choice on the screen writes the file it names (`testEachFormatWritesItsOwnFile`) |

### 6.6 Open: engineering hygiene

Test bundles share the app's bundle id; the shared scheme runs tests in parallel; strict concurrency is
off; project backups and per-user Xcode data are tracked; an empty build-file entry; development
signing identity on Release; the xcconfig files are decoration (real values sit in the project file);
two classes own StoreKit state; 7 Swift files over 700 lines; 17 hype names.

Stage G, as it closes (each line: what, and the evidence):
- Dead code, 11-12: `gold_check` "declarations nothing refers to" 13 → 0. Eight were code only tests
  called (a contrast helper, now in its test file; `canResend`; `extractChargeAmount`; a test-only
  factory and reader on `WidgetDataStore`; an unused launch price; an unused key name; an old-style
  preview). Five were not dead: the system starts or lists them (`@main`, App Intents, the Shortcuts
  provider), and the checker now knows that rule instead of a list of names. Proven able to fail
  with a throwaway probe. The "TODO" check reads comments only ("XXX" is also the ISO code for no
  currency, used by two tests); probe-tested too. `gold_check` 61.
- Hype names, 11-12: nine types and three files renamed to what they are (`AuthManager`,
  `MainTabView`, `SubscriptionsView`, `ProfileView`, `SignUpView`, `SignInView`, `SplashScreen`,
  `WelcomeFlow`, `AddSubscriptionView`; `CancelSubscriptionFlow.swift`). The check now reads file
  names too (probe-tested). `gold_check` "hype names" 9 → 0, total 52. 727 tests, 0 failures.
- Design lint, 11-12: 47 findings → 0. Colours: three named tokens (`Color.outline`, `.track`,
  `.outlineFocused`) replace eighteen hand-mixed whites, and the check now sees plain `.black` and
  `.white` (probe-tested; it found two more in Pause Plan). Type: every size written as a bare
  number is gone; the big amounts use `Font.total` with a size that scales with the reader's text
  (three amount fields did not scale at all), symbols use text styles. Motion: `Motion.fade` added;
  five raw curves replaced. Radii: `Layout.markRadius`; eleven numbers replaced. Pause Plan's start
  button is the design system's main button, not a hand-made white one, and its small pill buttons
  have a 44-point place to tap. `gold_check` 5 (the long files). Seen on the simulator: the edit
  screen. Not seen yet: Pause Plan with a plan to start (its demo opens the empty state), and the
  edit screen's "Next renewal" row sets its date under the label instead of beside it; both go to
  Stage E's pass over those screens.
- Long files, 11-12. Three real splits along seams that needed no member made less private: the
  found-subscription row left the inbox screen (`Views/Inbox/FoundRow.swift`); what the Keychain
  remembers about the account left `AuthManager` for `AccountMemory` (and a dictionary nothing ever
  filled, two empty headings and one that said "REVOLUTIONARY" went with it); the engine's five
  model types have their own file. Said plainly: the check's measure was changed, from raw lines
  to lines of code, because the two files still over 700 raw lines (the receipt analyzer 790, the
  engine 778) are each one algorithm whose helpers are private, and a quarter of their lines are
  the comments that make them readable; cutting them further meant un-hiding a dozen helpers. They
  are 625 and 624 lines of code. `CatalogData.swift` (a table of 848 rows) is left out by name.
  `gold_check` **0**. 727 tests, 0 failures. Not proven by a test: that a session is still restored
  at launch after the move (the code is the same lines in a new place; a test would write to the
  simulator's real Keychain). It is checked in Stage H's first walk from a signed-in start.
- The project file, 11-12: the unit and UI test bundles have their own bundle ids; the shared
  scheme runs tests one at a time (a run without the command-line flag made no simulator clones);
  the widget no longer links ActivityKit; the build entry with no file is gone; the three
  `.xcconfig` files and their template are deleted (one base file fed a setting nothing read, two
  were attached to nothing, and one listed keys for RevenueCat, Plaid and OpenAI, which the app
  never used), with the plist key they fed and the README line that sent people to them. No
  backups or per-user Xcode data are tracked any more. `ProjectFileTests` (3 tests). Debug suite
  730 tests, 0 failures; Release builds, with its server address in the built Info.plist. Left as
  it is, on purpose: "Apple Development" as the signing identity on Release. Signing is automatic
  and ten builds have been archived this way; changing it cannot be checked without an archive and
  an upload, which are the owner's.

### 6.7 For the owner (cannot or should not be done from here)

- The repository is public. Its history still holds business notes (growth, monetisation, data
  monetisation research) and a committed `backend/.dev.vars`. The values looked like scaffold
  defaults, but if any was ever real, rotate it. Decide whether the app repository should be private
  (the website can live in its own public one).
- The README now says no licence is granted. It used to say MIT with no licence file. Confirm.
- Everything already on the list in memory: Supabase email templates and redirect URLs, the pending
  SQL, the edited listing text and review notes, Microsoft client id, the "go" for 1.0.3.
- `pausely.pro/privacy.html` was corrected in the repository on 11-11 and is not published: it now
  names the exchange-rate service and the mail provider that sends sign-in codes, and no longer
  names Google for logos. Publishing is a push of the site; the policy also promises 14 days' notice
  of material changes, which is the owner's call.
- Sign in with Apple revocation (O39) is built and waits for three things only the owner has or
  decides: a "Sign in with Apple" key from the developer account (Certificates, Identifiers &
  Profiles → Keys), the function's four secrets (`APPLE_TEAM_ID`, `APPLE_KEY_ID`,
  `APPLE_PRIVATE_KEY`, `APPLE_CLIENT_ID`), and the word to deploy `apple-revoke` to the live project.
  Then one deletion of an Apple-made test account on a device, to see Apple's sheet and the entry
  leave Settings → Apple Account → Sign in with Apple.
- Time Sensitive reminders (O24): in the developer account, switch on "Time Sensitive Notifications"
  for the identifier com.pausely.app.Pausely. Then the entitlement and one line are added here, and
  "charges tomorrow" gets through a Focus.
- One check on a real iPhone for S1 (the simulator has no data protection): with a renewal reminder
  due, restart the phone and leave it locked; when the reminder arrives, press and hold it and tap
  "Keep it"; then unlock and open Pausely. It must open signed in, with the list as it was.
- One real purchase on a device with a sandbox Apple Account: start the free trial, see Pausely Pro
  join the list at the App Store's price, then refund it in the sandbox and see Pro go without a
  restart. The code paths are tested against stand-in answers; the App Store itself can't be reached
  from the simulator here (no Apple Account, and the local test store refuses purchases in tests).
- Publish the corrected website. The live privacy policy still says the app reads Screen Time and
  collects crash logs, and omits two companies it sends data to. Read `git diff origin/gh-pages
  gh-pages` (legal text: your call), then `git push origin gh-pages`. Until then the app links to
  a policy that is wrong in the ways the "Website" row lists.
- Deploy the waitlist function so the welcome email stops promising early access and perks:
  `supabase functions deploy waitlist-signup --project-ref ddaotwyaowspwspyddzs` (the rig passes
  on the new text; no secret changes).
- When 1.0.3 is on the App Store: `site-next` holds the new landing page, already corrected, and
  now contains everything on `gh-pages` (so it publishes by a plain push, no force):
  `git push origin site-next:gh-pages` after reading it.
- One native reader for each of Arabic, German, Spanish, French and Japanese (15 minutes each, the
  app in that language, eight screens). Every string has been read against its English and the
  terms made consistent (11-12), but whether a sentence sounds like a person wrote it is a native
  reader's call; until then translation is scored on what was checked, not on how it reads.

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
