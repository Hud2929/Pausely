# Pausely: App Store Keyword Plan (ASO)

Researched 2026-10-19 from Apple's live search results (US and Canada storefronts) and competitor App Store pages.
Raw data: `scripts/aso_scan_2026-10-19.json`. Re-run or track your own rank after launch with `scripts/aso_scan.py`.

## TL;DR: paste these (English, for en-US and en-CA)

| Field | Limit | Value | Length |
|---|---:|---|---:|
| Name | 30 | `Pausely: Subscription Tracker` | 29 |
| Subtitle | 30 | `Trial & Renewal Reminders` | 25 |
| Keywords | 100 | `cancel,find,alert,manager,manage,forgotten,hidden,bill,cost,recurring,payment,price,increase,track` | 98 |

**French Canada (fr-CA):** Quebec searches in French, the app is already translated, and the French field is almost empty of competition (table below).

| Field | Limit | Value | Length |
|---|---:|---|---:|
| Name | 30 | `Pausely: Suivi d'abonnements` | 28 |
| Subtitle | 30 | `Gestionnaire et rappels` | 23 |
| Keywords | 100 | `annuler,essai,renouvellement,facture,recurrent,paiement,cache,oublie,prix,hausse,alerte,cout,trouver` | 100 |

Verified by script: no word repeats across fields, no duplicates inside a field, no trademarks, within every limit. In Canada the store indexes both your English (Canada) and French (Canada) metadata, so fill in both.

## Why this beats the current listing

1. **The current keyword field is 103 characters, not the 99 the doc claims**, so App Store Connect would reject or truncate it.
2. It spends most of its space on words already in the name (`subscription` three times, `tracker` three times), plus `app`, which is wasted. That leaves about 5 useful new words. The new set has about 14.
3. Tested against 20 phrases people search, the old setup can form **4 of 20**. The new one forms **20 of 20**.
4. `AppStoreMetadata.md` "Set 4" uses competitor trademarks (Rocket Money, Truebill, Trim). Apple rejects listings that do this. Delete it.
5. Two docs disagree about the name and subtitle (`APP_STORE_LISTING.md` vs `AppStoreScreenshots/AppStoreMetadata.md`). Treat this file as the source of truth.

## How the App Store indexes text

- Only three fields are searchable on iOS: **name (30), subtitle (30), keyword field (100)**. The description is NOT indexed.
- Apple combines words across all three fields, so each word should appear once, in the highest-value field that fits.
- Name carries the most weight, then subtitle, then the keyword field. Use singular words, comma-separated, no spaces. Skip `app`, `free`, category names and other companies' trademarks.

## What competitors do

| App | Name | Subtitle | Ratings |
|---|---|---|---:|
| Rocket Money | Rocket Money - Bills & Budgets | Subscription & Expense Manager | 400,406 |
| Bobby | Bobby - Track subscriptions | Easily manage your expenses | 8,014 |
| MonoBoost | MonoBoost Cancel Subscriptions | Subscription Manager & Stopper | 6,008 |
| Subpilot | Subpilot - Cancel Subscription | Find & stop unwanted charges | 5,274 |
| Subscription Manager - Bills | (same) | Manage Recurring Bill Payments | 1,665 |
| SubSeek | SubSeek: Subscription Manager | Cancel Subscriptions & Bills | 591 |

- Everyone fights over `subscription`, `manager`, `cancel`, `tracker`, `bills`. Almost nobody uses **trial, renewal, reminder, alert, price increase**, and those searches are won by apps with 0 to 2 ratings.
- Rocket Money targets broad finance (budgets, credit, net worth). Do not chase `budget` or `expense`: the top results there have 16,000 to 289,000 ratings.
- **Title matching beats ratings.** An app with 2 ratings ranks #4 for "track subscriptions" because the words are in its name. That is why the name holds the head term and the subtitle holds the winnable terms.

## Keyword opportunity map (US storefront)

Difficulty proxy = median rating count of the top 5 (higher is harder). This is NOT search volume; Apple publishes that only in Apple Search Ads (Search Popularity) and, after launch, App Store Connect > Analytics > Search Terms.

### Winnable now (median 2,000 ratings or fewer)

| Phrase | Median ratings of top 5 (US) | Small apps in top 10 | #1 today | Median in Canada |
|---|---:|---:|---|---:|
| trial tracker | 0 | 5/10 | ET Grow - Trial Tracker | 0 |
| subscription reminder | 0 | 8/10 | Bobby - Track subscriptions | 0 |
| subscription cost | 0 | 8/10 | SubSeek: Subscription Manager | 0 |
| renewal reminder | 0 | 8/10 | Renewal Reminder App | - |
| cancel trial | 1 | 10/10 | Trial Alert: Avoid Auto Bills | - |
| subscription alerts | 2 | 9/10 | SubManager: Subscriptions | - |
| subscription saver | 2 | 7/10 | Cancel Subscriptions - Saver | - |
| recurring bills | 570 | 5/10 | Subscription Manager - Bills | 202 |
| find subscriptions | 682 | 6/10 | Subpilot - Cancel Subscription | - |
| manage subscriptions | 682 | 6/10 | Rocket Money - Bills & Budgets | - |
| free trial reminder | 799 | 5/10 | Free Trial Killer | 1,141 |
| forgotten subscriptions | 1,665 | 7/10 | MonoBoost Cancel Subscriptions | - |
| subscription organizer | 1,665 | 7/10 | Subscription Organizer | - |

### Contested but reachable (2,000 to 6,000)

| Phrase | Median ratings of top 5 (US) | Small apps in top 10 | #1 today | Median in Canada |
|---|---:|---:|---|---:|
| price increase alert | 2,078 | 5/10 | Keepa · Price Tracker | - |
| recurring payments | 2,088 | 2/10 | Rocket Money - Bills & Budgets | 0 |
| bill reminder | 4,893 | 4/10 | Bills Organizer & Reminder | 212 |
| bill tracker | 5,062 | 3/10 | Bills Organizer & Reminder | 468 |
| subscription tracker | 5,274 | 6/10 | Rocket Money - Bills & Budgets | 58 |
| subscription manager | 5,274 | 3/10 | Rocket Money - Bills & Budgets | 394 |
| cancel subscriptions | 5,274 | 4/10 | Rocket Money - Bills & Budgets | 394 |
| hidden subscriptions | 5,274 | 5/10 | Subpilot - Cancel Subscription | 243 |

### Avoid for now (over 6,000, led by big finance apps)

| Phrase | Median ratings of top 5 (US) | Small apps in top 10 | #1 today | Median in Canada |
|---|---:|---:|---|---:|
| track subscriptions | 8,014 | 5/10 | Rocket Money - Bills & Budgets | 58 |
| subscription cancel | 171,278 | 4/10 | Subpilot - Cancel Subscription | 332 |

Plus budget/expense terms (`expense tracker` 16,200; `budget tracker` 19,473; `save money` 289,207). Not relevant enough to Pausely to be worth it.

### French Canada: wide open

| Phrase | Median ratings of top 5 | Small apps in top 10 | #1 today |
|---|---:|---:|---|
| suivi abonnements | 0 | 10/10 | Suivi abonnements |
| gestionnaire abonnements | 54 | 10/10 | Gestionnaire d'Abonnements |
| annuler abonnement | 1 | 10/10 | Annuler: Gérer mes abonnements |
| rappel facture | 0 | 9/10 | Rappel de factures | Avizo |
| abonnements | 126 | 8/10 | Annuler: Gérer mes abonnements |

## Rollout and measurement

1. **Before submitting:** sign the pending Apple agreement (App Store Connect currently rejects API calls with "A required agreement is missing or has expired"). Then enter en-US, en-CA and fr-CA metadata above.
2. **Launch week:** run `python3 scripts/aso_scan.py --track Pausely --country us` weekly (and `--country ca`) and log the ranks.
3. **Days 14 to 30:** read App Store Connect > Analytics > Search Terms. Replace any keyword with zero impressions. Name, subtitle and keywords only change with a new app version.
4. **Free volume data:** create an Apple Search Ads Advanced account (no spend needed) and look up the Search Popularity score for the ~30 phrases above.
5. **Later:** add es-MX (it also indexes in the US store), then de-DE and ja-JP since the app is already translated.
6. **Conversion:** Custom Product Pages for "hidden subscriptions" and "trial reminders" audiences; ask for ratings after the first real win (a found subscription), because rating counts decide the contested phrases.

## Listing accuracy: fix before submitting

- The description still sells **Smart Pause** and "one-tap pause & cancel". The pause feature was removed from the app. Apple rejects metadata that promises features the app lacks.
- "Join thousands of users" and "$240/year average waste" are unsupported claims for an unreleased app. Remove or substantiate.
- Do not market Gmail receipt scanning until Google finishes its OAuth review: the feature is limited until approval.
- True headline features to lead with: trial and renewal reminders, price-increase alerts, 1,000-plus service catalog, cancel-difficulty ratings, cost-per-use, multi-currency (CAD), widgets.

## Limits of this research

- No search-volume numbers (Apple does not publish them). Difficulty is a proxy built from live rankings.
- Competitors' hidden keyword fields cannot be seen. Their names and subtitles are public, the rest is inferred.
- Rankings were captured on one day and can shift. Re-run the script before relying on them.
