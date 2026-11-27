import Foundation

/// One thing that happened to a subscription. Stored under iOS hardware data protection and synced
/// to your account when signed in (`LifecycleSync`).
struct LifecycleEvent: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case added          // the user started tracking it
        case renewed        // a renewal day passed while it was active
        case trialEnded     // a free trial ran out and it started charging
        case priceChanged   // the user changed the amount
        case cancelled      // the user marked it cancelled
        case reactivated    // a cancelled subscription became active again
        case deleted        // the user removed it from Pausely
        case kept           // the user decided to keep it at a renewal check
    }

    let id: UUID
    let kind: Kind
    let subscriptionId: UUID
    let subscriptionName: String
    let date: Date
    let amount: Decimal
    let currency: String
    let frequency: BillingFrequency
    let previousAmount: Decimal?
    /// The renewal this event is about: the one kept, or the next charge a cancellation avoids.
    /// A day, not a moment (`BillingDay`), like the anchor below.
    @SavedDay var renewalDate: Date?
    /// The subscription's billing anchor when the event happened, so the charges a cancellation
    /// avoids can be computed even after the subscription is deleted.
    @SavedDay var anchorDate: Date?

    init(id: UUID = UUID(), kind: Kind, subscription: Subscription, date: Date,
         previousAmount: Decimal? = nil, renewalDate: Date? = nil) {
        self.id = id
        self.kind = kind
        self.subscriptionId = subscription.id
        self.subscriptionName = subscription.name
        self.date = date
        self.amount = subscription.amount
        self.currency = subscription.currency
        self.frequency = subscription.billingFrequency
        self.previousAmount = previousAmount
        self.renewalDate = renewalDate
        self.anchorDate = subscription.nextBillingDate
    }

    init(id: UUID, kind: Kind, subscriptionId: UUID, subscriptionName: String, date: Date,
         amount: Decimal, currency: String, frequency: BillingFrequency,
         previousAmount: Decimal? = nil, renewalDate: Date? = nil, anchorDate: Date? = nil) {
        self.id = id
        self.kind = kind
        self.subscriptionId = subscriptionId
        self.subscriptionName = subscriptionName
        self.date = date
        self.amount = amount
        self.currency = currency
        self.frequency = frequency
        self.previousAmount = previousAmount
        self.renewalDate = renewalDate
        self.anchorDate = anchorDate
    }
}

/// An append-only history of subscription events (Lago keeps the same kind of vocabulary:
/// started, trial ended, updated, canceled). It powers price history, renewals that happened while
/// the app was closed, and the savings ledger. Synced to your account when signed in (`LifecycleSync`).
@MainActor
final class LifecycleEventLog: ObservableObject {
    static let shared = LifecycleEventLog()
    nonisolated static let maxEvents = 2_000

    @Published private(set) var events: [LifecycleEvent] = []
    private let fileURL: URL

    /// False while the saved history exists but can't be read (a background launch on a locked phone).
    /// Nothing is written until it has been read: saving now would replace the whole history with the
    /// one or two things that happened since launch.
    private(set) var historyIsLoaded = true
    /// What was recorded while the history couldn't be read. Joined to it as soon as it can be.
    private var recordedBeforeLoad: [LifecycleEvent] = []

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL()
        switch DeviceFile.load([LifecycleEvent].self, from: self.fileURL) {
        case .value(let saved):
            events = saved
            DeviceFile.relaxProtection(of: self.fileURL)
        case .missing:
            events = []
        case .unreadable:
            historyIsLoaded = false
        }
    }

    func record(_ kind: LifecycleEvent.Kind, for subscription: Subscription, date: Date = Date(),
                previousAmount: Decimal? = nil, renewalDate: Date? = nil) {
        let event = LifecycleEvent(kind: kind, subscription: subscription, date: date,
                                   previousAmount: previousAmount, renewalDate: renewalDate)
        events.append(event)
        if !historyIsLoaded { recordedBeforeLoad.append(event) }
        save()
        if self === Self.shared {
            Task { await LifecycleSync.shared.upload(event) }
        }
    }

    /// Reads the history if an earlier attempt couldn't, and saves anything recorded in between.
    /// Called whenever the app comes to the foreground, when the phone is certainly unlocked.
    func loadIfNeeded() {
        guard !historyIsLoaded else { return }
        save()
    }

    /// Reads the history again from its saved form. Its days are held as noon in the phone's time zone
    /// (`BillingDay`), so after a change of zone they are read afresh.
    func reload() {
        guard historyIsLoaded, case .value(let saved) = DeviceFile.load([LifecycleEvent].self, from: fileURL) else { return }
        events = saved
    }

    /// Rewrites local guest subscription IDs to their matched cloud IDs on first-sync dedup.
    func remapSubscriptionIDs(_ map: [UUID: UUID]) {
        guard !map.isEmpty else { return }
        var changed = false
        events = events.map { event in
            guard let target = map[event.subscriptionId] else { return event }
            changed = true
            return LifecycleEvent(
                id: event.id, kind: event.kind, subscriptionId: target,
                subscriptionName: event.subscriptionName, date: event.date,
                amount: event.amount, currency: event.currency, frequency: event.frequency,
                previousAmount: event.previousAmount, renewalDate: event.renewalDate,
                anchorDate: event.anchorDate
            )
        }
        if changed { save() }
    }

    /// Wipes the log (used when the user deletes their account or data).
    func removeAll() {
        restore([])
    }

    /// Replaces the history (tests put back what they changed).
    func restore(_ saved: [LifecycleEvent]) {
        events = saved
        recordedBeforeLoad = []
        historyIsLoaded = true
        save()
    }

    // MARK: - Persistence

    private func save() {
        if !historyIsLoaded {
            switch DeviceFile.load([LifecycleEvent].self, from: fileURL) {
            case .value(let saved):
                let known = Set(saved.map(\.id))
                events = saved + recordedBeforeLoad.filter { !known.contains($0.id) }
                DeviceFile.relaxProtection(of: fileURL)
            case .missing:
                events = recordedBeforeLoad
            case .unreadable:
                return
            }
            recordedBeforeLoad = []
            historyIsLoaded = true
        }
        if events.count > Self.maxEvents {
            events.removeFirst(events.count - Self.maxEvents)
        }
        do {
            try DeviceFile.save(events, to: fileURL)
        } catch {
            PauselyLogger.error("Lifecycle log save failed: \(String(describing: type(of: error)))", category: "lifecycle")
        }
    }

    private static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Pausely", isDirectory: true).appendingPathComponent("lifecycle_events.json")
    }
}
