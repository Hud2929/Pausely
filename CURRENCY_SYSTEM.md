# Pausely Multi-Currency System

A comprehensive, production-ready multi-currency system supporting 150+ currencies with real-time exchange rates for the Pausely iOS subscription management app.

## Features

- ✅ **150+ Currencies** - Complete coverage of world currencies, cryptocurrencies, and precious metals
- ✅ **Real-time Exchange Rates** - Live rates from exchangerate-api.com with automatic updates
- ✅ **Offline Support** - Cached rates for offline functionality
- ✅ **Smart Currency Detection** - Auto-detects currency from device locale
- ✅ **Currency Conversion** - Real-time conversion between any currencies
- ✅ **Beautiful UI Components** - Ready-to-use SwiftUI components
- ✅ **Subscription Integration** - Seamless integration with subscription management
- ✅ **Rate Trend Analysis** - Historical rate tracking and trend analysis

## Architecture

```
Services/
├── CurrencyManager.swift          # Core currency management singleton

Models/
├── Currency.swift                 # Currency model and extensions

Views/Currency/
├── CurrencyPickerView.swift       # Currency picker with search
├── CurrencySelectorButton.swift   # Quick currency selector button
├── CurrencySettingsView.swift     # Currency settings UI
├── SubscriptionCurrencyExample.swift  # Integration examples

ViewModels/
├── CurrencyViewModel.swift        # Currency ViewModel
```

## Supported Currencies (150+)

### Major Currencies
- USD - US Dollar 🇺🇸
- EUR - Euro 🇪🇺
- GBP - British Pound 🇬🇧
- JPY - Japanese Yen 🇯🇵
- CHF - Swiss Franc 🇨🇭
- CAD - Canadian Dollar 🇨🇦
- AUD - Australian Dollar 🇦🇺
- NZD - New Zealand Dollar 🇳🇿

### Asian Currencies
- CNY - Chinese Yuan 🇨🇳
- HKD - Hong Kong Dollar 🇭🇰
- SGD - Singapore Dollar 🇸🇬
- KRW - South Korean Won 🇰🇷
- INR - Indian Rupee 🇮🇳
- THB - Thai Baht 🇹🇭
- MYR - Malaysian Ringgit 🇲🇾
- PHP - Philippine Peso 🇵🇭
- IDR - Indonesian Rupiah 🇮🇩
- VND - Vietnamese Dong 🇻🇳
- TWD - Taiwan Dollar 🇹🇼
- And 25+ more...

### European Currencies
- SEK - Swedish Krona 🇸🇪
- NOK - Norwegian Krone 🇳🇴
- DKK - Danish Krone 🇩🇰
- PLN - Polish Zloty 🇵🇱
- CZK - Czech Koruna 🇨🇿
- HUF - Hungarian Forint 🇭🇺
- RON - Romanian Leu 🇷🇴
- BGN - Bulgarian Lev 🇧🇬
- And 15+ more...

### Americas
- MXN - Mexican Peso 🇲🇽
- BRL - Brazilian Real 🇧🇷
- ARS - Argentine Peso 🇦🇷
- CLP - Chilean Peso 🇨🇱
- COP - Colombian Peso 🇨🇴
- CAD - Canadian Dollar 🇨🇦
- And 25+ more...

### Middle East & Africa
- AED - UAE Dirham 🇦🇪
- SAR - Saudi Riyal 🇸🇦
- QAR - Qatari Riyal 🇶🇦
- KWD - Kuwaiti Dinar 🇰🇼
- ZAR - South African Rand 🇿🇦
- EGP - Egyptian Pound 🇪🇬
- NGN - Nigerian Naira 🇳🇬
- And 40+ more...

### Cryptocurrencies & Precious Metals
- BTC - Bitcoin 🪙
- ETH - Ethereum 💠
- XAU - Gold Ounce 🥇
- XAG - Silver Ounce 🥈
- XPT - Platinum Ounce ⚪

## Quick Start

### 1. Setup API Key

In `CurrencyManager.swift`, replace the API key:

```swift
private let apiKey = "YOUR_API_KEY" // Get from exchangerate-api.com
```

### 2. Basic Usage

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var currencyManager = CurrencyManager.shared
    
    var body: some View {
        VStack {
            // Show current currency
            Text(currencyManager.selectedCurrency.code)
            
            // Convert amount
            let converted = currencyManager.convertToSelected(100, from: "EUR")
            Text("€100 = \(currencyManager.selectedCurrency.format(converted))")
        }
        .task {
            await currencyManager.fetchExchangeRates()
        }
    }
}
```

### 3. Currency Picker

```swift
@State private var showPicker = false
@State private var selectedCurrency = CurrencyManager.shared.selectedCurrency

Button("Select Currency") {
    showPicker = true
}
.sheet(isPresented: $showPicker) {
    CurrencyPickerView(selectedCurrency: $selectedCurrency) { currency in
        CurrencyManager.shared.selectCurrency(currency)
    }
}
```

### 4. Subscription Integration

```swift
// In your subscription views
struct SubscriptionRow: View {
    let subscription: Subscription
    
    var body: some View {
        HStack {
            Text(subscription.name)
            Spacer()
            // Automatically converts and formats
            Text(subscription.formattedAmount(showConversion: true))
        }
    }
}
```

## UI Components

### CurrencySelectorButton

```swift
CurrencySelectorButton()
CurrencySelectorButton(size: .large, showRateIndicator: true)
```

### CurrencyAmountView

```swift
CurrencyAmountView(
    amount: 99.99,
    currencyCode: "EUR",
    showConversion: true,
    size: .large
)
```

### ExchangeRateBadge

```swift
ExchangeRateBadge(
    fromCurrency: usdCurrency,
    toCurrency: eurCurrency
)
```

### LastUpdatedIndicator

```swift
LastUpdatedIndicator()
```

## ViewModel Usage

```swift
class MyViewModel: ObservableObject {
    @StateObject private var currencyVM = CurrencyViewModel()
    
    func calculateTotal(subscriptions: [Subscription]) -> String {
        let total = subscriptions.reduce(0) { sum, sub in
            sum + sub.monthlyCostInUserCurrency
        }
        return currencyVM.formatInSelectedCurrency(total)
    }
}
```

## Advanced Features

### Batch Conversion

```swift
let amounts = [
    (amount: 100.0, currency: "USD"),
    (amount: 200.0, currency: "EUR"),
    (amount: 150.0, currency: "GBP")
]

let converted = currencyManager.convertBatch(
    amounts: amounts,
    to: "JPY"
)
```

### Historical Rates (Trend Analysis)

```swift
@StateObject private var trendAnalyzer = CurrencyTrendAnalyzer()

// Analyze 30-day trend
await trendAnalyzer.analyzeTrend(
    from: "USD",
    to: "EUR",
    days: 30
)

// Access trend data
Text("Trend: \(trendAnalyzer.currentTrend.rawValue)")
Text("Change: \(trendAnalyzer.trendPercentage)%")
```

### Currency Calculator for Subscriptions

```swift
@StateObject private var calculator = SubscriptionCurrencyCalculator()

// Update subscriptions
calculator.update(
    subscriptions: mySubscriptions,
    period: .monthly
)

// Access totals
Text(calculator.formattedTotal)
```

## Configuration Options

User defaults keys for preferences:

```swift
// Show original currency alongside converted
UserDefaults.standard.set(true, forKey: "show_original_currency")

// Auto-update exchange rates
UserDefaults.standard.set(true, forKey: "auto_update_rates")

// Selected currency code
UserDefaults.standard.set("USD", forKey: "selected_currency_code")
```

## API Configuration

The system uses exchangerate-api.com by default. To use a different provider:

1. Update the `baseURL` and API response parsing in `CurrencyManager.swift`
2. Implement the appropriate API response model

### Alternative: FloatRates API (Free, no API key required)

```swift
private let backupAPIURL = "https://api.floatrates.com/daily"
```

## Offline Mode

The system automatically:
- Caches exchange rates for 1 hour (configurable)
- Falls back to cached rates when offline
- Shows offline indicator in UI
- Automatically retries when connection returns

## Testing

```swift
// Use sample currencies for previews
Currency.samples // [USD, EUR, GBP, JPY]

// Use sample subscriptions
Subscription.multiCurrencySamples
```

## Performance Considerations

- Exchange rates are cached for 1 hour by default
- Batch conversions are optimized
- UI components use `@StateObject` for efficient re-rendering
- Auto-refresh timer runs every 30 minutes when app is active

## Future Enhancements

- [ ] Push notifications for significant rate changes
- [ ] Widget support for quick currency glance
- [ ] Apple Watch complication
- [ ] Custom alert thresholds for exchange rates
- [ ] Export exchange rate history

## License

This currency system is part of the Pausely iOS app.
