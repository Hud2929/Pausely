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

    // MARK: Amount parsing

    func testParsesCommonFormats() {
        XCTAssertEqual(SubscriptionEditDraft.parseAmount("9.99"), Decimal(string: "9.99"))
        XCTAssertEqual(SubscriptionEditDraft.parseAmount("9,99"), Decimal(string: "9.99"))
        XCTAssertEqual(SubscriptionEditDraft.parseAmount("$9.99"), Decimal(string: "9.99"))
        XCTAssertEqual(SubscriptionEditDraft.parseAmount("C$ 1,299.00"), 1299)
        XCTAssertEqual(SubscriptionEditDraft.parseAmount("1.299,00"), 1299)
        XCTAssertEqual(SubscriptionEditDraft.parseAmount("1,299"), 1299)
        XCTAssertEqual(SubscriptionEditDraft.parseAmount("  12  "), 12)
    }

    func testRejectsNonsense() {
        for bad in ["", "   ", "abc", "0", "0.00", "-5", "-5.00", "999999"] {
            XCTAssertNil(SubscriptionEditDraft.parseAmount(bad), "\(bad) should be invalid")
        }
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
        original.status = .paused
        original.isDetected = true
        original.monthlyUsageMinutes = 420
        let created = original.createdAt
        var draft = SubscriptionEditDraft(from: original)
        draft.name = "  Netflix Premium "
        draft.amountText = "22,99"
        draft.frequency = .yearly
        draft.category = "Music"
        draft.reminderDays = 7

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let updated = draft.applied(to: original, now: now)
        XCTAssertEqual(updated?.name, "Netflix Premium")
        XCTAssertEqual(updated?.amount, Decimal(string: "22.99"))
        XCTAssertEqual(updated?.billingFrequency, .yearly)
        XCTAssertEqual(updated?.category, "Music")
        XCTAssertEqual(updated?.notifyBeforeDays, 7)
        XCTAssertEqual(updated?.updatedAt, now)
        XCTAssertEqual(updated?.id, original.id)
        XCTAssertEqual(updated?.status, .paused)
        XCTAssertEqual(updated?.isDetected, true)
        XCTAssertEqual(updated?.monthlyUsageMinutes, 420)
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

// MARK: - Support links

final class SupportLinkTests: XCTestCase {

    func testPhoneBecomesTelURL() {
        let url = SubscriptionManagementView.url(for: SupportContact(type: .phone, value: "1-800-555-0100", label: "Support", hours: nil))
        XCTAssertEqual(url?.absoluteString, "tel:18005550100")
    }

    func testEmailBecomesMailto() {
        let url = SubscriptionManagementView.url(for: SupportContact(type: .email, value: "help@example.com", label: "Email", hours: nil))
        XCTAssertEqual(url?.absoluteString, "mailto:help@example.com")
    }

    func testChatLinkGetsAScheme() {
        let url = SubscriptionManagementView.url(for: SupportContact(type: .chat, value: "help.example.com/chat", label: "Chat", hours: nil))
        XCTAssertEqual(url?.absoluteString, "https://help.example.com/chat")
        let full = SubscriptionManagementView.url(for: SupportContact(type: .chat, value: "https://help.example.com", label: "Chat", hours: nil))
        XCTAssertEqual(full?.absoluteString, "https://help.example.com")
    }

    func testEmptyPhoneIsNotALink() {
        XCTAssertNil(SubscriptionManagementView.url(for: SupportContact(type: .phone, value: "   ", label: "Support", hours: nil)))
    }
}
