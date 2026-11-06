import Foundation

/// How the server's copy of the subscription list and this iPhone's copy become one list.
///
/// The server is the shared truth, with three exceptions that keep this iPhone's work from being lost:
/// a change still waiting in the sync queue wins over the server; fields only this iPhone stores
/// (app bundle id, plan tier, price override) are kept; and a renewal date the server doesn't have yet
/// (older app versions never sent it) is kept and sent back up.
struct SubscriptionSyncMerge {
    /// The list to show and cache.
    var subscriptions: [Subscription] = []
    /// On this iPhone only: create them on the server.
    var upload: [Subscription] = []
    /// On the server without the renewal date this iPhone knows: send the date up.
    var backfill: [Subscription] = []

    /// - Parameters:
    ///   - server: the signed-in person's rows, newest first.
    ///   - local: this iPhone's list.
    ///   - pending: changes still waiting to reach the server.
    ///   - firstSyncForUser: true until this person's list has been fetched once on this iPhone.
    ///     Only then is a subscription missing from the server new (made here before sign-in or while
    ///     sync failed); afterwards it was deleted on another device.
    static func merge(server: [Subscription], local: [Subscription], pending: [SyncOperation],
                      firstSyncForUser: Bool) -> SubscriptionSyncMerge {
        var result = SubscriptionSyncMerge()
        let localByID = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let deleted = Set(pending.filter { $0.type == .delete }.map(\.subscriptionId))
        let changed = Set(pending.filter { $0.type != .delete }.map(\.subscriptionId))
        let serverIDs = Set(server.map(\.id))

        // On this iPhone only, newest work first.
        for item in local where !serverIDs.contains(item.id) && !deleted.contains(item.id) {
            if changed.contains(item.id) || firstSyncForUser {
                result.subscriptions.append(item)
                result.upload.append(item)
            }
        }

        for remote in server where !deleted.contains(remote.id) {
            guard let mine = localByID[remote.id] else {
                result.subscriptions.append(remote)
                continue
            }
            if changed.contains(remote.id) {
                result.subscriptions.append(mine)
                continue
            }
            var merged = remote
            merged.bundleIdentifier = mine.bundleIdentifier
            merged.selectedTier = mine.selectedTier
            merged.userPriceUSD = mine.userPriceUSD
            merged.isPriceOverridden = mine.isPriceOverridden
            if remote.nextBillingDate == nil, let date = mine.nextBillingDate {
                merged.nextBillingDate = date
                result.backfill.append(merged)
            }
            result.subscriptions.append(merged)
        }
        return result
    }
}
