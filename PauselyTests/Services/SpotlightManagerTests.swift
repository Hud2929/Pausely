import CoreSpotlight
import XCTest
@testable import Pausely

/// What iOS search shows must match the subscription list: deleted subscriptions disappear, and
/// signing out or deleting the account leaves nothing behind.
@MainActor
final class SpotlightManagerTests: XCTestCase {

    /// Stands in for the system index: keeps what's indexed, by identifier.
    private final class FakeIndex: SpotlightIndexing {
        var items: [String: CSSearchableItem] = [:]

        func deleteSearchableItems(withDomainIdentifiers domainIdentifiers: [String]) async throws {
            items = items.filter { !domainIdentifiers.contains($0.value.domainIdentifier ?? "") }
        }

        func indexSearchableItems(_ newItems: [CSSearchableItem]) async throws {
            for item in newItems { items[item.uniqueIdentifier] = item }
        }
    }

    private var index: FakeIndex!
    private var spotlight: SpotlightManager!
    private let netflix = TestFactories.makeSubscription(name: "Netflix", amount: 15.49, category: "Entertainment")
    private let spotify = TestFactories.makeSubscription(name: "Spotify", amount: 11.99, category: "Music")

    override func setUp() {
        super.setUp()
        index = FakeIndex()
        spotlight = SpotlightManager(index: index)
    }

    private var indexedNames: Set<String> { Set(index.items.values.compactMap { $0.attributeSet.title }) }

    func testDeletedSubscriptionLeavesSearch() async {
        await spotlight.index(subscriptions: [netflix, spotify]).value
        XCTAssertEqual(indexedNames, ["Netflix", "Spotify"])

        await spotlight.index(subscriptions: [netflix]).value
        XCTAssertEqual(indexedNames, ["Netflix"], "Spotify was deleted, so search must stop showing it")
    }

    func testSignOutAndAccountDeletionClearSearch() async {
        await spotlight.index(subscriptions: [netflix, spotify]).value
        await spotlight.index(subscriptions: []).value
        XCTAssertTrue(index.items.isEmpty, "nobody else on this iPhone should find the old subscriptions")
    }

    func testRapidChangesEndWithTheLatestList() async {
        spotlight.index(subscriptions: [netflix, spotify])
        spotlight.index(subscriptions: [spotify])
        await spotlight.index(subscriptions: [netflix]).value
        XCTAssertEqual(indexedNames, ["Netflix"])
    }

    func testItemShowsNameAmountAndSearchWords() {
        let item = spotlight.searchableItem(for: netflix)
        XCTAssertEqual(item.uniqueIdentifier, netflix.id.uuidString)
        XCTAssertEqual(item.domainIdentifier, SpotlightManager.domainIdentifier)
        XCTAssertEqual(item.attributeSet.title, "Netflix")
        XCTAssertEqual(item.attributeSet.contentDescription,
                       "\(netflix.displayAmount) • \(netflix.billingFrequency.displayName)")
        XCTAssertEqual(item.attributeSet.keywords, ["Entertainment", "subscription", "billing"])
    }
}
