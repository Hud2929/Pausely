# Pausely: The Brutally Honest Golden Key

Started 2026-11-23. This document is the unforgiving product + engineering rubric for taking Pausely
from a polished manual tracker (**6.2 Consumer / 6.8 Developer**) to an undeniable **≥ 9.5 / 10**
product across every dimension—without compromising a single rule in `ENGINEERING_RULES.md` or
`GOLD_STANDARD.md`.

> **Hard limits that never break:**
> - Nothing is pushed or merged to `main`, submitted to App Review, or written to live Supabase / App Store Connect without the owner's explicit go-ahead.
> - All money goes through `Pausely/Core/Money` (`CurrencyGuardTests`).
> - All dates and reminders follow `ENGINEERING_RULES.md`.
> - All user-facing text exists in all 6 languages (`en`, `ar`, `de`, `es`, `fr`, `ja`) with iPad device variants where `"iPhone"` appears (`LocalizationGuardTests`, `string_usage.py` = 0).
> - `scripts/gold_check.sh` must print **0**.
> - Every privacy, website, and store-listing promise is held by automated truth tests (`PrivacyPageTests`, `WebsiteTruthTests`, `StoreListingTests`, `LocalDataGuardTests`).

---

## 1. Scoring Law (Zero-Mercy Rules)

1. **0.0 to 10.0, never rounded up.**
2. **Evidence or it doesn't count:** Every score ≥ 9.0 must point to concrete code, passing tests that can fail, `scripts/proof.sh` output, opened simulator captures (English, Arabic RTL, Largest Text, iPad), and an independent hostile audit pass.
3. **Weakest-link cap:** Category score = `min(mean(dimensions), min(dimensions) + 0.5)`. Reaching **9.5** requires **every single dimension ≥ 9.0** and mean ≥ 9.5.
4. **Honesty about external gates:** Anything that physically cannot execute on this Mac (e.g., live Google CASA approval, live App Store Connect push, Apple Developer Portal `.p8` secret upload, real-iPhone haptic feel) is explicitly separated as an **Owner External Gate** and never faked—while 100% of the code, local test rigs, migrations, CI, and simulator verification must reach **≥ 9.5**.

---

## 2. The 12-Dimension Rubric

### Consumer Dimensions (6)

| ID | Dimension | Baseline | 9.5+ Bar |
| --- | --- | :---: | --- |
| **C1** | **First 90 Seconds & Discovery** | 5.5 | Zero forced account wall before seeing Home (local-first Guest Mode works immediately); **On-Device Screenshot Import (Apple Vision OCR)** enabled in Release builds so users populate subscriptions + prices + renewal dates in <30s with zero bank login; free users choose *which* 5 subscriptions to track. |
| **C2** | **Everyday Utility & Clarity** | 5.0 | Clean, deduplicated Home (no identical subscription card repeated in Attention and Coming Up); everyday fields people actually need (**Notes**, **Payment Method**, **Cost Split** e.g. 50/50 family plan sharing); 1-tap usage presets + UUID-keyed usage log (never lost on rename). |
| **C3** | **Actionable Cancellation & Refunds** | 5.5 | Verified cancel link + **Cancel Concierge** (one-tap pre-drafted cancellation email + **Refund Helper** for unexpected charges/forgotten trials) + live crowdsourced **Cancel Difficulty** rating (`cancel_difficulty_ratings` / `service_difficulty_scores`) shown right on Verdict & Cancel screens. |
| **C4** | **Core Loop Delight & Insights** | 7.0 | Renewal Verdict + Savings Receipt + Pause Plan + Pausely Promise + **Overlap Detector** on Insights (surfaces redundant subscriptions in the same category with exact combined cost) + iPad scrollable margins. |
| **C5** | **Pro Value & Willingness to Pay** | 4.0 | Pro unlocks an unmistakable, honest value stack (`Unlimited subscriptions`, `Pause Plan`, `Batch Screenshot Import`, `Cancel & Refund Drafts`) while keeping core reminders, Verdicts, Savings Receipt, and basic cancel help free forever; contextual paywall shows exact payback math. |
| **C6** | **Multi-Device Backup & Trust** | 5.5 | Optional cloud account seamlessly upgrades Guest Mode; when signed in, **subscriptions, Savings Receipt / lifecycle history, AND Pause Plan** all sync bidirectionally across iPhone, iPad, and reinstalls; hardware-protected local files; privacy copy matches code 100%. |

### Developer Dimensions (6)

| ID | Dimension | Baseline | 9.5+ Bar |
| --- | --- | :---: | --- |
| **D1** | **Architecture & Modularity** | 6.0 | `DebugLaunchRouter` extracted from `ContentView` (under 300 lines); `UsageLog` keyed by UUID with seamless legacy migration; clean pure-logic boundaries for all new engines (`ScreenshotParser`, `OverlapDetector`, `CancelConcierge`, `LifecycleSync`, `PausePlanSync`, `CancelDifficultyService`); zero files > 700 lines. |
| **D2** | **Data Layer & Protected Sync** | 5.8 | Subscription cache & sync queue moved out of unencrypted `UserDefaults` into `.completeFileProtectionUntilFirstUserAuthentication` `DeviceFile` storage (with automatic migration); complete idempotent sync + merge tests for `subscriptions`, `lifecycle_events`, and `pause_plans`; Guest → Account upgrade tested; `LocalDataGuardTests` 100% green. |
| **D3** | **Database, RLS & Edge Functions** | 5.8 | Consolidated idempotent `supabase/APPLY_2026-11-23.sql` + migration adding `lifecycle_events`, `pause_plans`, `app_store_entitlements`, `subscriptions` everyday columns (`notes`, `payment_method`, `split_count`), `auth.users` → `profiles` trigger, Realtime & `alternatives` lockdown; new `appstore-notifications` Edge Function (ASSN v2) + local test rig; `scripts/dbtest/run.sh` 100% green across all 6 starting states. |
| **D4** | **Discovery Engine Engineering** | 6.5 | On-device Vision OCR spatial parser (`ScreenshotParser`) proven with exhaustive unit tests across Apple Subscriptions, multi-currency bank statements, trials, cancelled rows, multi-screenshot dedup, and existing-list updates; Inbox `T11` store-billed cancel links fixed; two-phase Gmail quick pass implemented. |
| **D5** | **CI/CD, Hygiene & Ship Readiness** | 4.5 | Full `.github/workflows/ci.yml` (gold check, Docker Postgres + Edge Function rigs, Swift unit + UI tests, Release build); `ProjectFileTests` green; `scripts/site_check.sh` 0; all 11 App Store locales + `README.md` + `pausely.pro/` synchronized and verified by tests. |
| **D6** | **Verification, Visual Craft & Truth** | 9.0 | `scripts/gold_check.sh` = **0**; `scripts/proof.sh checks unit mail ui release db` = **100% green**; live simulator screenshots opened and visually inspected across English, Arabic RTL, Largest Text, and iPad; independent hostile Consumer & Developer subagent audits both ≥ 9.5. |

---

## 3. Master Execution Slices

1. **Slice 1 — Foundation, Bug Fixes & CI:** `UsageLog` UUID keying + migration + 1-tap presets; `DebugLaunchRouter` extraction from `ContentView`; `.github/workflows/ci.yml`.
2. **Slice 2 — Local-First Guest Mode + Free-Tier Choice:** Optional Guest Mode directly from First Run & Welcome; seamless Guest → Cloud Account upgrade in Profile; interactive picker letting free users choose *which* 5 subscriptions to track.
3. **Slice 3 — On-Device Screenshot Import (Release-Enabled):** Apple Vision spatial OCR engine (`ScreenshotParser` + `ScreenshotOCR`) + `ScreenshotImportView` (`PhotosPicker`, multi-screenshot dedup, date/price update for existing items, free-tier picker) wired into First Run, Home Empty, Catalog, and Profile.
4. **Slice 4 — Complete Multi-Device Sync, Protected Storage & Database Upgrade:** Protected `DeviceFile` storage for subscription cache & sync queue; `LifecycleSync` + `PausePlanSync`; `supabase/migrations/20261123_*.sql` + `APPLY_2026-11-23.sql`; `appstore-notifications` Edge Function + rig; expanded `scripts/dbtest/run.sh` proven in Docker.
5. **Slice 5 — Everyday Power Fields, Cancel Concierge, Refund Helper, Difficulty Ratings & Overlap Insights:** `notes`, `paymentMethod`, `splitCount` (true personal share math); pre-drafted cancel & refund emails; live `cancel_difficulty_ratings` + `service_difficulty_scores`; Insights `OverlapDetector`; deduplicated Home; expanded `ProFeature` stack.
6. **Slice 6 — Inbox Refinements & iPad Scroll Polish:** `T11` store-billed cancel links; two-phase Gmail quick pass; iPad `.readableScroll()` polish.
7. **Slice 7 — Full Localization, Truth Sync, Visual Inspection & Hostile Independent Audit Loop:** 6-language translations + iPad variants, `pausely.pro/` + `site_check.sh --sync`, `metadata/` + `README.md`, full `scripts/proof.sh` (including `db`), visual captures inspected pixel-by-pixel, independent hostile Consumer & Developer reviews, and iterative fixes until **every dimension ≥ 9.5**.

---

## 4. Running Scorecard Ledger

| Round | C1 | C2 | C3 | C4 | C5 | C6 | Consumer | D1 | D2 | D3 | D4 | D5 | D6 | Developer | Notes |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| **Baseline (2026-11-23)** | 5.5 | 5.0 | 5.5 | 7.0 | 4.0 | 5.5 | **6.2** | 6.0 | 5.8 | 5.8 | 6.5 | 4.5 | 9.0 | **6.8** | Pre-overhaul audit |
| **Round 2 Audit (Post Waves 1–5)** | 9.0 | 9.0 | 9.5 | 9.2 | 9.6 | 8.8 | **9.1** | 9.5 | 8.3 | 8.4 | 8.8 | 9.3 | 9.1 | **8.8** | Exposed ASSN v2 OID/CA/DN gaps, guest first-sync dedup race, PausePlan fractional LWW drift, guest difficulty fetch, Reveal above-the-fold CTA, Custom Add trial toggle |
| **Round 3 Audit (Post Wave 6)** | **9.6** | **9.5** | **9.7** | **9.6** | **9.6** | **9.6** | **9.6** | 9.6 | 9.2 | 8.6 | 9.6 | 9.5 | 9.4 | **9.1** | Consumer passed all 6 dimensions ≥ 9.5 (0 P0/P1, 29/29 screenshots inspected); Dev caught P1 ASN.1 32-bit length-overflow DoS in `appstore-notifications`, P2 failed-first-sync deadlock, and DB rig assertions |
| **Round 4 Final (Post Wave 7)** | **9.6** | **9.5** | **9.7** | **9.6** | **9.6** | **9.6** | **9.6** | **9.6** | **9.6** | **9.6** | **9.6** | **9.5** | **9.6** | **9.5** *(9.58 mean)* | **ALL 12 DIMENSIONS ≥ 9.5 (0 P0/P1/P2)** — `gold_check.sh` **0**, `unit` **936/936**, `mail` **22/22**, `ui` **10/10**, `release` **SUCCEEDED**, `db` **849/849** |

---

## 5. Owner External Gates Checklist (Ready for Owner Approval)

Nothing below was executed without explicit owner permission per `AGENTS.md`:

1. **Git remotes:** Review commits on `redesign` (`git log`), then merge/push to `main` and push local `gh-pages` and `site-next` policy updates when ready.
2. **Live Supabase database:** Apply `supabase/APPLY_2026-11-23.sql` to live Supabase (`ddaotwyaowspwspyddzs`).
3. **Live Edge Functions & secrets:** Deploy `supabase/functions/appstore-notifications` (confirm `APP_STORE_BUNDLE_ID=com.pausely.app.Pausely`, never set `APP_STORE_TEST_ROOT_SHA256` in production) and configure the ASSN v2 Production & Sandbox URLs in App Store Connect; confirm `apple-revoke` Apple `.p8` / Team ID / Key ID secrets.
4. **App Store Connect & App Review:** Archive signed Release build, push `metadata/version/1.0.3/` (`asc metadata push`), and submit to App Review.
5. **Real-device & third-party checks:** Verify physical-device haptics, VoiceOver, Sign in with Apple, live StoreKit sandbox-to-production purchase flow, and Google CASA verification if/when enabling Gmail Find in Email in Release builds.
