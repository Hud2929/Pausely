import CoreSpotlight
import XCTest
@testable import Pausely

/// What one person leaves on an iPhone is never handed to the next. Every value the app saves under a
/// name is either the person's (and `LocalUserData.wipe` removes it) or a setting of the iPhone, listed
/// here with the reason it may outlive an account. A value saved under a new name fails the first test
/// until someone decides which it is.
@MainActor
final class LocalDataGuardTests: XCTestCase {

    /// Settings of the iPhone, and why each may stay when the account goes.
    private static let deviceSettings: [String: String] = [
        "app_language": "the language chosen for the app on this iPhone",
        "selected_currency": "the display currency chosen on this iPhone",
        "cached_exchange_rates": "public exchange rates",
        "exchange_rates_date": "the day those rates were fetched",
        "renewalAlerts": "a reminder switch of this iPhone",
        "trialEndingAlerts": "a reminder switch of this iPhone",
        "hasCompletedOnboarding": "the first-run screens were seen on this iPhone",
        "lastSeenVersion": "What's New was shown for this version",
        "install_marker": "tells a fresh install from a relaunch",
        "review_requests_this_year": "how often this iPhone was asked for a review",
        "review_last_request_date": "how often this iPhone was asked for a review",
        "review_current_year": "how often this iPhone was asked for a review",
        "review_receipt_milestone_last": "how often this iPhone was asked for a review",
        "current_subscription_tier": "the plan the App Store confirmed for the Apple Account on this iPhone",
        "pending_first_run_tally": "made before any account exists; joins the list of whoever signs in next, then cleared",
        "age_gate_device_passed": "someone confirmed their age on this iPhone before an account existed",
        "age_gate_blocked_at": "an under-age answer blocks this iPhone, whoever signs in",
        "debug_auth_bypass": "debug builds only",
        "debug_premium_override": "debug builds only",
        "debug_free_pro": "debug builds only",
        "saved_list_is_demo": "debug builds only: marks a saved list as the demo set, so an ordinary launch throws it away",
    ]

    /// Kept somewhere other than the app's settings, and removed by the store that owns them.
    private static let keptElsewhere: [String: String] = [
        "widget_": "the widgets' copy, rewritten from the list and empty when the list is (and what earlier versions published, removed on the next publish)",
        "liveActivity_": "published by earlier versions, removed on the next publish",
        "auth_cached_user_id": "Keychain, removed at sign-out",
        "auth_cached_email": "Keychain, removed at sign-out",
        "auth_cached_created_at": "Keychain, removed at sign-out",
        "auth_access_token": "Keychain, removed at sign-out",
        "auth_refresh_token": "Keychain, removed at sign-out",
        "pending_firstName": "Keychain, removed when a sign-up finishes, fails, or the iPhone is wiped",
        "pending_lastName": "Keychain, removed when a sign-up finishes, fails, or the iPhone is wiped",
        "pending_nameEmail": "Keychain, removed when a sign-up finishes, fails, or the iPhone is wiped",
        "profile_": "Keychain, removed by AccountMemory.forgetName when the iPhone is wiped",
    ]

    func testEverySavedNameIsThePersonsOrTheDevices() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let appFolder = root.appendingPathComponent("Pausely")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: appFolder.path), "Sources aren't readable from this test run")

        // The ways a name reaches storage in this codebase.
        let patterns = [
            #"forKey: "([^"\\]+)"#,                              // defaults.set(x, forKey: "name") and "name_\(…)"
            #"@AppStorage\("([^"]+)"\)"#,
            #"@AppSetting\("([^"]+)""#,
            #"let \w*[Kk]ey\w* *= *"([^"\\]+)"#,                 // let somethingKey = "name"
            #"\) -> String \{ "([^"\\]+)\\\("#,                  // func minutesKey(_:) -> String { "usage_\(name)" }
            #"static let \w+ = "([a-z]+(?:_[a-z0-9]+)+)""#,       // a name in an `enum Key`: static let blockedAt = "age_gate_blocked_at"
        ].map { try! NSRegularExpression(pattern: $0) }

        var found: [String: String] = [:]   // name → first file it was seen in
        let files = try XCTUnwrap(FileManager.default.enumerator(at: appFolder, includingPropertiesForKeys: nil))
        for case let file as URL in files where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            let whole = NSRange(text.startIndex..., in: text)
            for pattern in patterns {
                for match in pattern.matches(in: text, range: whole) {
                    guard let range = Range(match.range(at: 1), in: text) else { continue }
                    let name = String(text[range])
                    if found[name] == nil { found[name] = String(file.path.dropFirst(root.path.count + 1)) }
                }
            }
        }
        XCTAssertGreaterThan(found.count, 40, "The scan found too few saved names to be reading the sources")

        let undecided = found.keys.sorted().filter { name in
            !LocalUserData.personalKeys.contains(name)
                && !LocalUserData.personalKeyPrefixes.contains(where: name.hasPrefix)
                && Self.deviceSettings[name] == nil
                && !Self.keptElsewhere.keys.contains(where: name.hasPrefix)
        }
        XCTAssertEqual(undecided, [], "Saved under a name nobody has decided about: is it the person's (LocalUserData.personalKeys) or the iPhone's?")
    }

    func testWipingRemovesEveryPersonalValueAndLeavesTheDevicesSettings() throws {
        let suite = "LocalDataGuardTests"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        for key in LocalUserData.personalKeys { defaults.set("someone's", forKey: key) }
        defaults.set(90, forKey: "usage_Netflix")
        defaults.set("2026-11", forKey: "usage_month_Netflix")
        defaults.set(Date(), forKey: "age_consent_user_5f0c3a0e")
        defaults.set(true, forKey: "age_consent_pending_sync_5f0c3a0e")
        for key in Self.deviceSettings.keys { defaults.set("this iPhone's", forKey: key) }

        LocalUserData.removeSavedValues(from: defaults)

        let left = defaults.persistentDomain(forName: suite) ?? [:]
        XCTAssertEqual(Set(left.keys), Set(Self.deviceSettings.keys))
    }

    /// The hours a person typed are theirs: after a wipe the next account starts with none.
    func testTypedHoursAreGoneAfterAWipe() throws {
        let suite = "LocalDataGuardTests.hours"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let log = UsageLog(defaults: defaults)
        log.setMonthlyUsage(minutes: 600, for: "Netflix")
        XCTAssertEqual(log.getUsage(for: "Netflix")?.minutesUsed, 600)

        LocalUserData.removeSavedValues(from: defaults)

        XCTAssertNil(log.getUsage(for: "Netflix"))
    }

    // MARK: - Signed out

    func testSigningOutHidesTheListAndKeepsTheCopyOnTheIPhone() async throws {
        let sandbox = StoreSandbox()
        let store = SubscriptionStore.shared
        _ = try await store.addSubscription(Subscription(name: "Netflix", amount: 15.49, billingFrequency: .monthly))
        let saved = AppSettings.shared.cachedSubscriptions
        XCTAssertFalse(saved.isEmpty)

        store.hideList()

        XCTAssertEqual(store.subscriptions, [])
        XCTAssertEqual(store.totalMonthlySpend, 0)
        XCTAssertEqual(AppSettings.shared.cachedSubscriptions, saved, "The copy on the iPhone waits for the same person to sign back in")
        XCTAssertEqual(WidgetDataStore.feed(for: store.subscriptions, now: Date()).charges, [])

        // A Shortcut can still try to add. It is refused, and the copy on the iPhone stays whole.
        do {
            _ = try await store.addSubscription(Subscription(name: "Spotify", amount: 11.99, billingFrequency: .monthly))
            XCTFail("An add while signed out went through")
        } catch {}
        XCTAssertEqual(store.subscriptions, [])
        XCTAssertEqual(AppSettings.shared.cachedSubscriptions, saved)

        store.showList()
        XCTAssertEqual(store.subscriptions.map(\.name), ["Netflix"])
        _ = try await store.addSubscription(Subscription(name: "Spotify", amount: 11.99, billingFrequency: .monthly))
        XCTAssertEqual(store.subscriptions.map(\.name), ["Spotify", "Netflix"])
        await sandbox.restore()
    }

    func testAReminderTappedWhileSignedOutOpensNothing() {
        let center = VerdictCenter()
        center.isSignedIn = { false }
        center.open(subscriptionId: UUID())
        center.openPausePlan()
        XCTAssertNil(center.presented)
        XCTAssertFalse(center.showingPausePlan)

        center.isSignedIn = { true }
        let id = UUID()
        center.open(subscriptionId: id)
        XCTAssertEqual(center.presented?.subscriptionId, id)
        center.forget()
        XCTAssertNil(center.presented)
    }

    /// A tap on a widget or a search result that starts the app asks for a subscription before the main
    /// screen exists. The request is held until it does; before, it was announced once to nobody.
    func testARequestToOpenASubscriptionWaitsForTheMainScreen() {
        let center = VerdictCenter()
        center.isSignedIn = { true }
        let id = UUID()
        center.showSubscription(id)
        XCTAssertEqual(center.subscriptionToShow?.subscriptionId, id)

        center.forget()
        XCTAssertNil(center.subscriptionToShow)

        center.isSignedIn = { false }
        center.showSubscription(id)
        XCTAssertNil(center.subscriptionToShow, "Signed out, a widget or a search result opens nothing")
    }

    func testASearchResultNamesItsSubscription() {
        let id = UUID()
        let activity = NSUserActivity(activityType: CSSearchableItemActionType)
        activity.userInfo = [CSSearchableItemActivityIdentifier: id.uuidString]
        XCTAssertEqual(SpotlightManager.subscriptionId(in: activity), id)

        let other = NSUserActivity(activityType: "com.example.other")
        other.userInfo = [CSSearchableItemActivityIdentifier: id.uuidString]
        XCTAssertNil(SpotlightManager.subscriptionId(in: other))
    }

    // MARK: - A name typed at sign-up

    func testANameTypedForOneAddressIsNeverGivenToAnotherAccount() {
        let typed = AccountMemory.nameTyped(for: "sam@example.com", first: "Alex", last: "Lee",
                                                       typedFor: "alex@example.com")
        XCTAssertNil(typed.first)
        XCTAssertNil(typed.last)

        let own = AccountMemory.nameTyped(for: "Alex@Example.com ", first: "Alex", last: "Lee",
                                                     typedFor: "alex@example.com")
        XCTAssertEqual(own.first, "Alex")
        XCTAssertEqual(own.last, "Lee")

        // Left by an older version, with no address beside it: nobody's.
        let unknown = AccountMemory.nameTyped(for: "sam@example.com", first: "Alex", last: nil, typedFor: nil)
        XCTAssertNil(unknown.first)
    }
}
