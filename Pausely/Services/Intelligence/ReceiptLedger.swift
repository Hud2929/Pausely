import Foundation

/// On-device history of per-email *facts* (merchant, amount, date, flags). Never email text.
/// It lets incremental scans re-analyze the full history, which is what makes recurrence detection possible.
/// Stored locally with file protection; wiped when Gmail is disconnected.
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

    /// Idempotent merge: dedupes by message id, drops very old facts, caps the size.
    static func merge(_ new: [ReceiptSignal], into existing: [ReceiptSignal], now: Date = Date()) -> [ReceiptSignal] {
        var byId: [String: ReceiptSignal] = [:]
        for signal in existing { byId[signal.id] = signal }
        for signal in new { byId[signal.id] = signal }
        let cutoff = now.addingTimeInterval(-retention)
        return byId.values
            .filter { $0.date >= cutoff }
            .sorted { $0.date > $1.date }
            .prefix(maxEntries)
            .map { $0 }
    }

    static func clear() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
