import Foundation

/// How the server's copy of the subscription list and this iPhone's copy become one list.
///
/// The server is the shared truth, with three exceptions that keep this iPhone's work from being lost:
/// a change still waiting to be sent wins over the server; fields only this iPhone stores
/// (the app bundle id) are kept; and a renewal date the server doesn't have yet
/// (older app versions never sent it) is kept and sent back up.
struct SubscriptionSyncMerge {
    /// The list to show and cache.
    var subscriptions: [Subscription] = []
    /// On this iPhone only: create them on the server.
    var upload: [Subscription] = []
    /// On the server without the renewal date or local details this iPhone knows: send them up.
    var backfill: [Subscription] = []
    /// Local-only guest rows matched by `ServiceName.same` to an existing server subscription on first sync.
    var supersededLocalIDs: [UUID] = []

    /// - Parameters:
    ///   - server: the signed-in person's rows, newest first.
    ///   - local: this iPhone's list.
    ///   - pending: changes still waiting to reach the server, and ones made while the server's list
    ///     was on its way here (it may be older than they are).
    ///   - firstSyncForUser: true until this person's list has been fetched once on this iPhone.
    ///     Only then is a subscription missing from the server new (made here before sign-in);
    ///     afterwards it is new only if its add is still waiting, and otherwise it was deleted on
    ///     another device. An edit doesn't bring back what another device deleted.
    static func merge(server: [Subscription], local: [Subscription], pending: [UUID: SyncIntent.Kind],
                      firstSyncForUser: Bool) -> SubscriptionSyncMerge {
        var result = SubscriptionSyncMerge()
        let localByID = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let deleted = Set(pending.filter { $0.value == .delete }.keys)
        let added = Set(pending.filter { $0.value == .create }.keys)
        let changed = Set(pending.filter { $0.value != .delete }.keys)
        let serverIDs = Set(server.map(\.id))
        let liveServer = server.filter { !deleted.contains($0.id) }
        var matchedGuestByServerID: [UUID: Subscription] = [:]

        // On this iPhone only, newest work first.
        for item in local where !serverIDs.contains(item.id) && !deleted.contains(item.id) {
            if added.contains(item.id) || firstSyncForUser {
                if firstSyncForUser,
                   let match = liveServer.first(where: { ServiceName.same($0.name, item.name) && matchedGuestByServerID[$0.id] == nil }) {
                    result.supersededLocalIDs.append(item.id)
                    matchedGuestByServerID[match.id] = item
                    continue
                }
                result.subscriptions.append(item)
                result.upload.append(item)
            }
        }

        for remote in liveServer {
            if let mine = localByID[remote.id] {
                if changed.contains(remote.id) {
                    result.subscriptions.append(mine)
                    continue
                }
                var merged = remote
                if remote.nextBillingDate == nil, let date = mine.nextBillingDate {
                    merged.nextBillingDate = date
                    result.backfill.append(merged)
                }
                result.subscriptions.append(merged)
                continue
            }
            if let guest = matchedGuestByServerID[remote.id] {
                var merged = remote
                var needsBackfill = false
                if merged.nextBillingDate == nil, let date = guest.nextBillingDate {
                    merged.nextBillingDate = date
                    needsBackfill = true
                }
                if (merged.notes ?? "").isEmpty, let notes = guest.notes, !notes.isEmpty {
                    merged.notes = notes
                    needsBackfill = true
                }
                if (merged.paymentMethod ?? "").isEmpty, let method = guest.paymentMethod, !method.isEmpty {
                    merged.paymentMethod = method
                    needsBackfill = true
                }
                if needsBackfill { result.backfill.append(merged) }
                result.subscriptions.append(merged)
                continue
            }
            result.subscriptions.append(remote)
        }
        return result
    }
}
