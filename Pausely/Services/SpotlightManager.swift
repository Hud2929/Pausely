import CoreSpotlight
import UniformTypeIdentifiers
import os.log

/// One search result as plain values: this is what crosses from the app to the system's index.
struct SpotlightEntry: Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let keywords: [String]

    func item(inDomain domain: String) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(itemContentType: UTType.item.identifier)
        attributes.title = title
        attributes.displayName = title
        attributes.contentDescription = detail
        attributes.keywords = keywords
        return CSSearchableItem(uniqueIdentifier: id, domainIdentifier: domain, attributeSet: attributes)
    }
}

/// The part of the system's Spotlight index Pausely uses (tests use a stand-in).
protocol SpotlightIndexing: Sendable {
    func removeAll(inDomain domain: String) async throws
    func add(_ entries: [SpotlightEntry], toDomain domain: String) async throws
}

/// The system's own index. The search items are built here, on the far side: they are objects that
/// cannot be handed from one thread to another, and plain values can.
struct SystemSpotlight: SpotlightIndexing {
    func removeAll(inDomain domain: String) async throws {
        try await CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domain])
    }

    func add(_ entries: [SpotlightEntry], toDomain domain: String) async throws {
        try await CSSearchableIndex.default().indexSearchableItems(entries.map { $0.item(inDomain: domain) })
    }
}

/// Indexes subscriptions into Core Spotlight so users can find them via iOS system search.
@MainActor
final class SpotlightManager {
    static let shared = SpotlightManager(index: SystemSpotlight())
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
        let entries = subscriptions.map { entry(for: $0) }
        let previous = lastUpdate
        let index = self.index
        let task = Task {
            await previous?.value
            do {
                try await index.removeAll(inDomain: Self.domainIdentifier)
                if !entries.isEmpty { try await index.add(entries, toDomain: Self.domainIdentifier) }
                os_log("Indexed %d subscriptions in Spotlight", log: .default, type: .info, entries.count)
            } catch {
                os_log("Spotlight update failed: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
            }
        }
        lastUpdate = task
        return task
    }

    /// The subscription a tapped search result stands for.
    nonisolated static func subscriptionId(in activity: NSUserActivity) -> UUID? {
        guard activity.activityType == CSSearchableItemActionType else { return nil }
        return (activity.userInfo?[CSSearchableItemActivityIdentifier] as? String).flatMap(UUID.init(uuidString:))
    }

    // MARK: - Helpers

    /// What search shows for a subscription: its name, its price with its period as one phrase, and
    /// the words that find it in the reader's language.
    func entry(for subscription: Subscription) -> SpotlightEntry {
        SpotlightEntry(id: subscription.id.uuidString,
                       title: subscription.name,
                       detail: subscription.billingFrequency.priced(subscription.chargeText),
                       keywords: [SubscriptionCategory.matching(subscription.category).localizedName, L10n.string("Subscriptions")])
    }
}
