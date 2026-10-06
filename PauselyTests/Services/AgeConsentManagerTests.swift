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
}
