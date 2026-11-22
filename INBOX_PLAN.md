# Find Everything: reading subscription receipts from every inbox

Written 2026-10-27. This is signature feature #1 in `REVOLUTION_PLAN.md`, and the thing that makes
Pausely stand out: it finds every subscription you pay for from the receipts in your email, without
a bank password, and nothing leaves your iPhone.

**Where it stands (2026-11-18):** one on-device engine reads Gmail, IMAP inboxes and (once Microsoft's
client ID is set) Outlook. It is proven on made-up mail and on stand-ins for the providers, never on a
real sign-in, and every provider is switched off in release builds. Customers get nothing from it
today. The plan to change that is the next section.

**The plan in one line:** turn the Gmail scanner into one engine with an adapter per provider, ship
Outlook/Hotmail first (no Google dependency), then iCloud, Yahoo and AOL through secure IMAP, run a
strict multi-pass "find everything" protocol behind release gates, and keep watching in the background.

**Score journey (out of 10, against the ideal):** today 6.0 on paper (0 for customers) → v1 6.5 →
v2 7.2 → v3 8.2 → v4 8.8 → **v5 9.3**. About 12 weeks of work and under $1,000 a year in fees.
**Verdict: worth it.** It's the highest-return item on the roadmap.

## The 9.5 push (plan of 2026-11-22)

The owner, after the first real Gmail scan: the "Last charged" dates are wrong; fix them so it can't
happen again, hunt every bug in email import, rate it as a consumer with independent agents, work until
it is honestly 9.5, remove dead code, and carry out the four distribution items.

### What the real scan proved wrong (owner's Gmail, checked against the receipts in the ledger)

| Row | Shown | True | Cause |
|---|---|---|---|
| Google One | "Last charged Dec 26" | Dec 26, **2025** | dates printed without a year, so last year reads as next month |
| ChatGPT Plus | "Last charged Sep 3" | Sep 3, **2025** | same |
| Claude | "$31.64, last charged Oct 20" | charged **$148.41 on Nov 10, 2026** after 12 months at $31.64 | the engine keeps only the regular chain; a newer charge outside it vanished with its date |
| Crunchyroll | "Confirmed, last charged May 20" | subscribed May 20 as a Prime Video channel; channels bill monthly and email no receipts | a sign-up shown as the latest charge, and as proven |
| (scan) | 8½ minutes, header step ~5 min with a frozen bar | | Gmail headers paced by back-off; no progress reported in that step |
| Google One insight | "$152.54" next to "$269.99" | one includes tax, the other doesn't | mixed tax in one note |

### Rules that make these impossible (each one is a test)
1. **A date that isn't in this year carries its year**, everywhere a past or future charge day is written
   (rows, insights, reasons, Home, receipts). One formatter; a test fails if a view formats a charge day itself.
2. **"Last charged" is the newest real charge** from that subscription, never older. A newer charge at another
   amount is kept and named ("$148.41 on Nov 10, more than the usual $31.64"); it is not silently made the price.
3. **No charge, no "Last charged"**: a sign-up, trial start or channel subscription says "Subscribed May 20"
   (or "Trial started"), and a store that emails no receipts is never "Confirmed" on a sign-up alone.
4. **One status rule**: a plan with no charge for longer than its period plus grace "may have ended",
   whichever section it was in.
5. **Money in one sentence is all with tax or all without**, and says which when it can't be both.

### Slices (one at a time, each with tests and a commit)
- **D1 dates and charges**: rules 1–3 in the engine, the rows, the insights; real-shape tests with made-up
  details (a year-old yearly charge, a newer off-chain charge, a Prime Video channel sign-up).
- **D2 status and tax**: rules 4–5.
- **D3 speed**: Gmail header reads paced to stay inside Google's per-person quota instead of backing off;
  the header step reports progress; target under 2 minutes for 1,500 candidates, measured on the real inbox.
- **D4 independent consumer rating**: agents that did not build it (Fable, per the owner's rule) read every
  inbox capture (the tour's inbox states, English, Arabic, largest text, iPad) and the real-scan captures,
  rate the eight dimensions of `GOLD_STANDARD.md` harshly, and list defects. Every defect becomes a slice.
  Repeat until every dimension is 9.0+ and the score 9.5, or say plainly which dimension can't get there
  without a device or a native reader.
- **D5 dead code**: an agent in its own worktree removes code nothing calls and files nothing uses, with the
  gold check, unit tests and Release build green; reviewed and merged here.
- **D6 the four items**: Apple's agreement (the Account Holder's; checked again), iCloud (needs the owner's
  app-specific password), Google's "[Action Needed]" email (a reply drafted for the owner to send; never
  sent without their word), ratings (asked for at proven-value moments; a TestFlight beta once Apple allows).

### Progress and the open list (kept current; read this first after a break)

Done 2026-11-22: D1 dates and charges (38fe4cf), D3 pacing and parallel reads (ade2926, 321b185: one
note per coming charge with tax, ten header reads in flight, DEBUG request counters), D5 dead code
(merged from dead-code-cleanup, 3,565 lines), "On your list" (4a7f779). Gmail reply to Google drafted in
the owner's Gmail, not sent (needs the video link and a TestFlight link). Real ledger copy (132 facts)
in the session scratchpad `realmail/ledger-2026-11-22.json`; `testRealLedgerReport` reads it with
`PAUSELY_LEDGER_FILE`. Xcode reinstalls the app when the project changes, which erases a connected inbox:
reconnect (account chooser, no password) before a real scan. Speed still to measure on a quiet Mac.

Independent truth audit (Fable, 2026-11-22): about 7. Each item, fixed or not:
- [x] T1 blocker: trust (+30 after an import) lifts no-receipt rows into "Confirmed: your receipts show
  these renew". Trust may lift to "Worth a look", never Confirmed.
- [x] T2 blocker: one later charge at another amount is made the monthly price (Claude $148.41 is likely a
  prorated upgrade). Keep the plan's price until two charges at the new amount; show the newer one as a
  dated note; "Last charged" stays the newest.
- [x] T3 blocker: a trial end worked out from the email date (+3 or +14 days) is stated as fact ("Trial
  ends Nov 28", "Cancel before Nov 28") and imported. Say "around" and give no cancel-by date unless read.
- [ ] T4 "Emails checked: 1,500" is the cap; say when the search was capped and how far back it reached.
- [x] T5 "Charged 9 times" counts the chain, not the 12 charges held; the proof list skips months.
- [x] T6 "Same amount each time" under a row with a later different charge.
- [ ] T7 totals ignore the ticks, mix tax bases, and count rows never seen charged.
- [ ] T8 an amount with no currency is taken as the person's currency without saying so.
- [ ] T9 already-listed rows keep a different amount/date unsaid.
- [x] T10 "May have ended" rows can be ticked and import as active with a next charge.
- [ ] T11 a store-billed subscription (Prime Video channel, App Store) imports with the service's own cancel link.
- [ ] T12 Google One imports at the old price although the new price was read.
- [x] T13 "Charged after cancelling... worth disputing" when the person may have re-subscribed.
- [x] T14 "raised its price" blames the seller for any rise; one wording everywhere.
- [x] T15 "most likely renewed" after a trial for any merchant, not only stores that send no receipts.
- [ ] T16 a stopped or refused search looks complete; the results page never shows a refused inbox.
- [x] T17 "Senders with only one-time purchases, left out" counts more than one-time purchases.
- [x] T18 "renews in 37 days" counts 24-hour spans; count calendar days.
- [x] T19 "goes up to $269.99 on Dec 26": before tax and "on" for a worked-out date.
- [x] T21 "Yearly renewals are the easiest to forget" has no source.
- [x] T22 "Your card was declined" when the email only said a payment failed.
- [x] T23 "Reading 380 receipts" are emails that might be receipts.
- [x] T25 "Missing renewal dates were filled in from your receipts" can come from a trial or sign-up.
- [x] T27 Prime "Subscribed on" is the day a free trial started.
- [x] T28 an assumed monthly period shown as fact.
- [x] T29 "You told Pausely this is a subscription" (a tap on a pre-ticked row); "structured subscription data" is internal wording.
- [ ] T30 the privacy line "keeps only the name, amount and date" is narrower than what is kept (sender, period, flags).
- [ ] T31 a later scan's "Emails checked" counts only new mail while findings come from all.
- [ ] T32 already-listed is matched by exact name ("Claude" vs "Claude Pro").
(T20 and T24 are covered by commits above.)

Independent reach rating (Fable: iPad, Arabic, largest text, VoiceOver, 2026-11-22): 7.0. Contrast passes;
Arabic mirrors and is fully translated; rows read as one sentence. Open:
- [ ] B1 iPad: the connect form is a form sheet that cuts its text under the keyboard; at the largest size
  the title and steps 1-2 are gone (also full screen at the largest size: opens past its title).
- [x] B3 Arabic: "CA$" is drawn "$CA" (the trailing symbol flips inside an isolate); "US$" the same.
- [x] B4 a failed inbox ("Your sign-in expired. Reconnect this inbox.") has no reconnect action anywhere.
- [ ] B5 iPad: the side margins don't scroll (only the centre column does).
- [ ] B6 Arabic dates follow the device calendar (Hijri on ar_SA); for a native reader to decide. Also
  "منذ ٢٧ ذو القعدة" should be "ذي القعدة".
- [ ] B8 a date broken across lines at the largest size ("around Dec" / "12."); proof lines may overflow.
- [ ] B9-B11 VoiceOver: the "why" button doesn't name its service or state; a connected inbox is three
  stops; the results header is one 40-word heading; "selected" is a word, not the trait.
- [ ] B12 "Charged N times" above fewer proof lines (the list shows the latest eight).
- [ ] B14 "Worth knowing" changes order between launches on the same data.
- [ ] B15 tags repeat their section ("May have ended" under "May have ended"); "Select all" over one row.
- [ ] B16 letter tiles (G, O, H) beside real logos; logos don't scale at the largest size.
- [ ] B17 targets under 44 pt: paste button, Close, Cancel.
- [ ] B18 iPad column stays 640 pt at the largest size; addresses break mid-word.
- [ ] B20 copy: one-item "..." menu, heading punctuation, a lower-case line start, Arabic button voice.

Independent consumer rating (Fable, iPhone, 2026-11-22): 7.0 (trust 7.0, effort 6.5). Open beyond the above:
- [ ] A1 search speed: measure after pacing on a quiet Mac; under two minutes, a bar that follows one count,
  a time estimate, and whether the app can be left.
- [ ] A3 the free limit: "Add 5" then "Nothing new was added" when the list is full (only a footnote warns);
  the person can't choose which five; a trial with a deadline is the one parked "Waiting" (unexplained).
- [ ] A5 one headline count that matches the rows ("We found 7", nine rows, "Add 5").
- [ ] A6 every "Worth a look" row says why it isn't confirmed and what to check.
- [ ] A8 privacy block: what Google asks for ("View your email messages"), what is kept, what is synced once
  added, a policy link, what Disconnect erases.
- [ ] A9 "This isn't a subscription": one tap, permanent, no undo, no confirmation; nothing clears it.
- [ ] A10 a trial row shows no price after the trial.
- [ ] A11 GMX page: "your main password stays private" then "Use your GMX password"; "gmx.net" title for gmx.de.
- [ ] A12 the slip while searching shows food orders as receipts; the bar jumps between phases.
- [ ] A13 nothing found: "Search again" as the main button; no period for "Emails checked"; no route to add by hand.
- [ ] A14 the second Gmail row (app password) beside "Sign in with Google"; disconnect says nothing of what it erased.
- [ ] A15 disabled "Connect and search" gives no reason; the form jumps when the provider is recognised.
- [ ] A16 Google's consent page shows the app icon (purple "P") that the redesigned app doesn't use inside: owner.

## Real accounts, real subscriptions, and Outlook (plan of 2026-11-18)

The owner asked: fix the import from email, make sure every way in works and pulls real
subscriptions, and add Outlook. Everything below is measured or checked, not assumed; each line says
which.

### Where it stands, measured on 2026-11-18

| What | Result | How it was measured |
|---|---|---|
| Engine on the synthetic mailbox (22 subscriptions, six languages, decoys) | 22 of 22 found, 0 wrong details, 0 false positives | `scripts/proof.sh mail` |
| IMAP through the screens (connect, scan, import, relaunch, disconnect) | passes | `InboxWorkflowUITests`, local IMAP server |
| The ten real IMAP servers (iCloud, Yahoo, AOL, Gmail, GMX ×2, WEB.DE, Zoho, Fastmail, Xfinity) | all reachable, TLS ok, a wrong password refused cleanly | `LiveMailboxTests.testRealProviderServers` (made-up login) |
| Gmail and Microsoft Graph APIs | reject a bad token cleanly: one refresh, then "sign in again" | `testRealCloudAPIsRejectBadTokensCleanly` |
| Google sign-in | the page loads for "Pausely" (no client error); cancelling returns quietly | on the simulator, stopped at the password |
| Outlook | **not offered**: `InboxProviderList.swift:25` hides it because `MS_CLIENT_ID` in `Configuration/Info.plist` is empty | read |
| Any provider scanned through a real sign-in | **never** | `testRealConnectedInboxes` has never run |
| Real mail | last sample 2026-11-10 (81 messages); deleted since | memory, section above |
| Release builds | every provider off (`FeatureFlags`) | read |

So nothing is broken on the bench. What is missing is the real world: no real sign-in has
ever been scanned, Outlook can't be chosen, and no customer can reach any of it.

Facts that shape the plan (checked 2026-11-18):
- Outlook.com no longer accepts app passwords over IMAP (basic authentication was switched off for
  personal accounts in September 2024). Microsoft sign-in through Graph, which is built, is the only way.
- Since June 2024 a new Microsoft app registration must live in an Entra directory (tenant). A personal
  Microsoft account can create one; existing registrations are not affected.
- Mail.Read is a permission a person can grant for their own personal account. Work and school
  accounts may need their admin's consent, more so for an app whose publisher is not verified.
- The sign-in already uses PKCE (`OAuthSession`), and its redirect `msauth.com.pausely.app.Pausely://auth`
  is the one Entra generates for an iOS app with this bundle id.

### What "works" means, for every way in

A way in works only when all six hold on a real account:
1. **Sign-in**: a real account connects through the app's own screens.
2. **Transport**: a real inbox at that provider, seeded with the synthetic mailbox, scores what the
   local rig scores: 22 of 22, 0 wrong, 0 false positives. This proves the provider's own search,
   folders, paging and encodings, which no stand-in can.
3. **Real subscriptions**: a real inbox with real receipts yields every live subscription with the
   right name, amount, currency and period, and no false positive in Confirmed or Likely, scored against
   a truth written by hand (kept out of the repository, deleted after).
4. **Failures named on the real server**: wrong password, access revoked at the provider, expired
   token, offline mid-scan, admin consent required (work accounts).
5. **Repeat**: the second scan reads only new mail (IMAP cursor, Gmail history, Graph delta), and ten
   runs in a row give the same result.
6. **Forget**: disconnect leaves no token or password in the Keychain and no fact in the ledger, and
   revokes at the provider where it can (Google).

### The matrix

| Way in | Account needed | 1 | 2 | 3 | 4–6 | Release switch |
|---|---|---|---|---|---|---|
| Gmail (Sign in with Google) | owner's Gmail (real receipts) + a test Gmail (seeded) | owner signs in | test Gmail | owner's Gmail | both | `gmailImportEnabled`, after Google's approval |
| Outlook, Hotmail, Live (Graph) | Entra registration + an Outlook.com test account | after registration | test account | owner's, if any | test account | `microsoftImportEnabled`, after this column passes |
| Microsoft 365 work/school | a tenant the owner controls (the Entra one) | after registration | optional | - | admin-consent message | same switch |
| iCloud Mail | owner's Apple ID with iCloud Mail on, app-specific password | owner | owner's iCloud (seeded folder) | owner's, if it gets receipts | yes | `imapImportEnabled` |
| Yahoo Mail | new Yahoo account + app password | owner | test account | - | yes | same |
| AOL Mail | new AOL account + app password | owner | test account | - | yes | same |
| Gmail (app password) | the test Gmail + 2-Step Verification + app password | owner | test Gmail | - | yes | same |
| GMX, WEB.DE, Zoho | new free accounts (IMAP switched on in each one's settings) | owner | test accounts | - | yes | same |
| Fastmail | 30-day trial | owner | trial | - | yes | same |
| Xfinity | a Comcast customer's account | **nobody has one** | - | - | - | **remove the preset** unless someone can test it; "Other email" still reaches the server |

"Real subscriptions" (column 3) is proven where real receipts live, which is the owner's Gmail. The
engine after the raw message is the same for every provider (`MIMEParser` → extractor → ledger), so
column 2 on each provider plus column 3 on one real inbox proves each way in end to end. If the owner
has receipts in another inbox (iCloud, Outlook), column 3 runs there too.

### Slices, in order (one at a time; each ends with its tests and a commit)

**A. Real subscriptions on the owner's Gmail** (needs only the owner's yes to reading their mail)

Changed 2026-11-18, before it started: the app reads the mail, not Claude. The owner connects their
real Gmail in the app on the test simulator (Google sign-in, columns 1 and 3 at once);
`testRealConnectedInboxes` scans it and prints only what was found (name, amount, period, state,
receipt count); the owner marks each line right or wrong and names what is missing; only the emails
behind a miss are then fetched through the connector (steps 1–4 below, for those alone). The email
never passes through a model, and the proof is the real path a customer takes.

Outlook, 2026-11-18: column 1 passed on a personal account (hudwkim0909@gmail.com consented, token
saved, address read, mailbox searched without error). That mailbox is empty (a Microsoft account named
with a Gmail address receives no Outlook mail), so "Emails checked: 0" was true; columns 2–3 wait for
an Outlook.com address.

1. Fetch a fresh sample through the Gmail connector (read-only): every receipt, renewal, trial,
   price-change and cancellation mail from the owner's subscriptions over two years, plus look-alikes
   (orders, rides, refunds, promotions). Saved as .eml in the session scratchpad, never the repository.
2. Write the truth by hand: each live subscription with amount, currency, period; each cancelled one;
   each look-alike that must not appear.
3. Run `LiveMailboxTests.testRealMailDirectory` and `ProviderWorkflowTests` with
   `PAUSELY_REAL_MAIL_DIR` and `PAUSELY_REAL_MAIL_EXPECT/_REJECT`, score it.
4. Fix each miss in the engine; pin each one in `RealWorldReceiptShapesTests` with made-up details.
   Exit: at least 95% of live subscriptions found, none wrong, no false positive. Delete the sample.

**B. Truth over the wire, a tool that needs no owner** (built before the accounts exist)
1. `scripts/mailtest/seed_real_mailbox.py`: puts the synthetic mailbox (made-up details only) into a
   real inbox with IMAP APPEND, each message with its own date, decoys into Junk and Trash, marked so a
   second run replaces rather than duplicates. Signs in with an app password, or with an OAuth token
   (XOAUTH2) for Outlook. Passwords are read from the macOS Keychain ("Pausely test mailbox <name>"),
   never from a file or the command line.
2. A truth check for a connected inbox: `testRealConnectedInboxes` scores what it found against
   `truth.json` (the same scorer as `MailTruthTests`), so each provider is one command.
3. A runbook in `scripts/mailtest/README` (or this file): seed, connect on the simulator, run, read the score.

**C. Outlook** (the owner's part is step 1; the rest is mine)

Status 2026-11-18: **C1 and C3 done.** Entra app "Pausely", client ID
`856a7218-9a16-4f20-91d9-2529e3b6f9d2`, registered in the Default Directory of the owner's personal
Microsoft account (hudwkim0909@gmail.com; never the school account), for any Entra directory and
personal accounts; redirect `msauth.com.pausely.app.Pausely://auth` (public client); delegated
`User.Read`, `Mail.Read`, `offline_access`, none needing admin consent. Public client flows stay off
until the seeding tool needs them. The ID is in `MS_CLIENT_ID`; `InboxPrivacyTests` holds it to the
registration. Outlook now shows in Find in Email (debug builds) and Microsoft's sign-in page opens for
it. Entra notes that people can't consent to a new multitenant app from an unverified publisher: that
binds work and school directories (C5), not personal accounts. The account that owns the
registration has no Outlook mailbox, so C2 and C4 need an Outlook.com address.

1. Owner, about 15 minutes, with Claude driving Chrome if wanted: create an Entra tenant if there
   is none (Azure portal → Microsoft Entra ID → Manage tenants → Create; a free Azure account works),
   then App registrations → New registration: name "Pausely"; accounts "any Entra directory and personal
   Microsoft accounts"; platform iOS/macOS, bundle id `com.pausely.app.Pausely` (gives the redirect
   above); Authentication → allow public client flows = Yes (for the seeding tool's device sign-in);
   API permissions: Microsoft Graph, delegated, `offline_access`, `User.Read`, `Mail.Read`. Copy the
   Application (client) ID. The ID is not a secret.
2. Before relying on it, check the adapter's assumptions against the real Graph (Graph Explorer, or
   the app once the ID is in): `$search` with `received>=` and `from:<domain>` on a personal mailbox;
   `/me/mailFolders/inbox/messages/delta` with a `receivedDateTime ge` filter; `/$value` returning MIME;
   the `junkemail` and `deleteditems` folders. Fix whatever differs; update the stand-in to match the
   real answers so `ProviderWorkflowTests` keeps telling the truth.
3. Put the ID in `MS_CLIENT_ID`; a test that it is a GUID and that the redirect matches the bundle id.
   Outlook then appears in the list (debug builds).
4. Columns 1, 2, 4–6 on an Outlook.com test account; a work account in the Entra tenant to see the
   admin-consent path and give it its own message.
5. Later, owner: publisher verification (Microsoft partner ID + the pausely.pro domain) so work
   accounts are not blocked and the consent screen shows a verified publisher. Needs the business
   details already on the compliance list. Personal accounts work without it.

**D. Each IMAP provider, one slice each**: iCloud, Yahoo, AOL, Gmail app password, GMX, WEB.DE,
Zoho, Fastmail. Owner: create the account and its app password, store it in the Keychain (one
`security add-generic-password` line, given at the time). Me: seed (B), connect through the screens,
score, the failure paths, ten runs. Xfinity: removed from the presets unless someone can test it.

**E. Gmail through Google sign-in**: owner signs in once with their Gmail (column 3) and once with the
test Gmail (column 2). Owner checks Google's verification status in the Cloud console; the consent page
still shows the old purple "P" logo, which should match the app's icon before Google reviews it.

**F. Release, provider by provider**: a switch is turned on in release only after its six columns
pass, IMAP first (no outside approval), then Outlook for personal accounts, Gmail when Google approves.
With each switch: the privacy explainer, `metadata/` and What's New mention only what is on; App Review
notes get a demo inbox seeded by B (an Outlook.com one, as section 8 says); the privacy label stays
"Data Not Collected" for email. Tour, proof and a device check on TestFlight (once Apple's agreement is
signed) before the build goes up.

### What only the owner can do (each handed over as one step when its slice comes)
1. Say yes to slice A (reading their Gmail through the connector, read-only, deleted after).
2. The Entra tenant and app registration (C1).
3. The test accounts and app passwords (D), and turning on iCloud Mail on their Apple ID if it is off.
4. Google: verification status and the consent-screen logo (E).
5. Later: Microsoft publisher verification (C5).
Cost: nothing, apart from a card that Azure's free account may ask for to verify identity (no charge)
and Fastmail after its trial.

### Risks
- Work and school tenants can block an unverified app; personal accounts are the first target.
- Providers change: Yahoo and AOL have limited app passwords before. The live server check runs in
  each proof so a change shows up.
- Real mail is private: it stays in the session scratchpad, only made-up shapes reach the repository,
  and the sample is deleted when the slice ends.

## Build status (2026-11-10): measured against the standard below

**How it is measured now.** `scripts/mailtest/make_test_mailbox.py` writes a synthetic mailbox (138
messages: 22 subscriptions in six languages and five currencies, real MIME encodings, and decoys such
as orders, rides, bills, transfers, promotions, a forged receipt, Trash and Junk) with a `truth.json`.
`MailTruthTests` scores a scan on name, amount, currency, billing period and state.
`scripts/mailtest/imap_test_server.py` serves the same mailbox so the app's real IMAP stack and
screens are driven end to end (`InboxWorkflowUITests`). A fresh sample of 81 real messages (kept
outside the repository and deleted afterwards) was scored by hand against a written truth.

| Corpus | Before | Now |
|---|---|---|
| Synthetic mailbox (22 subscriptions) | 18 found, 3 with a wrong detail, 1 wrong name | 22 found, none wrong, no false positive |
| Real sample (3 live, 2 cancelled, about 20 look-alikes) | 1 amount wrong (tax read as the price), 1 false positive (an offer read as a trial), 1 live subscription missed | all live ones found with the right amount, cancelled ones shown as cancelled, no false positive |

**What changed in the engine** (each pinned in `ReceiptAccuracyTests`):
- Each figure is judged by its own label, whichever way the line reads ("Total: $22.60" and
  "CA$67.79 Total charged"). A tax, subtotal, shipping or discount line is never the price; the amount
  is the total charged, tax included.
- Offered prices ("plans from", "then", "danach") are never the charge. Mail with an unsubscribe header
  that neither calls itself a receipt nor says anything was charged is a promotion, with or without
  Gmail's label. An invitation to start a trial is not a trial.
- Whole-unit prices, riyals, dirhams, dinars, Arabic-Indic and full-width digits; billing periods in
  every app language.
- The schedule is the longest regular chain of charges: a stray email can't change it, a plan that
  moved from monthly to yearly is yearly, a price rise is found wherever it happened.
- App Store receipts yield each subscription with its own price (`AppleReceipt`), nothing for one-off
  purchases or a family member's copy. An app-store subscription nobody has heard of is still found.
- Stores that send no renewal receipts (Prime Video channels): a sign-up with no cancellation since is
  listed as worth a look. Inside a store, what follows a brand is its plan; from a payment processor
  it is another business.

**What changed in the flow:**
- Connecting starts the search. Receipts print on a slip while it runs. Stopping keeps what was read.
- One importer (`TallyImporter.add`) for first-run lines and mail findings. The free limit is said
  before the tap and after it; nothing is dropped unsaid. Imports keep the category, the period, a
  trial's end and the last real charge date as the anchor.
- The app-password screen puts the steps first and has the system paste button. iCloud signs in with
  the name part first, as Apple documents.
- Reachable from Home's empty state, the add screen and Profile (all behind `FeatureFlags`).
- `InboxPrivacyTests` hold each sentence of the privacy promise: only mail providers are contacted,
  the ledger has no field for email text, access is read-only, disconnecting forgets the inbox.

**Still not claimable** (unchanged): one real sign-in per provider, the Microsoft client ID, Google's
approval. Release switches stay off. Known limits: bodies larger than the fetch cap are cut; a store
receipt in a layout the reader doesn't know falls back to one fact per email; Google Play's discounted
receipts (the total shows the list price) have no sample yet.

## Build status (2026-11-03)

**Built and tested, still off in release builds** (`FeatureFlags`):
- One engine (`Pausely/Services/Mailbox/`) with Gmail, Microsoft Graph and IMAP adapters, several
  inboxes at once, receipts counted once across inboxes, disconnect removes that inbox's facts.
- Translated: every inbox screen, app-password step, status line, error and the engine's reasons and
  insights in Arabic, German, Spanish, French and Japanese, with plurals (Arabic dual included).
  `LocalizationGuardTests` fails the build's tests if a code-built string, screen literal or
  `MailboxError` message has no translation, or a translation drops a format specifier.
- IMAP presets checked against the live servers (TLS, capabilities, clean wrong-password handling):
  iCloud, Yahoo, AOL, Gmail app password, GMX (two), WEB.DE, Zoho, Fastmail, Xfinity. Mail.com and
  Yandex were dropped (unreachable).
- Real-data run: 27 real emails from a real inbox (kept outside the repository). It finds every live
  subscription in the sample with the right amount and billing period and none of the orders,
  rentals, rides, promos or cancelled channels, through each path:
  - IMAP: the app's own scanner against a local IMAP server (`LiveMailboxTests`), and the whole
    flow through the screens (`PauselyUITests/InboxWorkflowUITests`: suggested server, a server that
    doesn't exist, a wrong password, connect, scan, import, relaunch, disconnect).
  - Gmail and Outlook: `ProviderWorkflowTests` serve the same mail through stand-ins for the Gmail
    and Graph APIs (paging, throttling, token refresh and revocation, expired history and delta
    links, a next-page link to another server, Junk and Spam), so the real adapters run unchanged.
- Bugs that real mail exposed and that are now fixed and pinned in `RealWorldReceiptShapesTests`:
  Stripe "Qty 1" read as an order; service periods ("Oct 20–Nov 20") ignored; "cancellation policy"
  read as a cancellation; "then $269.99/year" picked over the price charged; "Amazon Prime Video"
  read as Prime; channel cancellations attached to Prime Video; footers ("You received this email",
  "Refund Policy") flipping the meaning; declined cards counted as charges; gaps in receipt history
  hiding a monthly plan; App Store and Play apps lumped under "Apple"/"Google".
- Workflow bugs fixed on 2026-11-03: deleting the account during a scan left the inboxes and their
  receipts behind (a scan finishing late saved them again); a wrong server name or port waited out
  the full timeout (up to 40 s) and said only "Timed out connecting" (now immediate, with what to
  check); connection errors in English only; app passwords pasted with Google's and Yahoo's display
  spaces; the help link named the wrong page; a 20-point options button.

**Ratings (2026-11-03)**, seven dimensions (accuracy 30, UX 20, polish 15, copy 10, accessibility 10,
errors 10, performance 5):

| Workflow | Before this pass | Now | What stops a 9.5 |
|---|---|---|---|
| Gmail (Sign in with Google) | 8.8 | 9.1 | One real sign-in on a device; Google's restricted-scope verification before release |
| iCloud Mail | 8.4 | 9.0 | One real sign-in; the app-password detour (Apple offers nothing else) |
| Gmail (app password) | 8.4 | 9.0 | Same as iCloud |
| Yahoo Mail, AOL Mail | 8.25 | 8.85 | One real sign-in each (their SEARCH has never seen a real mailbox); app-password detour |
| Other email (any IMAP) | 8.05 | 8.85 | Servers vary; app-password detour |
| Outlook, Hotmail, Microsoft 365 | 7.5 (capped) | 7.5 (capped) | Unusable until `MS_CLIENT_ID` is set; the code scores 9.1 like Gmail |

**Before turning any provider on in release:** the Microsoft app's client ID in `MS_CLIENT_ID`;
one real sign-in per provider on a device (`LiveMailboxTests.testRealConnectedInboxes`); the gates
in section 5; and Google's decision for Gmail.

## The standard (2026-11-11): what must be true before mail is called fantastic

**Accuracy**, measured on every corpus (the synthetic scorecard, `RealWorldReceiptShapesTests`, the
reference shapes, and a fresh real-mail sample kept outside the repository):
- No wrong subscription in "Confirmed" or "Likely". A one-time order, ride, ticket, bill, transfer
  or promotion never appears there.
- At least 95% of the subscriptions that have a receipt in the corpus are found.
- Everything found has the right amount, currency and billing period. A next date is either read
  from the receipt or shown as expected, never stated as fact.
- One receipt that lists several subscriptions yields each of them.
- No message makes the parser crash or hang.

**Flow**
- The search starts by itself once an inbox is connected; findings appear while it runs; it can be
  stopped at any moment and keeps what it found.
- One tap imports. The free limit is handled in the open: the person sees what was found, what is
  watched, and what waits.
- Imports keep the category, the trial end and the cancel link.
- Every failure names what happened and what to do: wrong password, two-factor needed, server not
  found, offline, sign-in cancelled, access revoked, throttled, nothing found.
- Reachable from where a person looks for it: Home when the list is empty, the add screen, Profile.

**Trust**
- A test proves the app contacts only the mail provider during a search, that the ledger holds no
  email text, and that disconnecting wipes that inbox's facts and secrets.
- Every sentence about privacy on screen is covered by one of those tests.

**Coverage and repetition**
- Each route (Gmail, Outlook, iCloud, Yahoo, AOL, Gmail app password, other IMAP) passes end to end
  through the screens or its API stand-in, ten runs in a row.
- English, Arabic, German, Spanish, French, Japanese; the largest text size; iPad; VoiceOver labels.

**Not claimable without the owner**: one real sign-in per provider, the Microsoft client ID and
Google's approval. Until then the release switches stay off and no release screen mentions mail.

---

## 1. The "10": what the ideal inbox scanner does

Every option, including each version of this plan, is scored on ten weighted dimensions.

| Dimension | Weight | What a 10 looks like |
|---|---|---|
| Coverage | 15 | Reads every major inbox (Gmail, iCloud, Outlook/Hotmail/Live/MSN, Microsoft 365, Yahoo, AOL) plus any IMAP mailbox, and several at once |
| Recall | 20 | Finds at least 95% of the subscriptions that sent a receipt, including App Store bundles, PayPal- and Stripe-billed services, and receipts in any of the app's languages; all of the top 50 billers |
| Precision | 15 | No false positives in the "confirmed" tier: no one-off orders, rides, tickets, promotions or phishing |
| Privacy and trust | 15 | Read-only access, processing on the device, no server copies, only receipts opened, a visible record of what was read, one-tap disconnect and wipe |
| Lifecycle intelligence | 10 | Trials, renewals, price rises, cancellations confirmed, charged after cancelling, refunds, failed payments |
| Always watching | 8 | Incremental sync and background checks: a new subscription or price rise surfaces within a day |
| Speed and clarity | 7 | First findings in under 60 seconds, results stream in, each finding shows its evidence, one tap to import |
| Multi-account | 4 | Merges findings across mailboxes and payment platforms without double counting |
| Global | 3 | All app languages and currencies (the money engine), regional billers |
| Run cost and risk | 3 | Feasible for a small team, low recurring cost, low approval and App Review risk, testable |

## 2. Who reads mail for subscriptions today

| App | Inboxes | How it reads | Price | Score |
|---|---|---|---|---|
| CentryAI | Gmail, iCloud | "read-only OAuth", processed in real time, "never stored on their servers" | $7.99/mo | 5.4 |
| Track-Subs | Gmail, Microsoft, any IMAP | Read-only; processed during a scan and not stored; rules for 60+ providers, then AI | $6.99/mo, $59.99/yr | 5.4 |
| Suprascribe | Gmail, Outlook, iCloud, IMAP | "Privacy-aware" scan; 25 discoveries | $25 once, $5 single audit | 5.1 |
| CostLoop | Gmail, Outlook | Billing receipts, renewals, invoices | — | 4.4 |
| Pausely today | Gmail (off in release) | On the device: header triage, platform parsers, DKIM checks, structured markup, on-device AI for unclear receipts, a receipt ledger, recurrence proof, tiers and lifecycle | — | 6.0 on paper, 0 for customers |

What the market tells us:
- Competitors process mail on their **servers** and ask you to trust them. Pausely can say what they
  can't: *your email never leaves your iPhone*. The cautionary tale is Unroll.me, which sold receipt
  data from inboxes to Slice Intelligence and settled with the FTC in 2019. Trust is the product.
- Nobody pairs detection with **decisions and proof**: none of them have Pausely's Renewal Verdict,
  Savings Receipt or Promise downstream.
- Nobody publishes accuracy. Pausely can, from its own evaluation suite.
- Bank-linked apps (Rocket Money and others) see charges that send no email, but need your bank login.

## 3. The inboxes

| Provider | Users (est.) | How Pausely connects | Approval | Friction for the user | Order |
|---|---|---|---|---|---|
| Outlook.com, Hotmail, Live, MSN | ~400M (Outlook overall) | Microsoft Graph `Mail.Read` (delegated, read-only); sign-in through `ASWebAuthenticationSession` + PKCE; Graph search and per-folder delta sync | Entra app registration (free). Publisher verification (free, needs a verified business in Partner Center) removes the "unverified" label | One sign-in | **First** |
| Microsoft 365 (work, school) | — | Same app, multi-tenant | Many organizations block user consent to unverified apps; verification helps, and admins may still need to approve | Sign-in, sometimes admin approval | With v1; best effort |
| iCloud Mail (icloud.com, me.com, mac.com) | ~950M | IMAP over TLS (`imap.mail.me.com:993`) with an **app-specific password** (Apple offers no mail OAuth) | None | Create an app-specific password at account.apple.com (two-factor required); Pausely guides each step | v2. On iPhone this is where App Store receipts usually land |
| Yahoo Mail | ~225M | IMAP with a Yahoo **app password** | The OAuth `mail-r` scope needs Yahoo's approval and a Commercial Access Agreement; app passwords need nothing | Generate an app password | v2 |
| AOL | — | IMAP with an AOL app password (Yahoo Inc.) | None | Same as Yahoo | v2 |
| GMX, WEB.DE, Zoho, Fastmail, ISP mail | — | Generic IMAP (app password where required) | None | Varies | v2 |
| Gmail | ~1.8B | Existing Gmail API adapter (`gmail.readonly`) | Google restricted-scope verification (submitted ~2026-10-07). An annual CASA audit is required when data can pass through a server; Pausely's on-device design may be exempt, which Google's developer forums haven't answered (two open threads), so budget $540–720 a year (TAC Security) | One sign-in | When Google approves |
| Proton Mail | — | No mobile API (Bridge is desktop only) | — | — | Not supported; Screenshot Import covers it |

IMAP is implemented with Apple's open-source `swift-nio-imap` (Apache 2.0). Credentials live only in
the iOS Keychain.

## 4. Architecture: one engine, many inboxes

Everything after "a raw email" already works for any provider: `EmailSignalExtractor` → `ReceiptSignal`
→ `ReceiptLedger` (on the device) → `SubscriptionIntelligenceEngine` (tiers, evidence, lifecycle) →
import, Renewal Verdicts and the Savings Receipt.

New in this plan:

```swift
protocol MailboxProvider {
    var kind: MailboxKind { get }                 // .gmail, .microsoft, .imap(host)
    func connect() async throws -> MailboxAccount // OAuth (Gmail, Microsoft) or IMAP + Keychain
    func search(_ pass: SearchPass, since: Date) async throws -> [MessageRef]   // provider-native search
    func headers(_ refs: [MessageRef]) async throws -> [MessageHeaders]          // cheap triage
    func body(_ ref: MessageRef) async throws -> RawEmail                        // only when triage says so
    func changes(since cursor: SyncCursor?) async throws -> (refs: [MessageRef], cursor: SyncCursor)
    func disconnect() async                       // revoke token, delete Keychain items and cursor
}
```

- **Adapters:** `GmailProvider` (refactored from `GmailSubscriptionScanner`), `MicrosoftGraphProvider`,
  `IMAPProvider` (iCloud, Yahoo, AOL and generic presets).
- **Multi-account ledger:** signals carry their account; merge by merchant, amount, date and receipt ID
  so the same charge forwarded to two inboxes counts once.
- **Data flow:** iPhone ↔ the mail provider's servers only. No Pausely server ever sees a token, a
  header or a byte of mail. The ledger keeps derived facts (merchant, amount, currency, date, cadence),
  never email text.

## 5. The strict regimen: Pausely's inbox protocol

Each scan runs the same passes, and each release must pass the same gates.

**Passes**
1. **Connect read-only.** The narrowest scope each provider offers; tokens and passwords in the Keychain.
2. **Provider's own signals first.** Gmail `category:purchases`; Outlook focused/other classification;
   folder hints such as "Receipts".
3. **Biller sweep.** The sender domains of every known biller: the 123 built-in profiles plus domains
   for the 1,192-service catalog (a one-time data job), sent as batched OR searches.
4. **Platform sweep.** Receipts from platforms that bill for others: Apple (App Store receipts that
   list several subscriptions), Google Play, PayPal, Stripe, Paddle, Chargebee, Recurly, Shopify,
   Amazon, Microsoft, Patreon, Substack. Each has its own parser.
5. **Language sweep.** Billing and lifecycle phrases in all 11 store languages ("receipt", "renews",
   "free trial ends", "price change", "subscription cancelled", "payment failed"): today the lexicon
   is mostly English with some French, Spanish and German.
6. **Triage, then read.** Headers first; a full body only when triage says it's financial; a body
   budget per scan.
7. **Extract and verify.** Amount, currency, cadence and plan; DKIM and SPF alignment with the sender
   (a "Netflix" receipt that isn't signed by Netflix never reaches the confirmed tier); schema.org
   markup; Apple's on-device model for unclear cases.
8. **Prove.** Recurrence over time, merged across inboxes and platforms; tiers (confirmed, likely,
   worth a look) with the evidence shown: "3 receipts from netflix.com (verified), last Oct 3, US$15.49".
9. **Watch.** Incremental sync (Gmail history, Graph delta, IMAP UIDNEXT/CONDSTORE) on a nightly
   background refresh; alerts feed reminders, Verdicts and the Savings Receipt.

**Release gates** (an extension of the existing `MailboxEvaluationTests` scorecard)

| Gate | Threshold |
|---|---|
| Precision | 0 false positives in confirmed or likely, on every corpus |
| Recall | ≥ 95% per provider corpus; 100% of the top 50 billers |
| Phishing | Spoofed receipts without DKIM alignment never reach confirmed |
| Languages | Receipts in all 11 languages: correct amount, currency and cadence |
| Formats | One corpus per provider (Gmail JSON, Graph JSON, raw IMAP MIME) with the same expected results |
| Privacy | A network test: during a scan the app contacts only the provider's hosts |
| Speed | First findings under 60 s and a full scan under 5 minutes on a 5,000-message mailbox (device) |

## 6. Scoring rounds

| Version | Adds | Score | Why it moved |
|---|---|---|---|
| Today | Gmail engine, off in release | 6.0 | Strong precision and privacy, but almost no coverage |
| **v1** | `MailboxProvider`; Gmail adapter; **Microsoft Graph** for Outlook, Hotmail, Live, MSN and Microsoft 365 | 6.5 | Ships without waiting for Google; coverage up |
| **v2** | **IMAP** for iCloud, Yahoo, AOL, GMX and others, with guided app-password setup; multiple accounts | 7.2 | Covers the big four; iCloud brings App Store receipts |
| **v3** | **The strict regimen**: domain map, platform parsers, 11-language lexicon, DKIM gate, per-provider corpora and release gates | 8.2 | Recall and precision reach the ideal's level |
| **v4** | **Always watching**: incremental sync, nightly background refresh, lifecycle alerts wired into reminders and Verdicts | 8.8 | Lifecycle and watching move from 3 to 9–10 |
| **v5** | **Proof and trust**: a "scan receipt" (searched, opened, uploaded: 0), evidence and a verified-sender badge on every finding, network test, one-tap wipe, a privacy explainer, publisher and Google verification | **9.3** | Trust, clarity and coverage near 10 |

**What keeps it from a 10:** email can't see subscriptions that never send a receipt (bank and card
data would, at the cost of the "no bank password" promise; Screenshot Import is the bridge), and Proton
users can't be read on iOS.

**Cut, because the time isn't worth it:** Yahoo's OAuth partner route (app passwords give the same
access with no approval), Proton, server-side forwarding addresses (they would break the
on-device promise), and admin-consent tooling for Microsoft 365 organizations.

## 7. Worth the money and time?

**Cost**
- About 12 weeks of build: v1 2.5, v2 3, v3 3, v4 2, v5 1.5.
- Fees: Microsoft $0, Yahoo/AOL/iCloud $0, swift-nio-imap $0, Google CASA $540–720 a year if
  required. Optional outside privacy review: $2,000–5,000.
- Owner time: about a day of paperwork (Microsoft Partner Center, Google follow-up, the review mailbox).

**Value** (assumptions from `REVOLUTION_PLAN.md`)
- Today automatic detection reaches 0% of customers; after v2 it covers the large majority of personal
  inboxes, and iCloud covers most App Store receipts on iPhone.
- Automatic detection is the plan's biggest activation lever. If it lifts install-to-paid from 3% to
  4.5%, then at 20,000 installs a month (gate G1) that's about 300 more payers a month, roughly
  **$12,600 more ARR for each month of installs**; at 100,000 installs a month (G3), about $63,000.
- It makes the planned price step to $39.99 a year credible, and it's the press story: *"finds every
  subscription in your email, and your email never leaves your phone."*

**Verdict:** about 12 weeks and under $1,000 a year buys the feature the whole product is positioned
on. It pays back within the first month of meaningful installs. **Build v1–v5 in order.**

## 8. Release order

1. **v1 Outlook** behind a feature flag; ship once the gates pass and the Microsoft app is registered.
2. **v2 iCloud**, then Yahoo, AOL and generic IMAP.
3. **Gmail** turns on when Google approves (`FeatureFlags.gmailImportEnabled`).
4. **v3–v5** land continuously; every release must pass the gates in section 5.

App Store: the privacy label stays "Data Not Collected" for email, because nothing leaves the device.
The review notes need a demo Outlook mailbox with sample receipts.

## 9. Only the owner can do these

1. Register the Microsoft Entra app (personal and work accounts, redirect `msauth.com.pausely.app.Pausely://auth`)
   and complete publisher verification in Partner Center. This needs the legal business details already
   on the compliance list.
2. Follow up with Google on verification, and ask in the review whether an on-device-only app needs CASA.
3. Create a review mailbox (Outlook.com) and forward a dozen sample receipts to it.
4. Approve the privacy explainer wording on pausely.pro.

## 10. Risks

- **Approvals stall** (Google). Outlook and IMAP don't depend on Google, which is why they go first.
- **App-password friction** (iCloud, Yahoo). Step-by-step guidance with deep links, and a clear
  "why this is safe" note.
- **Provider changes** (Yahoo ending app passwords, Graph throttling). Adapters are isolated; the
  corpora catch format drift.
- **Trust.** One careless sentence costs more than a missing feature: wording and the network test
  are release gates.

## Sources

- Microsoft Graph mail and delta query: https://learn.microsoft.com/graph/delta-query-messages
- Entra consent experience and verified publishers: https://learn.microsoft.com/en-us/entra/identity-platform/application-consent-experience
- Personal-account Graph OAuth guide: https://www.unipile.com/microsoft-graph-oauth-email/
- Yahoo restricted scopes and Commercial Access Agreement: https://developer.nylas.com/docs/dev-guide/provider-guides/yahoo-authentication/
- Yahoo app passwords for third-party mail apps: https://help.yahoo.com/kb/SLN36847.html
- iCloud Mail settings for other mail apps: https://support.apple.com/kb/HT1625
- Google restricted-scope verification: https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification
- Open questions about CASA for on-device apps: https://discuss.google.dev/t/gmail-restricted-scope-is-the-casa-assessment-required-when-mail-is-processed-on-device-and-only-a-derived-subscription-list-reaches-our-server/398372
- CASA Tier 2 pricing: https://tacsecurity.com/esof/
- Email users by provider (estimates): https://clean.email/blog/insights/email-industry-report-2026
- Competitors: https://centryai.app/best-subscription-tracker · https://www.track-subs.com/ · https://www.suprascribe.com/ · https://costloop.app/blog/manage-my-subscriptions-email-scanner/
- Unroll.me and the FTC: https://leavemealone.com/blog/unroll-me-ftc-settlement-explained/
