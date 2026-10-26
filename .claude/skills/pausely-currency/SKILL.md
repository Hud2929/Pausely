---
name: pausely-currency
description: The rules and tools for money in Pausely. Use whenever code shows, adds, compares, ranks, stores or converts a price, total, saving or exchange rate; when adding a screen, widget, notification, export or sample text with an amount in it; when touching the currency picker or exchange rates; or when a currency looks wrong on screen ("C$ here, $ there", a total that doesn't add up, a price in the wrong currency).
---

# Money in Pausely

Every amount in Pausely is a number **and** an ISO 4217 currency code. Bugs happen when the two get
separated: a US-dollar price shown with a Canadian symbol, a total that adds yen to dollars, a
paywall price Pausely made up. All money goes through one engine in `Pausely/Core/Money/`, and
`PauselyTests/Services/CurrencyGuardTests.swift` fails the tests if anything goes around it.

## The rules

1. **One formatter.** All money text comes from `MoneyFormat.string(amount, currency)`. Never write
   `"$" + …`, `String(format: "%.2f")`, a `NumberFormatter` with `.currency`, or a symbol table.
2. **The reader's locale picks the symbol.** In Canada CAD is `$12.99` and USD is `US$12.99`; in the
   US, USD is `$12.99` and CAD is `CA$12.99`; in Germany `12,99 €`. Decimals follow the currency
   (¥1,500, KWD 1.250). Nobody ever sees a bare `$` for a currency that isn't theirs.
3. **One subscription's price is shown in what it's billed in** (`subscription.chargeText`): list
   rows, payment and decision cards, the verdict, reminders, price history, the edit screen. A
   converted figure may follow as "about …", never replace it.
4. **Anything added up is in the display currency** (`CurrencyManager.shared.selectedCurrency`),
   with every item converted first. Use `subscriptions.monthlyTotal()` / `annualTotal()` or
   `MoneyMath.total`. Comparisons and rankings ("biggest expense") also compare converted values.
5. **Parts shown next to a total use the total's currency**, so they visibly add up; the original
   currency can follow as detail. Converted amounts next to originals are marked "≈".
6. **Conversion never fails silently.** `CurrencyRates.convert` returns `nil` for an unknown
   currency; callers handle it. Live rates come from the API, and the built-in table
   (`CurrencyRates.fallback`) covers every currency in the picker, so offline still converts.
7. **Pausely never invents a price.** Pro prices come only from StoreKit (`product.displayPrice`);
   while they load the paywall shows "…". Catalog prices are US list prices and are labelled as such
   (or converted with "≈").

## The engine

| File | What it does |
|---|---|
| `Core/Money/MoneyFormat.swift` | `string(_:_:locale:wholeUnits:)`, `symbol(for:)` (input-field prefixes), `fractionDigits(for:)`, `plainNumber` (CSV), `decimal(Double)` (no binary noise), `normalizedCode`, `isKnown` |
| `Core/Money/CurrencyRates.swift` | Rates per USD in `Decimal`; `convert(_:from:to:) -> Decimal?`; `fillingGaps()`; `fallback` table + `fallbackDate` |
| `Core/Money/MoneyMath.swift` | `MoneyMath.total`, `[Subscription].monthlyTotal(in:)` / `annualTotal(in:)`, `Subscription.monthlyCost(in:)` / `annualCost(in:)`, `Subscription.chargeText` |
| `Services/SupabaseManager.swift` → `CurrencyManager` | The user's display currency (`selectedCurrency`, the only source of truth), live rates (`exchangeRates` → `rates`), the picker list (`allCurrencies`), thin wrappers (`format`, `convertToSelected`, `formatCatalogPrice`) that call the engine |

## Recipes

```swift
// A subscription's price (rule 3)
Text(subscription.chargeText)                                   // "$15.49" / "US$20.00"
Text(MoneyFormat.string(subscription.monthlyCost, subscription.currency))

// A total (rule 4)
let monthly = subscriptions.monthlyTotal()                      // display currency
Text(CurrencyManager.shared.format(monthly))

// Ranking or comparing across currencies
subs.sorted { [$0].monthlyTotal() > [$1].monthlyTotal() }

// One subscription in the display currency, explicit about failure
if let converted = sub.monthlyCost(in: CurrencyManager.shared.selectedCurrency) { … }

// A line next to a total (rule 5): the Savings Receipt
summary.formatted(line.savedSoFar, from: line.currency)        // "≈$14.00" when converted

// A US catalog / alternative price shown to someone else
CurrencyManager.shared.formatCatalogPrice(price)                // converted to the display currency
CurrencyManager.shared.priceIndicator + …                      // "≈" when converted

// Sample or marketing amounts (onboarding mockups)
OnboardingSample.money(17.99)                                   // US price → reader's currency

// An amount input field's prefix
Text(MoneyFormat.symbol(for: draft.currency))

// Files (CSV): plain numbers plus a currency column
MoneyFormat.plainNumber(sub.amount, sub.currency)               // "15.49", "1500"

// Widgets and Live Activities: the app formats, the extension only displays text
defaults.set(MoneyFormat.string(total, currency), forKey: "widget_monthlySpendText")
```

**Localized strings with amounts:** interpolate the formatted amount (`"\(amount) a year"`), so the
key is `"%@ a year"`. Never put a symbol or number inside a localized key. When re-keying
`Localizable.xcstrings` by script, keep its JSON style (`separators=(',', ': ')`, original key order).

**Stored amounts:** create `Decimal`s from text or `MoneyFormat.decimal(double)`, never
`Decimal(double)` (15.49 becomes 15.4900000000000002). A new `Subscription` defaults to the display
currency; pass the real currency whenever you know it (catalog plans carry their own).

**Observing the display currency:** `@Published` sends *before* the value changes. Take the new code
from the event (`.sink { code in … }`) or hop to the main queue before reading `selectedCurrency`.
`SubscriptionStore` recalculates totals on currency changes and when live rates arrive.

## Before you finish any change that touches money

- [ ] Every amount on screen goes through `MoneyFormat` (directly or via `CurrencyManager.format`).
- [ ] Each amount is labelled with **its own** currency, or converted first.
- [ ] Sums, averages, rankings and percentages convert every item first.
- [ ] Parts next to a total use the total's currency.
- [ ] No price that StoreKit or the user didn't give you.
- [ ] Widgets, notifications, Siri/Shortcuts text, exports and accessibility labels too.
- [ ] `scripts/check_money.sh` passes (the guard plus the money tests).
- [ ] For visible changes: `scripts/locale_tour.sh` and look at the screens in each locale.

## Verify

```bash
# Guard + money tests (about a minute; builds first)
.claude/skills/pausely-currency/scripts/check_money.sh

# Screenshots of the money screens in en_CA, en_US, de_DE and ja_JP (DEBUG demo data)
.claude/skills/pausely-currency/scripts/locale_tour.sh
```

The guard (`CurrencyGuardTests.testMoneyIsOnlyHandledByTheMoneyEngine`) prints `file:line`, the rule
and the fix for each violation. A deliberate exception gets `// money-guard: <reason>` on that line;
a whole file of US list prices or parsing code goes in the rule's `allowedPaths` with a comment.

## Refresh the built-in rates

The fallback table only matters offline or before live rates load, but keep it within a few months:

```bash
python3 .claude/skills/pausely-currency/scripts/refresh_rates.py   # rewrites CurrencyRates.fallback
```

It fetches today's rates for exactly the currencies in the picker and updates `fallbackDate`. Then run
`check_money.sh`. When adding a currency to the picker, add it to `CurrencyManager.currencies` and
re-run the script; `testBuiltInRatesCoverEveryCurrencyInThePicker` fails until it has a rate.

## Bugs this replaced (2026-10-26), so they don't come back

- Three formatters disagreed: the same CAD amount showed as `$`, `C$` and `CA$` on different screens.
- Conversions fell back to 1:1 or to the unconverted number when a rate was missing.
- Lifetime spend, Profile stats, the personality card, Biggest Expenses, the PDF export, the widget
  and the Gmail results added different currencies together.
- Totals didn't update after switching currency (`@Published` fired before the change, and a stale
  cache hash skipped the recalculation).
- The paywall showed an invented local Pro price before StoreKit loaded, treating CAD as equal to USD.
- The catalog plan sheet showed a converted "≈" price but saved the US price.
- "Cheaper alternative" savings multiplied a yearly plan's price by 12 and compared it with a USD price.
- The widget, trial widget and Live Activity used their own symbol table, `%.2f`, and a yearly plan's
  monthly cost labelled "/ Yearly".
- Onboarding mockups hard-coded `$247`, `$17.99`, `$215.88` for every country.
- Bitcoin, Ethereum, gold, silver, the retired kuna and the non-ISO "KID" were in the picker.
