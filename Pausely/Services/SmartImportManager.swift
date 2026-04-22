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
        let errors: [String] = []
        
        let lines = csvData.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            if index == 0 { continue } // Skip header
            
            let columns = line.components(separatedBy: ",")
            guard columns.count >= 3 else { continue }
            
            // Simple CSV parsing: Date, Description, Amount
            let description = columns[1].trimmingCharacters(in: .whitespaces)
            let amountString = columns[2].trimmingCharacters(in: .whitespaces)
            
            // Detect subscription keywords
            let subscriptionKeywords = ["netflix", "spotify", "apple", "google", "microsoft", 
                                       "adobe", "amazon prime", "disney", "hulu", "youtube"]
            
            let lowerDesc = description.lowercased()
            let isSubscription = subscriptionKeywords.contains { lowerDesc.contains($0) }
            
            if isSubscription, let amount = Decimal(string: amountString) {
                let sub = ImportSubscription(
                    name: description,
                    amount: abs(amount),
                    currency: "USD",
                    billingFrequency: .monthly,
                    confidence: .medium,
                    source: "Bank CSV"
                )
                subscriptions.append(sub)
            }
        }
        
        return ImportResult(subscriptions: subscriptions, errors: errors)
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
