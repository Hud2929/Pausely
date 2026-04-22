import CoreSpotlight
import UniformTypeIdentifiers
import os.log

/// Indexes subscriptions into Core Spotlight so users can find them via iOS system search.
@MainActor
final class SpotlightManager {
    static let shared = SpotlightManager()
    private let domainIdentifier = "com.pausely.app.subscription"

    private init() {}

    // MARK: - Index

    func index(subscriptions: [Subscription]) {
        let items = subscriptions.map { searchableItem(for: $0) }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error {
                os_log("Spotlight index failed: %{public}@", log: .default, type: .error, error.localizedDescription)
            } else {
                os_log("Indexed %d subscriptions in Spotlight", log: .default, type: .info, items.count)
            }
        }
    }

    // MARK: - Delete

    func deleteIndex() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { error in
            if let error {
                os_log("Spotlight delete failed: %{public}@", log: .default, type: .error, error.localizedDescription)
            }
        }
    }

    func delete(subscriptionID: String) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [subscriptionID]) { error in
            if let error {
                os_log("Spotlight delete item failed: %{public}@", log: .default, type: .error, error.localizedDescription)
            }
        }
    }

    // MARK: - Helpers

    private func searchableItem(for subscription: Subscription) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: UTType.item.identifier)
        attributeSet.title = subscription.name
        attributeSet.contentDescription = "\(subscription.displayAmount) • \(subscription.billingFrequency.displayName)"
        attributeSet.keywords = [subscription.category ?? "subscription", "subscription", "billing"]
        attributeSet.displayName = subscription.name

        let item = CSSearchableItem(
            uniqueIdentifier: subscription.id.uuidString,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
        return item
    }
}
