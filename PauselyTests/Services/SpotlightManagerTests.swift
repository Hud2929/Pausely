import CoreSpotlight
import XCTest
@testable import Pausely

/// What iOS search shows must match the subscription list: deleted subscriptions disappear, and
/// signing out or deleting the account leaves nothing behind.
@MainActor
final class SpotlightManagerTests: XCTestCase {

    /// Stands in for the system index: keeps what's indexed, by identifier.
    private actor FakeIndex: SpotlightIndexing {
        private var entries: [String: SpotlightEntry] = [:]

        func removeAll(inDomain domain: String) async throws { entries = [:] }
        func add(_ new: [SpotlightEntry], toDomain domain: String) async throws {
            for entry in new { entries[entry.id] = entry }
        }

        var names: Set<String> { Set(entries.values.map(\.title)) }
    }

    private var index: FakeIndex!
    private var spotlight: SpotlightManager!
    private var savedLanguage: Any?
    private let netflix = TestFactories.makeSubscription(name: "Netflix", amount: 15.49, category: "Entertainment")
    private let spotify = TestFactories.makeSubscription(name: "Spotify", amount: 11.99, category: "Music")

    override func setUp() {
        super.setUp()
        index = FakeIndex()
        spotlight = SpotlightManager(index: index)
        savedLanguage = UserDefaults.standard.object(forKey: L10n.languageKey)
        UserDefaults.standard.set("en", forKey: L10n.languageKey)
    }

    override func tearDown() {
        UserDefaults.standard.set(savedLanguage, forKey: L10n.languageKey)
        super.tearDown()
    }

    func testDeletedSubscriptionLeavesSearch() async {
        await spotlight.index(subscriptions: [netflix, spotify]).value
        let both = await index.names
        XCTAssertEqual(both, ["Netflix", "Spotify"])

        await spotlight.index(subscriptions: [netflix]).value
        let one = await index.names
        XCTAssertEqual(one, ["Netflix"], "Spotify was deleted, so search must stop showing it")
    }

    func testSignOutAndAccountDeletionClearSearch() async {
        await spotlight.index(subscriptions: [netflix, spotify]).value
        await spotlight.index(subscriptions: []).value
        let left = await index.names
        XCTAssertTrue(left.isEmpty, "nobody else on this iPhone should find the old subscriptions")
    }

    func testRapidChangesEndWithTheLatestList() async {
        spotlight.index(subscriptions: [netflix, spotify])
        spotlight.index(subscriptions: [spotify])
        await spotlight.index(subscriptions: [netflix]).value
        let names = await index.names
        XCTAssertEqual(names, ["Netflix"])
    }

    /// The line under the name is the price with its period as one phrase, and the search words are
    /// in the reader's language. It used to read "$15.49 • Monthly", with English keywords for everyone.
    func testAResultShowsThePriceAsAPhraseAndIsFoundInTheReadersLanguage() {
        let entry = spotlight.entry(for: netflix)
        XCTAssertEqual(entry.id, netflix.id.uuidString)
        XCTAssertEqual(entry.title, "Netflix")
        XCTAssertEqual(entry.detail, netflix.billingFrequency.priced(netflix.chargeText))
        XCTAssertTrue(entry.detail.hasSuffix(" a month"), entry.detail)
        XCTAssertEqual(entry.keywords, ["Entertainment", "Subscriptions"])

        UserDefaults.standard.set("de", forKey: L10n.languageKey)
        XCTAssertEqual(spotlight.entry(for: netflix).keywords, ["Unterhaltung", "Abos"])
    }

    func testAnEntryBecomesTheSystemsSearchItem() {
        let item = spotlight.entry(for: netflix).item(inDomain: SpotlightManager.domainIdentifier)
        XCTAssertEqual(item.uniqueIdentifier, netflix.id.uuidString)
        XCTAssertEqual(item.domainIdentifier, SpotlightManager.domainIdentifier)
        XCTAssertEqual(item.attributeSet.title, "Netflix")
        XCTAssertEqual(item.attributeSet.contentDescription, netflix.billingFrequency.priced(netflix.chargeText))
        XCTAssertEqual(item.attributeSet.keywords ?? [], ["Entertainment", "Subscriptions"])
    }
}
