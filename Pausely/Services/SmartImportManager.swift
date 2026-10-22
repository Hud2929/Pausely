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
        let nextBillingDate: Date?
        let confidence: Confidence
        let source: String
        /// Evidence, score, lifecycle status and reasons from the intelligence engine (Gmail scans).
        var proven: ProvenSubscription? = nil
        
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
                        billingFrequency: sub.billingFrequency,
                        nextBillingDate: sub.nextBillingDate
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
    
    
    // MARK: - Private Methods
    

    


    
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


extension Collection {
}
