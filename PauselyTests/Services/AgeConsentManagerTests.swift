import XCTest
@testable import Pausely

@MainActor
final class AgeConsentManagerTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func makeManager() -> (AgeConsentManager, UserDefaults) {
        let suite = "AgeConsentManagerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (AgeConsentManager(defaults: defaults), defaults)
    }

    // MARK: - Minimum age constant

    func testMinimumAgeIs16() {
        XCTAssertEqual(AgeConsentManager.minimumAge, 16)
    }

    // MARK: - Age maths

    func testExactly16Today_isAllowed() {
        let now = date(2026, 10, 5)
        XCTAssertTrue(AgeConsentManager.isOldEnough(birthDate: date(2010, 10, 5), now: now, calendar: calendar))
    }

    func testTurns16Tomorrow_isBlocked() {
        let now = date(2026, 10, 5)
        XCTAssertFalse(AgeConsentManager.isOldEnough(birthDate: date(2010, 10, 6), now: now, calendar: calendar))
    }

    func testAge15AndEleven_Months_isBlocked() {
        let now = date(2026, 10, 5)
        XCTAssertFalse(AgeConsentManager.isOldEnough(birthDate: date(2010, 11, 5), now: now, calendar: calendar))
    }

    func testAdult_isAllowed() {
        XCTAssertTrue(AgeConsentManager.isOldEnough(birthDate: date(1990, 1, 1), now: date(2026, 10, 5), calendar: calendar))
    }

    func testFutureDate_isNotOldEnough_andHasNoAge() {
        let now = date(2026, 10, 5)
        XCTAssertNil(AgeConsentManager.age(on: now, birthDate: date(2030, 1, 1), calendar: calendar))
        XCTAssertFalse(AgeConsentManager.isOldEnough(birthDate: date(2030, 1, 1), now: now, calendar: calendar))
    }

    func testLeapDayBirthday_16thBirthdayOnFeb28IsNotYetReached_ifBornFeb29() {
        // Born 2008-02-29. In 2024 (leap) they turn 16 on Feb 29; the day before they're still 15.
        XCTAssertFalse(AgeConsentManager.isOldEnough(birthDate: date(2008, 2, 29), now: date(2024, 2, 28), calendar: calendar))
        XCTAssertTrue(AgeConsentManager.isOldEnough(birthDate: date(2008, 2, 29), now: date(2024, 2, 29), calendar: calendar))
    }

    // MARK: - Device gate + lockout

    func testAllowed_setsDeviceGate() {
        let (manager, _) = makeManager()
        XCTAssertFalse(manager.hasPassedDeviceGate)
        XCTAssertEqual(manager.evaluate(birthDate: date(1990, 1, 1), now: date(2026, 10, 5)), .allowed)
        XCTAssertTrue(manager.hasPassedDeviceGate)
    }

    func testUnderAge_blocksAndLocksOut() {
        let (manager, _) = makeManager()
        let now = date(2026, 10, 5)
        XCTAssertEqual(manager.evaluate(birthDate: date(2015, 1, 1), now: now), .underAge)
        XCTAssertFalse(manager.hasPassedDeviceGate)
        XCTAssertNotNil(manager.lockoutRemaining(now: now))
    }

    func testLockout_preventsRetryWithAdultDate() {
        let (manager, _) = makeManager()
        let now = date(2026, 10, 5)
        _ = manager.evaluate(birthDate: date(2015, 1, 1), now: now)
        // Same device immediately retries with a different (adult) date: still locked.
        XCTAssertEqual(manager.evaluate(birthDate: date(1990, 1, 1), now: now.addingTimeInterval(60)), .lockedOut)
        XCTAssertFalse(manager.hasPassedDeviceGate)
    }

    func testLockout_expiresAfter24Hours() {
        let (manager, _) = makeManager()
        let now = date(2026, 10, 5)
        _ = manager.evaluate(birthDate: date(2015, 1, 1), now: now)
        let later = now.addingTimeInterval(AgeConsentManager.lockoutDuration + 1)
        XCTAssertNil(manager.lockoutRemaining(now: later))
        XCTAssertEqual(manager.evaluate(birthDate: date(1990, 1, 1), now: later), .allowed)
    }

    func testFutureDate_isInvalid_andDoesNotLockOut() {
        let (manager, _) = makeManager()
        let now = date(2026, 10, 5)
        XCTAssertEqual(manager.evaluate(birthDate: date(2030, 1, 1), now: now), .invalidDate)
        XCTAssertNil(manager.lockoutRemaining(now: now))
    }

    // MARK: - Privacy: DOB never stored

    func testDateOfBirthIsNeverPersisted() {
        let (manager, defaults) = makeManager()
        let birth = date(1990, 6, 15)
        _ = manager.evaluate(birthDate: birth, now: date(2026, 10, 5))
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix("age_") {
            if let d = value as? Date { XCTAssertNotEqual(d, birth, "Birth date leaked into \(key)") }
        }
    }

    // MARK: - Per-user consent

    func testNeedsConsent_untilRecorded() {
        let (manager, _) = makeManager()
        XCTAssertTrue(manager.needsConsent(userId: "user-1"))
    }

    func testAdoptRemoteConsentHydratesLocalStateAndKeepsEarliestTimestamp() {
        let (manager, defaults) = makeManager()
        let original = date(2026, 5, 1)
        let later = date(2026, 10, 1)

        manager.adoptRemoteConsent(userId: "user-remote", confirmedAt: original)
        XCTAssertFalse(manager.needsConsent(userId: "user-remote"))
        XCTAssertEqual(defaults.object(forKey: "age_consent_user_user-remote") as? Date, original)
        XCTAssertFalse(defaults.bool(forKey: "age_consent_pending_sync_user-remote"))

        manager.adoptRemoteConsent(userId: "user-remote", confirmedAt: later)
        XCTAssertEqual(defaults.object(forKey: "age_consent_user_user-remote") as? Date, original)
    }

    /// When the lockout ends, said in the reader's language: one hour is "hour", not "hour(s)".
    func testTheLockoutLineIsInTheReadersLanguage() {
        let saved = UserDefaults.standard.object(forKey: L10n.languageKey)
        defer { UserDefaults.standard.set(saved, forKey: L10n.languageKey) }

        UserDefaults.standard.set("en", forKey: L10n.languageKey)
        XCTAssertEqual(AgeGateView.lockoutLine(remaining: 40 * 60), "You can try again in about 1 hour.")
        XCTAssertEqual(AgeGateView.lockoutLine(remaining: 2.2 * 3600), "You can try again in about 3 hours.", "rounded up: never sooner than said")

        UserDefaults.standard.set("de", forKey: L10n.languageKey)
        XCTAssertEqual(AgeGateView.lockoutLine(remaining: 23 * 3600), "Sie können es in etwa 23 Stunden erneut versuchen.")
        UserDefaults.standard.set("fr", forKey: L10n.languageKey)
        XCTAssertEqual(AgeGateView.lockoutLine(remaining: 3600), "Vous pourrez réessayer dans environ 1 heure.")
    }
}
