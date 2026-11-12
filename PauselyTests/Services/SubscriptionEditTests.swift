import XCTest
@testable import Pausely

final class SubscriptionEditDraftTests: XCTestCase {

    private func sub(_ price: Double = 16.49, frequency: BillingFrequency = .monthly) -> Subscription {
        var s = Subscription(name: "Netflix", price: price, category: "Entertainment", billingFrequency: frequency)
        s.currency = "CAD"
        s.nextBillingDate = Calendar.current.date(byAdding: .day, value: 9, to: Date())
        s.notifyBeforeDays = 3
        return s
    }

    // MARK: Amount parsing (every amount field reads through `AmountText`)

    private let english = Locale(identifier: "en_US")
    private let french = Locale(identifier: "fr_FR")
    private let german = Locale(identifier: "de_DE")
    private let arabic = Locale(identifier: "ar_SA")
    private let japanese = Locale(identifier: "ja_JP")

    func testParsesCommonFormats() {
        func parse(_ text: String) -> Decimal? { AmountText.parse(text, currency: "USD", locale: english) }
        XCTAssertEqual(parse("9.99"), Decimal(string: "9.99"))
        XCTAssertEqual(parse("9,99"), Decimal(string: "9.99"))
        XCTAssertEqual(parse("$9.99"), Decimal(string: "9.99"))
        XCTAssertEqual(parse("C$ 1,299.00"), 1299)
        XCTAssertEqual(parse("1.299,00"), 1299)
        XCTAssertEqual(parse("1,299"), 1299)
        XCTAssertEqual(parse("12,990.50"), Decimal(string: "12990.5"))
        XCTAssertEqual(parse("  12  "), 12)
    }

    func testRejectsNonsense() {
        for bad in ["", "   ", "abc", "0", "0.00", "-5", "-5.00", "999999", "−5", "1,29,9", "."] {
            XCTAssertNil(AmountText.parse(bad, currency: "USD", locale: english), "\(bad) should be invalid")
        }
    }

    /// The Arabic keyboard types Arabic-Indic digits and its own decimal mark (U+066B). Before, the
    /// mark was dropped and the amount refused.
    func testAnAmountTypedOnAnArabicKeyboardIsRead() {
        XCTAssertEqual(AmountText.parse("٩٫٩٩", currency: "SAR", locale: arabic), Decimal(string: "9.99"))
        XCTAssertEqual(AmountText.parse("١٬٢٩٩٫٥٠", currency: "SAR", locale: arabic), Decimal(string: "1299.5"))
        XCTAssertEqual(AmountText.parse("۱۵٫۴۹", currency: "USD", locale: english), Decimal(string: "15.49"), "Persian digits")
        XCTAssertEqual(AmountText.parse("１５００", currency: "JPY", locale: japanese), 1500, "Full-width digits from a Japanese keyboard")
    }

    /// A single mark is read the way the reader's language writes numbers.
    func testALoneMarkFollowsTheReadersLanguage() {
        XCTAssertEqual(AmountText.parse("1.299", currency: "EUR", locale: german), 1299, "German groups thousands with a point")
        XCTAssertEqual(AmountText.parse("1.299", currency: "USD", locale: english), Decimal(string: "1.3"), "In English a point is the decimal mark")
        XCTAssertEqual(AmountText.parse("9.99", currency: "EUR", locale: german), Decimal(string: "9.99"), "Not a group of three: a decimal")
        XCTAssertEqual(AmountText.parse("1,299", currency: "EUR", locale: french), Decimal(string: "1.3"), "French writes decimals with a comma")
        XCTAssertEqual(AmountText.parse("1 299,00", currency: "EUR", locale: french), 1299)
        XCTAssertEqual(AmountText.parse("1'299.00", currency: "CHF", locale: Locale(identifier: "de_CH")), 1299)
    }

    /// Each currency has its own decimals: none for yen, three for dinars.
    func testAmountsKeepTheirCurrencysDecimals() {
        XCTAssertEqual(AmountText.parse("1,500", currency: "JPY", locale: french), 1500, "Yen has no decimals, so this is fifteen hundred in every language")
        XCTAssertEqual(AmountText.parse("1500.4", currency: "JPY", locale: english), 1500)
        XCTAssertEqual(AmountText.parse("1.255", currency: "KWD", locale: english), Decimal(string: "1.255"))
        XCTAssertEqual(AmountText.parse("15.499", currency: "USD", locale: english), Decimal(string: "15.5"))
        XCTAssertNil(AmountText.parse("0.001", currency: "USD", locale: english), "Rounds to nothing")
    }

    /// The ceiling is there to catch a slip, and it is the same sum in every currency. Before, rupiah,
    /// dong and rial prices above 100,000 were refused, and those are ordinary prices.
    func testOrdinaryPricesInLargeDenominationCurrenciesAreAccepted() {
        XCTAssertEqual(AmountText.parse("186000", currency: "IDR", locale: english), 186_000)
        XCTAssertEqual(AmountText.parse("260.000", currency: "VND", locale: Locale(identifier: "vi_VN")), 260_000)
        XCTAssertEqual(AmountText.parse("2,500,000", currency: "KRW", locale: english), 2_500_000)
        XCTAssertNil(AmountText.parse("100001", currency: "USD", locale: english))
        XCTAssertTrue(AmountText.isTooLarge("100001", currency: "USD", locale: english))
        XCTAssertFalse(AmountText.isTooLarge("abc", currency: "USD", locale: english))
        XCTAssertEqual(AmountText.ceiling(for: "USD"), 100_000)
        XCTAssertGreaterThan(AmountText.ceiling(for: "IDR"), 1_000_000_000)
        XCTAssertEqual(AmountText.ceiling(for: "KWD"), 100_000, "Never less than 100,000, whatever the rate")
    }

    /// What a field shows can always be typed back: in every language the app speaks and for
    /// currencies with no, two and three decimals.
    func testWhatAFieldShowsReadsBackAsTheSameAmount() {
        let amounts: [(String, String)] = [("USD", "15.49"), ("EUR", "1299.99"), ("JPY", "1500"), ("KWD", "1.255"),
                                           ("IDR", "186000"), ("SAR", "0.5")]
        for locale in [english, french, german, arabic, japanese, Locale(identifier: "es_ES"), Locale(identifier: "en_CA")] {
            for (currency, text) in amounts {
                let amount = Decimal(string: text)!
                let shown = AmountText.text(for: amount, currency: currency, locale: locale)
                XCTAssertEqual(AmountText.parse(shown, currency: currency, locale: locale), amount,
                               "\(currency) \(text) shown as \"\(shown)\" in \(locale.identifier)")
            }
        }
    }

    func testAFieldShowsTheCurrencysOwnDecimals() {
        XCTAssertEqual(AmountText.text(for: 1500, currency: "JPY", locale: english), "1500")
        XCTAssertEqual(AmountText.text(for: Decimal(string: "1.255")!, currency: "KWD", locale: english), "1.255")
        XCTAssertEqual(AmountText.text(for: Decimal(string: "16.49")!, currency: "CAD", locale: english), "16.49")
        XCTAssertEqual(AmountText.text(for: Decimal(string: "16.49")!, currency: "EUR", locale: french), "16,49")
    }

    /// Opening the edit screen for a price in dinars and saving something else must not round the price.
    func testEditingADinarPriceDoesNotChangeIt() {
        var subscription = sub()
        subscription.currency = "KWD"
        subscription.amount = Decimal(string: "1.255")!
        var draft = SubscriptionEditDraft(from: subscription)
        XCTAssertFalse(draft.isDirty(comparedTo: subscription))
        draft.name = "Netflix Premium"
        XCTAssertEqual(draft.applied(to: subscription)?.amount, Decimal(string: "1.255"))
    }

    // MARK: Validation

    func testValidationMessages() {
        var draft = SubscriptionEditDraft(from: sub())
        XCTAssertTrue(draft.isValid)
        draft.name = "   "
        XCTAssertEqual(draft.nameError, "Add a name")
        draft.name = "Netflix"
        draft.amountText = ""
        XCTAssertEqual(draft.amountError, "Enter the amount")
        draft.amountText = "abc"
        XCTAssertEqual(draft.amountError, "Enter a valid amount")
        XCTAssertFalse(draft.isValid)
        draft.amountText = "250000"
        XCTAssertEqual(draft.amountError, "That is more than Pausely can track.")
    }

    // MARK: Dirty tracking: Save must stay off until something really changed

    func testUntouchedDraftIsNotDirty_evenWithFloatDerivedAmounts() {
        for price in [16.49, 9.99, 0.99, 1299.99, 4.5] {
            let original = sub(price)
            XCTAssertFalse(SubscriptionEditDraft(from: original).isDirty(comparedTo: original), "price \(price)")
        }
    }

    func testRealChangesAreDirty() {
        let original = sub()
        var draft = SubscriptionEditDraft(from: original)
        draft.name = "Netflix Premium"
        XCTAssertTrue(draft.isDirty(comparedTo: original))

        draft = SubscriptionEditDraft(from: original); draft.amountText = "18.99"
        XCTAssertTrue(draft.isDirty(comparedTo: original))

        draft = SubscriptionEditDraft(from: original); draft.frequency = .yearly
        XCTAssertTrue(draft.isDirty(comparedTo: original))

        draft = SubscriptionEditDraft(from: original); draft.category = "Music"
        XCTAssertTrue(draft.isDirty(comparedTo: original))

        draft = SubscriptionEditDraft(from: original); draft.reminderDays = 7
        XCTAssertTrue(draft.isDirty(comparedTo: original))

        draft = SubscriptionEditDraft(from: original); draft.nextBillingDate = nil
        XCTAssertTrue(draft.isDirty(comparedTo: original))
    }

    func testCosmeticDifferencesAreNotChanges() {
        var original = sub()
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: original.nextBillingDate!)!
        original.nextBillingDate = noon
        var draft = SubscriptionEditDraft(from: original)
        draft.name = "  Netflix  "
        draft.amountText = "16.490"
        draft.nextBillingDate = noon.addingTimeInterval(3_600)   // same calendar day
        XCTAssertFalse(draft.isDirty(comparedTo: original))
    }

    // MARK: Applying

    func testAppliedKeepsEverythingElse() {
        var original = sub()
        original.status = .trial
        original.trialEndsAt = Calendar.billing.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 12))
        let created = original.createdAt
        var draft = SubscriptionEditDraft(from: original)
        draft.name = "  Netflix Premium "
        draft.amountText = "22,99"
        draft.frequency = .yearly
        draft.category = "Music"
        draft.reminderDays = 7

        let updated = draft.applied(to: original)
        XCTAssertEqual(updated?.name, "Netflix Premium")
        XCTAssertEqual(updated?.amount, Decimal(string: "22.99"))
        XCTAssertEqual(updated?.billingFrequency, .yearly)
        XCTAssertEqual(updated?.category, "Music")
        XCTAssertEqual(updated?.notifyBeforeDays, 7)
        XCTAssertEqual(updated?.id, original.id)
        XCTAssertEqual(updated?.status, .trial)
        XCTAssertEqual(updated?.trialEndsAt, original.trialEndsAt)
        XCTAssertEqual(updated?.createdAt, created)
    }

    func testInvalidDraftCannotBeApplied() {
        var draft = SubscriptionEditDraft(from: sub())
        draft.amountText = "0"
        XCTAssertNil(draft.applied(to: sub()))
    }

    // MARK: Hints

    func testYearlyCostHint() {
        var draft = SubscriptionEditDraft(from: sub())
        XCTAssertEqual(draft.yearlyCost, Decimal(string: "197.88"))
        draft.frequency = .weekly
        XCTAssertEqual(draft.yearlyCost, Decimal(string: "857.48"))
        draft.amountText = "oops"
        XCTAssertNil(draft.yearlyCost)
    }

    func testReminderLabels() {
        XCTAssertEqual(SubscriptionEditDraft.reminderLabel(0), "Off")
        XCTAssertEqual(SubscriptionEditDraft.reminderLabel(1), "1 day before")
        XCTAssertEqual(SubscriptionEditDraft.reminderLabel(7), "7 days before")
    }
}

// MARK: - Countdowns

final class RenewalDayCountTests: XCTestCase {

    private func date(daysFromToday: Int, hour: Int) -> Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: daysFromToday, to: calendar.startOfDay(for: Date()))!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    func testCalendarDaysIgnoresTimeOfDay() {
        let calendar = Calendar.current
        for hour in [0, 1, 12, 23] {
            XCTAssertEqual(calendar.calendarDays(from: Date(), to: date(daysFromToday: 9, hour: hour)), 9, "hour \(hour)")
            XCTAssertEqual(calendar.calendarDays(from: Date(), to: date(daysFromToday: 1, hour: hour)), 1, "hour \(hour)")
            XCTAssertEqual(calendar.calendarDays(from: Date(), to: date(daysFromToday: 0, hour: hour)), 0, "hour \(hour)")
            XCTAssertEqual(calendar.calendarDays(from: Date(), to: date(daysFromToday: -3, hour: hour)), -3, "hour \(hour)")
        }
    }

    func testSubscriptionRenewalCountdown() {
        for hour in [0, 12, 23] {
            var s = Subscription(name: "X", price: 1, category: "Other", billingFrequency: .monthly)
            s.nextBillingDate = date(daysFromToday: 9, hour: hour)
            XCTAssertEqual(s.daysUntilRenewal, 9, "hour \(hour)")
        }
    }
}
