import Foundation

/// On-device history of per-email *facts* (merchant, amount, date, flags). Never email text.
/// It lets incremental scans re-analyze the full history, which is what makes recurrence detection possible.
/// Stored locally with file protection; an inbox's facts are removed when it is disconnected.
enum ReceiptLedger {

    private static let maxEntries = 4_000
    private static let retention: TimeInterval = 3 * 365 * 86_400

    private static var fileURL: URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("receipt_ledger.json")
    }

    static func load() -> [ReceiptSignal] {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return (try? decoder.decode([ReceiptSignal].self, from: data)) ?? []
    }

    static func save(_ signals: [ReceiptSignal]) {
        guard let url = fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(signals) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try? mutableURL.setResourceValues(values)
    }

    /// Idempotent merge: dedupes by message id (the same receipt in two inboxes is one fact, remembering
    /// both inboxes), drops very old facts, caps the size.
    static func merge(_ new: [ReceiptSignal], into existing: [ReceiptSignal], now: Date = Date()) -> [ReceiptSignal] {
        var byId: [String: ReceiptSignal] = [:]
        for signal in existing { byId[signal.id] = signal }
        for signal in new {
            var merged = signal
            let sources = Set((byId[signal.id]?.sources ?? []) + (signal.sources ?? []))
            merged.sources = sources.isEmpty ? nil : sources.sorted()
            byId[signal.id] = merged
        }
        let cutoff = now.addingTimeInterval(-retention)
        return byId.values
            .filter { $0.date >= cutoff }
            .sorted { $0.date > $1.date }
            .prefix(maxEntries)
            .map { $0 }
    }

    /// Forgets one inbox: its receipts go unless another connected inbox also has them. Receipts saved
    /// before inboxes were tracked go with the last inbox.
    static func removeSource(_ accountID: String, remainingAccounts: Int) -> [ReceiptSignal] {
        let kept = load().compactMap { signal -> ReceiptSignal? in
            guard let sources = signal.sources else { return remainingAccounts > 0 ? signal : nil }
            let others = sources.filter { $0 != accountID }
            guard !others.isEmpty else { return nil }
            var updated = signal
            updated.sources = others
            return updated
        }
        save(kept)
        return kept
    }

    static func clear() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
