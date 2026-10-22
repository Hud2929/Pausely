import Foundation

/// One thing that happened to a subscription. Stored only on this device.
struct LifecycleEvent: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case added          // the user started tracking it
        case renewed        // a renewal day passed while it was active
        case trialEnded     // a free trial ran out and it started charging
        case priceChanged   // the user changed the amount
        case cancelled      // the user marked it cancelled
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

    init(id: UUID = UUID(), kind: Kind, subscription: Subscription, date: Date, previousAmount: Decimal? = nil) {
        self.id = id
        self.kind = kind
        self.subscriptionId = subscription.id
        self.subscriptionName = subscription.name
        self.date = date
        self.amount = subscription.amount
        self.currency = subscription.currency
        self.frequency = subscription.billingFrequency
        self.previousAmount = previousAmount
    }
}

/// An append-only, on-device history of subscription events (Lago keeps the same kind of vocabulary:
/// started, trial ended, updated, canceled). It powers price history, renewals that happened while
/// the app was closed, and the savings ledger. Nothing here leaves the device.
@MainActor
final class LifecycleEventLog: ObservableObject {
    static let shared = LifecycleEventLog()
    static let maxEvents = 2_000

    @Published private(set) var events: [LifecycleEvent] = []
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL()
        events = Self.load(from: self.fileURL)
    }

    func record(_ kind: LifecycleEvent.Kind, for subscription: Subscription, date: Date = Date(),
                previousAmount: Decimal? = nil) {
        events.append(LifecycleEvent(kind: kind, subscription: subscription, date: date, previousAmount: previousAmount))
        if events.count > Self.maxEvents {
            events.removeFirst(events.count - Self.maxEvents)
        }
        save()
    }

    func events(for subscriptionId: UUID) -> [LifecycleEvent] {
        events.filter { $0.subscriptionId == subscriptionId }
    }

    /// Wipes the log (used when the user deletes their account or data).
    func removeAll() {
        events = []
        save()
    }

    // MARK: - Persistence

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(events)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            PauselyLogger.error("Lifecycle log save failed: \(error.localizedDescription)", category: "lifecycle")
        }
    }

    private static func load(from url: URL) -> [LifecycleEvent] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([LifecycleEvent].self, from: data)) ?? []
    }

    private static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Pausely", isDirectory: true).appendingPathComponent("lifecycle_events.json")
    }
}
