import CoreSpotlight
import UniformTypeIdentifiers
import os.log

/// The part of the system's Spotlight index Pausely uses (tests use a stand-in).
protocol SpotlightIndexing: AnyObject {
    func deleteSearchableItems(withDomainIdentifiers domainIdentifiers: [String]) async throws
    func indexSearchableItems(_ items: [CSSearchableItem]) async throws
}

extension CSSearchableIndex: SpotlightIndexing {}

/// Indexes subscriptions into Core Spotlight so users can find them via iOS system search.
@MainActor
final class SpotlightManager {
    static let shared = SpotlightManager(index: CSSearchableIndex.default())
    static let domainIdentifier = "com.pausely.app.subscription"

    private let index: SpotlightIndexing
    private var lastUpdate: Task<Void, Never>?

    init(index: SpotlightIndexing) {
        self.index = index
    }

    // MARK: - Index

    /// Makes Spotlight show exactly these subscriptions. Everything Pausely indexed before is removed
    /// first, so a deleted subscription (and every subscription, after sign-out or account deletion)
    /// stops appearing in search. Updates run one at a time, in order.
    @discardableResult
    func index(subscriptions: [Subscription]) -> Task<Void, Never> {
        let items = subscriptions.map { searchableItem(for: $0) }
        let previous = lastUpdate
        let index = self.index
        let task = Task {
            await previous?.value
            do {
                try await index.deleteSearchableItems(withDomainIdentifiers: [Self.domainIdentifier])
                if !items.isEmpty { try await index.indexSearchableItems(items) }
                os_log("Indexed %d subscriptions in Spotlight", log: .default, type: .info, items.count)
            } catch {
                os_log("Spotlight update failed: %{public}@", log: .default, type: .error, error.localizedDescription)
            }
        }
        lastUpdate = task
        return task
    }

    // MARK: - Helpers

    func searchableItem(for subscription: Subscription) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: UTType.item.identifier)
        attributeSet.title = subscription.name
        attributeSet.contentDescription = "\(subscription.displayAmount) • \(subscription.billingFrequency.displayName)"
        attributeSet.keywords = [subscription.category ?? "subscription", "subscription", "billing"]
        attributeSet.displayName = subscription.name

        return CSSearchableItem(
            uniqueIdentifier: subscription.id.uuidString,
            domainIdentifier: Self.domainIdentifier,
            attributeSet: attributeSet
        )
    }
}
