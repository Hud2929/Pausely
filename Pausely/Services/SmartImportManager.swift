import Foundation
import SwiftUI
import Combine

/// Revolutionary Smart Import System
/// Handles importing subscriptions from multiple sources with deduplication
@MainActor
final class SmartImportManager: ObservableObject {
    static let shared = SmartImportManager()
    
    // MARK: - Published State
    @Published var isProcessing = false
    @Published var importProgress: Double = 0
    @Published var importPhase: String = ""
    @Published var importedCount = 0
    @Published var duplicatesFound = 0
    @Published var lastImportResults: ImportResults?
    
    // MARK: - Caching for Performance
    private let cacheKey = "smartImportCache"
    private let resultsKey = "lastImportResults"
    private var processingTask: Task<Void, Never>?
    
    struct ImportResults: Codable {
        let date: Date
        let imported: Int
        let duplicates: Int
        let failed: Int
        let totalValue: Decimal
        let sources: [String]
    }
    
    struct ImportSource: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let description: String
        let handler: () async -> ImportResult
    }
    
    struct ImportResult {
        let subscriptions: [ImportSubscription]
        let errors: [String]
    }
    
    struct ImportSubscription: Identifiable {
        let id = UUID()
        let name: String
        let amount: Decimal
        let currency: String
        let billingFrequency: BillingFrequency
        let confidence: Confidence
        let source: String
        
        enum Confidence: String, Codable {
            case high = "High"
            case medium = "Medium"
            case low = "Low"
        }
    }
    
    private init() {
        loadCachedResults()
    }
    
    // MARK: - Public Methods
    
    func importFromEmail() async -> ImportResult {
        do {
            return try await simulateImportProcess(source: "Email Receipts")
        } catch {
            return ImportResult(subscriptions: [], errors: [error.localizedDescription])
        }
    }
    
    func importFromBankCSV(csvData: String) async -> ImportResult {
        await parseBankCSV(csvData)
    }
    
    func importFromManualEntry(subscriptions: [ImportSubscription]) async -> ImportResult {
        ImportResult(subscriptions: subscriptions, errors: [])
    }
    
    func processImports(from results: [ImportResult]) async {
        guard !isProcessing else { return }
        
        processingTask?.cancel()
        processingTask = Task { [weak self] in
            guard let self = self else { return }
            
            await MainActor.run {
                self.isProcessing = true
                self.importProgress = 0
                self.importedCount = 0
                self.duplicatesFound = 0
            }
            
            let allSubscriptions = results.flatMap { $0.subscriptions }
            let totalCount = allSubscriptions.count
            
            var imported = 0
            var duplicates = 0
            var failed = 0
            var totalValue: Decimal = 0
            
            // Batch processing for memory efficiency
            let batchSize = 50
            let batches = stride(from: 0, to: totalCount, by: batchSize).map {
                Array(allSubscriptions[$0..<min($0 + batchSize, totalCount)])
            }
            
            let store = SubscriptionStore.shared
            let existingNames = Set(store.subscriptions.map { $0.name.lowercased() })
            
            for (batchIndex, batch) in batches.enumerated() {
                if Task.isCancelled { break }
                
                await MainActor.run {
                    self.importPhase = "Processing batch \(batchIndex + 1) of \(batches.count)..."
                }
                
                for sub in batch {
                    // Deduplication check
                    if existingNames.contains(sub.name.lowercased()) {
                        duplicates += 1
                        continue
                    }
                    
                    let newSub = Subscription(
                        name: sub.name,
                        category: "Other",
                        amount: sub.amount,
                        currency: sub.currency,
                        billingFrequency: sub.billingFrequency
                    )
                    
                    do {
                        _ = try await store.addSubscription(newSub)
                        imported += 1
                        totalValue += sub.amount
                    } catch {
                        failed += 1
                    }
                }
                
                await MainActor.run {
                    self.importedCount = imported
                    self.duplicatesFound = duplicates
                    self.importProgress = Double(batchIndex + 1) / Double(batches.count)
                }
                
                // Memory management: small delay between batches
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            
            let results = ImportResults(
                date: Date(),
                imported: imported,
                duplicates: duplicates,
                failed: failed,
                totalValue: totalValue,
                sources: results.map { _ in "Import" }
            )
            
            await MainActor.run {
                self.lastImportResults = results
                self.isProcessing = false
                self.cacheResults(results)
            }
        }
        
        await processingTask?.value
    }
    
    func cancelImport() {
        processingTask?.cancel()
        isProcessing = false
    }
    
    // MARK: - Private Methods
    
    private func simulateImportProcess(source: String) async throws -> ImportResult {
        // Email import requires EventKit permissions and Apple Mail integration
        // This feature is not yet implemented - throw not implemented error
        throw ImportError.notImplemented
    }

    enum ImportError: LocalizedError {
        case notImplemented
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .notImplemented:
                return "Email import is not yet available. Use CSV import or Manual Bulk Add instead."
            case .permissionDenied:
                return "Email access was denied. Please enable email access in Settings."
            }
        }
    }
    
    private func parseBankCSV(_ csvData: String) async -> ImportResult {
        var subscriptions: [ImportSubscription] = []
        var errors: [String] = []

        let lines = csvData.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return ImportResult(subscriptions: [], errors: ["CSV file is empty"])
        }

        // Parse header to detect column mapping
        let headerColumns = parseCSVLine(lines[0]).map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        let columnMap = detectColumnMapping(headers: headerColumns)

        guard columnMap[.name] != nil, columnMap[.price] != nil else {
            return ImportResult(subscriptions: [], errors: ["CSV must have 'name' and 'price' columns. Supported headers: name, price, category, frequency, next_billing_date"])
        }

        for (index, line) in lines.enumerated().dropFirst() {
            let columns = parseCSVLine(line)
            guard columns.count >= headerColumns.count else {
                errors.append("Row \(index): too few columns")
                continue
            }

            let name = columnMap[.name].flatMap { idx in columns[safe: idx]?.trimmingCharacters(in: .whitespaces) } ?? ""
            let priceStr = columnMap[.price].flatMap { idx in columns[safe: idx]?.trimmingCharacters(in: .whitespaces) } ?? ""
            let category = columnMap[.category].flatMap { idx in columns[safe: idx]?.trimmingCharacters(in: .whitespaces) } ?? "Other"
            let frequencyStr = columnMap[.frequency].flatMap { idx in columns[safe: idx]?.trimmingCharacters(in: .whitespaces) } ?? "monthly"
            let nextBillingStr = columnMap[.nextBilling].flatMap { idx in columns[safe: idx]?.trimmingCharacters(in: .whitespaces) }

            guard !name.isEmpty else {
                errors.append("Row \(index): name is required")
                continue
            }

            let cleanedPrice = priceStr.replacingOccurrences(of: "[$,£€]", with: "", options: .regularExpression)
            guard let amount = Decimal(string: cleanedPrice), amount > 0 else {
                errors.append("Row \(index): invalid price '\(priceStr)'")
                continue
            }

            let billingFrequency = parseBillingFrequency(frequencyStr)

            let sub = ImportSubscription(
                name: name,
                amount: amount,
                currency: "USD",
                billingFrequency: billingFrequency,
                confidence: .high,
                source: "CSV"
            )
            subscriptions.append(sub)
        }

        return ImportResult(subscriptions: subscriptions, errors: errors)
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var insideQuotes = false

        for char in line {
            switch char {
            case "\"":
                insideQuotes.toggle()
            case ",":
                if insideQuotes {
                    current.append(char)
                } else {
                    result.append(current.trimmingCharacters(in: .whitespaces))
                    current = ""
                }
            default:
                current.append(char)
            }
        }
        result.append(current.trimmingCharacters(in: .whitespaces))
        return result
    }

    private enum CSVColumn: String, CaseIterable {
        case name
        case price
        case category
        case frequency
        case nextBilling = "next_billing_date"
    }

    private func detectColumnMapping(headers: [String]) -> [CSVColumn: Int] {
        var mapping: [CSVColumn: Int] = [:]
        for (index, header) in headers.enumerated() {
            let lower = header.lowercased()
            if lower.contains("name") || lower.contains("title") || lower.contains("description") {
                mapping[.name] = index
            } else if lower.contains("price") || lower.contains("amount") || lower.contains("cost") {
                mapping[.price] = index
            } else if lower.contains("category") || lower.contains("type") {
                mapping[.category] = index
            } else if lower.contains("freq") || lower.contains("period") || lower.contains("interval") {
                mapping[.frequency] = index
            } else if lower.contains("billing") || lower.contains("renewal") || lower.contains("next") {
                mapping[.nextBilling] = index
            }
        }
        return mapping
    }

    private func parseBillingFrequency(_ raw: String) -> BillingFrequency {
        let lower = raw.lowercased()
        if lower.contains("week") { return .weekly }
        if lower.contains("bi") && lower.contains("week") { return .biweekly }
        if lower.contains("month") { return .monthly }
        if lower.contains("quarter") { return .quarterly }
        if lower.contains("semi") || lower.contains("6 month") { return .semiannual }
        if lower.contains("year") || lower.contains("annual") { return .yearly }
        return .monthly
    }
    
    private func cacheResults(_ results: ImportResults) {
        if let encoded = try? JSONEncoder().encode(results) {
            UserDefaults.standard.set(encoded, forKey: resultsKey)
        }
    }
    
    private func loadCachedResults() {
        guard let data = UserDefaults.standard.data(forKey: resultsKey),
              let decoded = try? JSONDecoder().decode(ImportResults.self, from: data) else {
            return
        }
        lastImportResults = decoded
    }
}

// MARK: - Memory-Efficient Batch Processor
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Memory-Efficient Batch Processor
final class BatchProcessor<T> {
    private let batchSize: Int
    private let processDelay: UInt64
    
    init(batchSize: Int = 100, processDelayMs: Int = 10) {
        self.batchSize = batchSize
        self.processDelay = UInt64(processDelayMs) * 1_000_000
    }
    
    func process(items: [T], operation: (T) async throws -> Void) async throws {
        let batches = stride(from: 0, to: items.count, by: batchSize).map {
            Array(items[$0..<min($0 + batchSize, items.count)])
        }
        
        for batch in batches {
            for item in batch {
                try await operation(item)
            }
            // Prevent memory spikes
            try await Task.sleep(nanoseconds: processDelay)
        }
    }
}
