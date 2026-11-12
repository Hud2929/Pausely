import Foundation
import XCTest
@testable import Pausely

/// Shortcuts and Siri: what they say, in whose language, and what they refuse.
@MainActor
final class PauselyAppIntentsTests: XCTestCase {

    private var sandbox: StoreSandbox!
    private var signedInCheck: (() -> Bool)!
    private var savedLanguage: Any?
    private let cal = Calendar.billing
    private let english = Locale(identifier: "en_US")

    override func setUp() async throws {
        sandbox = StoreSandbox()   // an empty list, offline, put back afterwards
        signedInCheck = ShortcutProblem.isSignedIn
        ShortcutProblem.isSignedIn = { true }
        savedLanguage = UserDefaults.standard.object(forKey: L10n.languageKey)
        UserDefaults.standard.set("en", forKey: L10n.languageKey)
        CurrencyManager.shared.selectedCurrency = "USD"
        UserDefaults.standard.set(true, forKey: "debug_premium_override")   // the free limit has its own tests
    }

    override func tearDown() async throws {
        ShortcutProblem.isSignedIn = signedInCheck
        UserDefaults.standard.set(savedLanguage, forKey: L10n.languageKey)
        await sandbox.restore()
        sandbox = nil
    }

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func sub(_ name: String, _ amount: String = "10.00", anchor: Date? = nil, status: SubscriptionStatus = .active,
                     trialEnds: Date? = nil, frequency: BillingFrequency = .monthly) -> Subscription {
        Subscription(name: name, amount: Decimal(string: amount)!, currency: "USD", billingFrequency: frequency,
                     nextBillingDate: anchor, trialEndsAt: trialEnds, status: status)
    }

    /// As the answers format it: in the app's language, which these tests set to English.
    private func money(_ amount: String, locale: Locale = L10n.locale) -> String {
        MoneyFormat.string(Decimal(string: amount)!, "USD", locale: locale)
    }

    // MARK: - Signed out

    /// Signed out, the list is out of memory: a Shortcut neither answers from an empty list nor adds
    /// to it. It says to sign in.
    func testSignedOutEveryShortcutSaysToSignIn() async throws {
        ShortcutProblem.isSignedIn = { false }
        func refused(_ run: () async throws -> Void) async -> Bool {
            do { try await run() } catch ShortcutProblem.signedOut { return true } catch { return false }
            return false
        }
        let add = AddSubscriptionIntent()
        add.name = "Netflix"
        add.monthlyCost = 15.49
        let detail = GetSubscriptionDetailIntent()
        detail.name = "Netflix"

        let spend = await refused { _ = try await GetMonthlySpendIntent().perform() }
        let renewals = await refused { _ = try await GetUpcomingRenewalsIntent().perform() }
        let added = await refused { _ = try await add.perform() }
        let detailed = await refused { _ = try await detail.perform() }
        XCTAssertEqual([spend, renewals, added, detailed], [true, true, true, true])
        XCTAssertEqual(SubscriptionStore.shared.subscriptions, [])
    }

    // MARK: - What it all costs

    func testMonthlySpend() async throws {
        _ = try await SubscriptionStore.shared.addSubscription(sub("Netflix", "15.49"))
        _ = try await SubscriptionStore.shared.addSubscription(sub("Gone", "99.00", status: .cancelled))
        let result = try await GetMonthlySpendIntent().perform()
        XCTAssertEqual(result.value, "Your subscriptions cost \(money("15.49")) a month.")
    }

    func testATotalThatWasConvertedSaysItIsAbout() {
        XCTAssertTrue(ShortcutAnswers.monthlySpend(15, currency: "USD", converted: true).contains("≈"))
        XCTAssertFalse(ShortcutAnswers.monthlySpend(15, currency: "USD", converted: false).contains("≈"))
    }

    // MARK: - What renews next

    func testUpcomingListsEachChargeInTheWindowSoonestFirst() {
        let now = day(2026, 11, 12)
        let list = [sub("Later", "5.00", anchor: day(2026, 11, 18)),
                    sub("Tomorrow", "15.49", anchor: day(2026, 11, 13)),
                    sub("Next month", anchor: day(2026, 12, 20)),
                    sub("Cancelled", anchor: day(2026, 11, 13), status: .cancelled),
                    sub("Trial", "8.00", anchor: nil, status: .trial, trialEnds: day(2026, 11, 14)),
                    sub("No date")]
        let answer = ShortcutAnswers.upcoming(list, daysAhead: 7, now: now, locale: english)
        XCTAssertEqual(answer, """
        Tomorrow · \(money("15.49", locale: english)) · tomorrow
        Trial · \(money("8.00", locale: english)) · in 2 days
        Later · \(money("5.00", locale: english)) · in 6 days
        """)
    }

    func testNothingInTheWindowSaysSo() {
        let answer = ShortcutAnswers.upcoming([sub("Next month", anchor: day(2026, 12, 20))], daysAhead: 7, now: day(2026, 11, 12))
        XCTAssertEqual(answer, "Nothing renews in that time.")
    }

    // MARK: - One subscription

    func testDetailSaysWhatItCostsWhereItStandsAndWhenItRenews() {
        let now = day(2026, 11, 12)
        XCTAssertEqual(ShortcutAnswers.detail(for: sub("Netflix", "15.49", anchor: day(2026, 11, 15)), now: now, locale: english),
                       "Netflix · \(money("15.49", locale: english)) a month · Active · Renews in 3 days")
        XCTAssertEqual(ShortcutAnswers.detail(for: sub("Notion", "120.00", anchor: day(2027, 3, 1), frequency: .yearly), now: now, locale: english),
                       "Notion · \(money("10.00", locale: english)) a month · Active · Renews Mar 1")
    }

    /// Something that will not charge has no renewal to report; something that will, and has no date, says so.
    func testDetailReportsTheRealStatusAndNoRenewalForWhatWillNotCharge() {
        let now = day(2026, 11, 12)
        XCTAssertEqual(ShortcutAnswers.detail(for: sub("Hulu", anchor: day(2026, 11, 9), status: .cancelled), now: now, locale: english),
                       "Hulu · \(money("10.00", locale: english)) a month · Cancelled")
        XCTAssertEqual(ShortcutAnswers.detail(for: sub("Crave", status: .trial), now: now, locale: english),
                       "Crave · \(money("10.00", locale: english)) a month · Free trial · No renewal date")
    }

    func testANameThatMeansNoneOrSeveralIsAProblemNotAGuess() async throws {
        SubscriptionStore.shared.subscriptions = [sub("Apple One"), sub("Apple Music")]
        let intent = GetSubscriptionDetailIntent()

        intent.name = "Hulu"
        do { _ = try await intent.perform(); XCTFail("found something") } catch let problem as ShortcutProblem {
            XCTAssertEqual(problem, .notFound("Hulu"))
        }
        intent.name = "apple"
        do { _ = try await intent.perform(); XCTFail("picked one") } catch let problem as ShortcutProblem {
            XCTAssertEqual(problem, .several("apple", ["Apple One", "Apple Music"]))
        }
        intent.name = "apple music"
        let result = try await intent.perform()
        XCTAssertTrue(result.value?.hasPrefix("Apple Music · ") == true)
    }

    func testAnExactNameWinsOverNamesThatContainIt() {
        let list = [sub("Apple One"), sub("Apple")]
        guard case .one(let found) = NamedSubscription.find("apple", in: list) else { return XCTFail("exact name") }
        XCTAssertEqual(found.name, "Apple")
        guard case .none = NamedSubscription.find("   ", in: list) else { return XCTFail("empty name") }
    }

    // MARK: - Adding

    func testAddingByShortcutDoesNotInventARenewalDate() async throws {
        let intent = AddSubscriptionIntent()
        intent.name = "  Netflix "
        intent.monthlyCost = 15.49
        let result = try await intent.perform()
        XCTAssertEqual(result.value, "Added Netflix at \(money("15.49")) a month.")
        let added = try XCTUnwrap(SubscriptionStore.shared.subscriptions.first)
        XCTAssertEqual(added.name, "Netflix")
        XCTAssertEqual(added.amount, Decimal(string: "15.49"))
        XCTAssertNil(added.nextBillingDate)
    }

    /// Before, a Shortcut could add a subscription at zero, at a negative price (which lowered every
    /// total) or with no name.
    func testAShortcutAddsOnlyWhatAFormWould() {
        func problem(name: String, cost: Double, currency: String = "USD") -> ShortcutProblem? {
            do { _ = try ShortcutAnswers.newSubscription(name: name, monthlyCost: cost, currency: currency); return nil }
            catch { return error as? ShortcutProblem }
        }
        XCTAssertEqual(problem(name: "   ", cost: 9.99), .noName)
        XCTAssertEqual(problem(name: "Netflix", cost: 0), .notAPrice)
        XCTAssertEqual(problem(name: "Netflix", cost: -5), .notAPrice)
        XCTAssertEqual(problem(name: "Netflix", cost: .nan), .notAPrice)
        XCTAssertEqual(problem(name: "Netflix", cost: 0.001), .notAPrice, "rounds to nothing")
        XCTAssertEqual(problem(name: "Netflix", cost: 250_000), .tooLarge)
        XCTAssertNil(problem(name: "Netflix", cost: 186_000, currency: "IDR"))
        XCTAssertEqual(try? ShortcutAnswers.newSubscription(name: "Yen", monthlyCost: 1500.4, currency: "JPY").amount, 1500)
    }

    // MARK: - In the reader's language

    func testAnswersAndProblemsFollowTheLanguageChosenInTheApp() {
        let english = ShortcutAnswers.upcoming([], daysAhead: 7, now: day(2026, 11, 12))
        XCTAssertEqual(String(localized: ShortcutProblem.notFound("Hulu").localizedStringResource), "No subscription is called Hulu.")
        XCTAssertEqual(String(localized: ShortcutProblem.several("apple", ["Apple One", "Apple Music"]).localizedStringResource),
                       "More than one subscription matches apple: Apple One, Apple Music.")

        UserDefaults.standard.set("de", forKey: L10n.languageKey)
        let german = ShortcutAnswers.upcoming([], daysAhead: 7, now: day(2026, 11, 12))
        XCTAssertEqual(german, "In dieser Zeit verlängert sich nichts.")
        XCTAssertNotEqual(german, english)
        let detail = ShortcutAnswers.detail(for: sub("Netflix", "15.49", anchor: day(2026, 11, 13)), now: day(2026, 11, 12))
        XCTAssertTrue(detail.contains("morgen"), detail)
        XCTAssertTrue(detail.contains("Aktiv"), detail)
    }
}
