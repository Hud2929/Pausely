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

    /// What reading the file gave. "Couldn't read it" is not "there is nothing": the file is readable
    /// only while the iPhone is unlocked, and a scan can still be running when it locks.
    enum Stored: Equatable {
        case facts([ReceiptSignal])
        case nothingYet
        case unreadable
    }

    static func read(from url: URL? = fileURL) -> Stored {
        guard let url else { return .unreadable }
        guard FileManager.default.fileExists(atPath: url.path) else { return .nothingYet }
        guard let data = try? Data(contentsOf: url) else { return .unreadable }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        // A file this version can't decode holds nothing it can use; the next scan rebuilds it.
        guard let facts = try? decoder.decode([ReceiptSignal].self, from: data) else { return .nothingYet }
        return .facts(facts)
    }

    /// Everything known, for showing and analysing. Empty when nothing is saved or it can't be read now.
    static func load(from url: URL? = fileURL) -> [ReceiptSignal] {
        if case .facts(let facts) = read(from: url) { return facts }
        return []
    }

    static func save(_ signals: [ReceiptSignal], to url: URL? = fileURL) {
        guard let url else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(signals) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try? mutableURL.setResourceValues(values)
    }

    /// Adds newly found facts to what is saved and returns everything known. While the saved facts
    /// can't be read, nothing is written: saving then would replace up to three years of history with
    /// the few facts of this scan. They are returned on their own for this scan, and the next scan
    /// finds them again, because reading mail never uses it up.
    static func add(_ new: [ReceiptSignal], to url: URL? = fileURL, now: Date = Date()) -> [ReceiptSignal] {
        switch read(from: url) {
        case .unreadable:
            return merge(new, into: [], now: now)
        case .nothingYet:
            let all = merge(new, into: [], now: now)
            save(all, to: url)
            return all
        case .facts(let existing):
            let all = merge(new, into: existing, now: now)
            save(all, to: url)
            return all
        }
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
        // Facts that can't be read right now are left alone rather than replaced by an empty file.
        guard case .facts(let saved) = read() else { return [] }
        let kept = saved.compactMap { signal -> ReceiptSignal? in
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
