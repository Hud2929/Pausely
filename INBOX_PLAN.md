# Find Everything: reading subscription receipts from every inbox

Written 2026-10-27. This is signature feature #1 in `REVOLUTION_PLAN.md`, and the thing that makes
Pausely stand out: it finds every subscription you pay for from the receipts in your email, without
a bank password, and nothing leaves your iPhone.

**Where it stands:** a strong on-device engine reads Gmail, but only Gmail, and it's switched off in
release builds while Google reviews the restricted `gmail.readonly` scope. Customers get nothing from
it today.

**The plan in one line:** turn the Gmail scanner into one engine with an adapter per provider, ship
Outlook/Hotmail first (no Google dependency), then iCloud, Yahoo and AOL through secure IMAP, run a
strict multi-pass "find everything" protocol behind release gates, and keep watching in the background.

**Score journey (out of 10, against the ideal):** today 6.0 on paper (0 for customers) → v1 6.5 →
v2 7.2 → v3 8.2 → v4 8.8 → **v5 9.3**. About 12 weeks of work and under $1,000 a year in fees.
**Verdict: worth it.** It's the highest-return item on the roadmap.

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
