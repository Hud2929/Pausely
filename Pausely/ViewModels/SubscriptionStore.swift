import Foundation
import Auth
import PostgREST
import os.log

@MainActor
class SubscriptionStore: ObservableObject {
    @Published var subscriptions: [Subscription] = []
    @Published var totalMonthlySpend: Decimal = 0
    @Published var totalAnnualSpend: Decimal = 0
    @Published var isLoading = false
    @Published var error: Error?
    @Published var lastFetchDate: Date?
    @Published var isUsingLocalStorage = false
    
    static let shared = SubscriptionStore()
    
    private let client = SupabaseManager.shared.client
    private var fetchTask: Task<Void, Never>?
    private let localStorageKey = "local_subscriptions"
    private let useLocalStorageKey = "use_local_storage_fallback"
    
    // MARK: - Performance Optimizations for Scale
    private var backgroundQueue = DispatchQueue(label: "com.pausely.store", qos: .userInitiated)
    private var calculationTask: Task<Void, Never>?
    private var lastCalculationHash: Int?
    private var cachedSubscriptions: [Subscription]?
    private var cacheTimestamp: Date?
    
    private init() {
        // Check if user previously chose local storage
        isUsingLocalStorage = UserDefaults.standard.bool(forKey: useLocalStorageKey)
        
        if isUsingLocalStorage {
            loadFromLocalStorage()
        } else {
            loadFromCache()
        }
    }
    
    // MARK: - Storage Mode
    
    func enableLocalStorage() {
        isUsingLocalStorage = true
        UserDefaults.standard.set(true, forKey: useLocalStorageKey)
        loadFromLocalStorage()
    }
    
    func disableLocalStorage() {
        isUsingLocalStorage = false
        UserDefaults.standard.set(false, forKey: useLocalStorageKey)
        Task {
            await fetchSubscriptions(force: true)
        }
    }
    
    // MARK: - Data Fetching
    
    func fetchSubscriptions(force: Bool = false) async {
        // If using local storage, skip Supabase
        if isUsingLocalStorage {
            loadFromLocalStorage()
            return
        }
        
        fetchTask?.cancel()
        
        if !force, let lastFetch = lastFetchDate,
           Date().timeIntervalSince(lastFetch) < 60 {
            return
        }
        
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }
        
        do {
            guard let session = client.auth.currentSession else {
                throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
            }
            let userId = session.user.id

            let response: [SubscriptionRecord] = try await client
                .from("subscriptions")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            let fetchedSubscriptions = response.map { $0.toSubscription() }
            
            await MainActor.run {
                self.subscriptions = fetchedSubscriptions
                self.calculateTotals()
                self.lastFetchDate = Date()
                self.error = nil
                self.saveToCache()
            }
            
        } catch {
            print("Error fetching subscriptions: \(error)")
            await MainActor.run {
                self.error = error
                // Try to load from cache if available
                if self.subscriptions.isEmpty {
                    self.loadFromCache()
                }
            }
        }
    }
    
    func refresh() async {
        await fetchSubscriptions(force: true)
    }
    
    // MARK: - CRUD Operations
    
    enum SubscriptionLimitError: Error, LocalizedError {
        case freeTierLimitReached
        
        var errorDescription: String? {
            switch self {
            case .freeTierLimitReached:
                return "You've reached the free tier limit of 2 subscriptions. Upgrade to Pro for unlimited subscriptions."
            }
        }
    }
    
    enum DatabaseError: Error, LocalizedError {
        case tableNotFound
        case notAuthenticated
        case networkError
        case offlineMode
        case unknown(Error)
        
        var errorDescription: String? {
            switch self {
            case .tableNotFound:
                return "Database Connection Issue"
            case .notAuthenticated:
                return "Please sign in to save subscriptions."
            case .networkError:
                return "Network error. Please check your connection and try again."
            case .offlineMode:
                return "Working in offline mode"
            case .unknown(let error):
                return error.localizedDescription
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .tableNotFound:
                return "You can continue using the app with local storage, or try connecting to the cloud later."
            case .notAuthenticated:
                return "Sign in to your account to continue."
            case .networkError:
                return "Check your internet connection and try again."
            case .offlineMode:
                return "Your subscriptions are saved locally. Tap 'Enable Cloud Sync' to sync when ready."
            case .unknown:
                return "Please try again or contact support if the problem persists."
            }
        }
        
        var detailedMessage: String {
            switch self {
            case .tableNotFound:
                return """
                Database Connection Issue
                
                We're having trouble connecting to the cloud database. This can happen when:
                • The database is being set up
                • There are temporary connection issues
                • Your account needs verification
                
                You have two options:
                
                1️⃣ CONTINUE OFFLINE
                Use local storage - your subscriptions will be saved on this device
                
                2️⃣ TRY AGAIN
                Attempt to connect to the cloud again
                """
            case .notAuthenticated:
                return "Please sign in to add subscriptions."
            case .networkError:
                return "Network error. Please check your internet connection and try again."
            case .offlineMode:
                return "Working in offline mode. Your subscriptions are saved locally."
            case .unknown(let error):
                return "An error occurred: \(error.localizedDescription)"
            }
        }
        
        var isTableNotFound: Bool {
            if case .tableNotFound = self { return true }
            return false
        }
        
        static func from(_ error: Error) -> DatabaseError {
            let errorString = String(describing: error).lowercased()
            let localizedError = error.localizedDescription.lowercased()
            
            // Check for table not found
            let tableNotFoundPatterns = [
                "could not find the table",
                "does not exist",
                "42p01",
                "relation",
                "schema cache",
                "postgrest error"
            ]
            
            for pattern in tableNotFoundPatterns {
                if errorString.contains(pattern) || localizedError.contains(pattern) {
                    return .tableNotFound
                }
            }
            
            // Check for network errors
            let networkPatterns = ["network", "connection", "offline", "timeout", "host", "dns"]
            for pattern in networkPatterns {
                if errorString.contains(pattern) || localizedError.contains(pattern) {
                    return .networkError
                }
            }
            
            // Check for auth errors
            let authPatterns = ["jwt", "not authenticated", "unauthorized", "auth"]
            for pattern in authPatterns {
                if errorString.contains(pattern) || localizedError.contains(pattern) {
                    return .notAuthenticated
                }
            }
            
            return .unknown(error)
        }
    }
    
    /// Adds a subscription. Returns `true` if fell back to local storage, `false` if saved to cloud.
    @discardableResult
    func addSubscription(_ subscription: Subscription) async throws -> Bool {
        // Check subscription limit
        let paymentManager = PaymentManager.shared
        if paymentManager.hasReachedSubscriptionLimit(currentCount: subscriptions.count) {
            throw SubscriptionLimitError.freeTierLimitReached
        }
        
        // If using local storage, save locally
        if isUsingLocalStorage {
            var localSub = subscription
            localSub.id = UUID()
            await MainActor.run {
                self.subscriptions.insert(localSub, at: 0)
                self.calculateTotals()
                self.saveToLocalStorage()
            }
            return false
        }
        
        do {
            guard let session = client.auth.currentSession else {
                throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
            }
            let user = session.user
            var record = SubscriptionRecord(from: subscription)
            record.user_id = user.id
            
            let inserted: [SubscriptionRecord] = try await client
                .from("subscriptions")
                .insert(record)
                .select()
                .execute()
                .value
            
            if let newRecord = inserted.first {
                await MainActor.run {
                    self.subscriptions.insert(newRecord.toSubscription(), at: 0)
                    self.calculateTotals()
                    self.saveToCache()
                }
                // Trigger review prompt after adding first subscription
                if self.subscriptions.count == 1 {
                    ReviewPromptManager.shared.requestReviewIfAppropriate(after: .firstSubscriptionAdded)
                }
            }
            return false
        } catch {
            print("Error adding subscription: \(error)")
            let dbError = DatabaseError.from(error)
            
            // Automatically fall back to local storage for table/connection errors
            switch dbError {
            case .tableNotFound, .networkError, .notAuthenticated, .unknown:
                print("Falling back to local storage due to: \(dbError)")
                await MainActor.run {
                    self.enableLocalStorage()
                }
                // Retry with local storage
                var localSub = subscription
                localSub.id = UUID()
                await MainActor.run {
                    self.subscriptions.insert(localSub, at: 0)
                    self.calculateTotals()
                    self.saveToLocalStorage()
                }
                // Trigger review prompt after adding first subscription (local fallback)
                if self.subscriptions.count == 1 {
                    ReviewPromptManager.shared.requestReviewIfAppropriate(after: .firstSubscriptionAdded)
                }
                return true
            case .offlineMode:
                // Already in offline mode, shouldn't reach here
                throw dbError
            }
        }
    }
    
    func updateSubscription(_ subscription: Subscription) async throws {
        // If using local storage, update locally
        if isUsingLocalStorage {
            await MainActor.run {
                if let index = self.subscriptions.firstIndex(where: { $0.id == subscription.id }) {
                    self.subscriptions[index] = subscription
                    self.calculateTotals()
                    self.saveToLocalStorage()
                }
            }
            return
        }
        
        do {
            let record = SubscriptionRecord(from: subscription)
            
            let updated: [SubscriptionRecord] = try await client
                .from("subscriptions")
                .update(record)
                .eq("id", value: subscription.id)
                .select()
                .execute()
                .value
            
            if let updatedRecord = updated.first {
                await MainActor.run {
                    if let index = self.subscriptions.firstIndex(where: { $0.id == subscription.id }) {
                        self.subscriptions[index] = updatedRecord.toSubscription()
                        self.calculateTotals()
                        self.saveToCache()
                    }
                }
            }
        } catch {
            print("Error updating subscription: \(error)")
            let dbError = DatabaseError.from(error)
            
            // Automatically fall back to local storage for table/connection errors
            switch dbError {
            case .tableNotFound, .networkError, .notAuthenticated, .unknown:
                print("Falling back to local storage due to: \(dbError)")
                await MainActor.run {
                    self.enableLocalStorage()
                }
                // Retry with local storage
                await MainActor.run {
                    if let index = self.subscriptions.firstIndex(where: { $0.id == subscription.id }) {
                        self.subscriptions[index] = subscription
                        self.calculateTotals()
                        self.saveToLocalStorage()
                    }
                }
            case .offlineMode:
                throw dbError
            }
        }
    }

    // MARK: - Savings Tracking for Review Prompts

    /// Tracks potential savings from cancelled/paused subscriptions for review milestone prompts
    private var totalSavingsTracked: Decimal {
        // Calculate savings from paused or cancelled subscriptions
        // This is a simplified heuristic: sum of monthly costs of non-active subscriptions
        let saved = subscriptions
            .filter { $0.status != .active }
            .reduce(Decimal(0)) { total, sub in
                total + monthlyEquivalent(for: sub)
            }
        return saved
    }

    func checkSavingsMilestone() {
        let savings = totalSavingsTracked
        guard savings >= 50 else { return }
        ReviewPromptManager.shared.requestReviewIfAppropriate(after: .savingsMilestone(amount: savings))
    }

    func deleteSubscription(id: UUID) async throws {
        // If using local storage, delete locally
        if isUsingLocalStorage {
            await MainActor.run {
                self.subscriptions.removeAll { $0.id == id }
                self.calculateTotals()
                self.saveToLocalStorage()
            }
            return
        }
        
        do {
            try await client
                .from("subscriptions")
                .delete()
                .eq("id", value: id)
                .execute()
            
            await MainActor.run {
                self.subscriptions.removeAll { $0.id == id }
                self.calculateTotals()
                self.saveToCache()
            }
        } catch {
            print("Error deleting subscription: \(error)")
            let dbError = DatabaseError.from(error)
            
            // Automatically fall back to local storage for table/connection errors
            switch dbError {
            case .tableNotFound, .networkError, .notAuthenticated, .unknown:
                print("Falling back to local storage due to: \(dbError)")
                await MainActor.run {
                    self.enableLocalStorage()
                }
                // Retry with local storage
                await MainActor.run {
                    self.subscriptions.removeAll { $0.id == id }
                    self.calculateTotals()
                    self.saveToLocalStorage()
                }
            case .offlineMode:
                throw dbError
            }
        }
    }
    
    func updateSubscriptionStatus(id: UUID, status: SubscriptionStatus) async throws {
        if isUsingLocalStorage {
            await MainActor.run {
                if let index = self.subscriptions.firstIndex(where: { $0.id == id }) {
                    self.subscriptions[index].status = status
                    self.calculateTotals()
                    self.saveToLocalStorage()
                }
            }
            return
        }
        
        do {
            try await client
                .from("subscriptions")
                .update(["status": status.rawValue])
                .eq("id", value: id)
                .execute()
            
            await MainActor.run {
                if let index = self.subscriptions.firstIndex(where: { $0.id == id }) {
                    self.subscriptions[index].status = status
                    self.calculateTotals()
                    self.saveToCache()
                }
            }
            // Check for savings milestone after status change (e.g., pause/cancel)
            if status != .active {
                checkSavingsMilestone()
            }
        } catch {
            let dbError = DatabaseError.from(error)
            
            // Automatically fall back to local storage for table/connection errors
            switch dbError {
            case .tableNotFound, .networkError, .notAuthenticated, .unknown:
                print("Falling back to local storage due to: \(dbError)")
                await MainActor.run {
                    self.enableLocalStorage()
                }
                // Retry with local storage
                await MainActor.run {
                    if let index = self.subscriptions.firstIndex(where: { $0.id == id }) {
                        self.subscriptions[index].status = status
                        self.calculateTotals()
                        self.saveToLocalStorage()
                    }
                }
                // Check for savings milestone after status change (e.g., pause/cancel)
                if status != .active {
                    checkSavingsMilestone()
                }
            case .offlineMode:
                throw dbError
            }
        }
    }
    
    func pauseSubscription(id: UUID, until date: Date) async throws {
        if isUsingLocalStorage {
            await MainActor.run {
                if let index = self.subscriptions.firstIndex(where: { $0.id == id }) {
                    self.subscriptions[index].status = .paused
                    self.subscriptions[index].pausedUntil = date
                    self.calculateTotals()
                    self.saveToLocalStorage()
                }
            }
            return
        }
        
        do {
            let dateFormatter = ISO8601DateFormatter()
            try await client
                .from("subscriptions")
                .update([
                    "status": SubscriptionStatus.paused.rawValue,
                    "paused_until": dateFormatter.string(from: date)
                ])
                .eq("id", value: id)
                .execute()
            
            await MainActor.run {
                if let index = self.subscriptions.firstIndex(where: { $0.id == id }) {
                    self.subscriptions[index].status = .paused
                    self.subscriptions[index].pausedUntil = date
                    self.calculateTotals()
                    self.saveToCache()
                }
            }
        } catch {
            let dbError = DatabaseError.from(error)
            
            // Automatically fall back to local storage for table/connection errors
            switch dbError {
            case .tableNotFound, .networkError, .notAuthenticated, .unknown:
                print("Falling back to local storage due to: \(dbError)")
                await MainActor.run {
                    self.enableLocalStorage()
                }
                // Retry with local storage
                await MainActor.run {
                    if let index = self.subscriptions.firstIndex(where: { $0.id == id }) {
                        self.subscriptions[index].status = .paused
                        self.subscriptions[index].pausedUntil = date
                        self.calculateTotals()
                        self.saveToLocalStorage()
                    }
                }
            case .offlineMode:
                throw dbError
            }
        }
    }
    
    func resumeSubscription(id: UUID) async throws {
        try await updateSubscriptionStatus(id: id, status: .active)
    }
    
    // MARK: - Caching
    
    private func saveToCache() {
        do {
            let data = try JSONEncoder().encode(subscriptions)
            UserDefaults.standard.set(data, forKey: "cached_subscriptions")
            UserDefaults.standard.set(Date(), forKey: "subscriptions_cache_date")
        } catch {
            os_log("Cache save failed: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }
    
    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: "cached_subscriptions") else { return }
        
        do {
            let cached = try JSONDecoder().decode([Subscription].self, from: data)
            Task { @MainActor in
                self.subscriptions = cached
                self.calculateTotals()
            }
        } catch {
            os_log("Cache load failed: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }
    
    // MARK: - Local Storage (Offline Mode)
    
    private func saveToLocalStorage() {
        do {
            let data = try JSONEncoder().encode(subscriptions)
            UserDefaults.standard.set(data, forKey: localStorageKey)
            print("Saved \(subscriptions.count) subscriptions to local storage")
        } catch {
            os_log("Local storage save failed: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }
    
    private func loadFromLocalStorage() {
        guard let data = UserDefaults.standard.data(forKey: localStorageKey) else {
            print("No local subscriptions found")
            return
        }
        
        do {
            let localSubs = try JSONDecoder().decode([Subscription].self, from: data)
            Task { @MainActor in
                self.subscriptions = localSubs
                self.calculateTotals()
                print("Loaded \(localSubs.count) subscriptions from local storage")
            }
        } catch {
            os_log("Local storage load failed: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }
    
    /// Sync local subscriptions to cloud when connection is restored
    /// Optimized with batch processing for thousands of subscriptions
    func syncToCloud() async -> (success: Int, failed: Int) {
        guard !isUsingLocalStorage else { return (0, 0) }
        
        var successCount = 0
        var failedCount = 0
        
        // Get local-only subscriptions (those not synced)
        let localOnly = subscriptions.filter { sub in
            // In a real implementation, you'd track sync status
            true
        }
        
        // Batch processing for scale - process 10 at a time
        let batchSize = 10
        let batches = stride(from: 0, to: localOnly.count, by: batchSize).map {
            Array(localOnly[$0..<min($0 + batchSize, localOnly.count)])
        }
        
        for batch in batches {
            await withTaskGroup(of: Bool.self) { group in
                for subscription in batch {
                    group.addTask {
                        do {
                            try await self.addSubscription(subscription)
                            return true
                        } catch {
                            return false
                        }
                    }
                }
                
                for await success in group {
                    if success {
                        successCount += 1
                    } else {
                        failedCount += 1
                    }
                }
            }
            
            // Small delay between batches to prevent rate limiting
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        return (successCount, failedCount)
    }
    
    // MARK: - Batch Operations for Scale
    
    /// Efficiently add multiple subscriptions in batch
    func batchAddSubscriptions(_ newSubscriptions: [Subscription]) async -> (added: Int, failed: Int) {
        var added = 0
        var failed = 0
        
        // Deduplication check
        let existingNames = Set(subscriptions.map { $0.name.lowercased() })
        let uniqueSubs = newSubscriptions.filter { !existingNames.contains($0.name.lowercased()) }
        
        // Process in batches of 5 for memory efficiency
        let batchSize = 5
        let batches = stride(from: 0, to: uniqueSubs.count, by: batchSize).map {
            Array(uniqueSubs[$0..<min($0 + batchSize, uniqueSubs.count)])
        }
        
        for batch in batches {
            await withTaskGroup(of: Bool.self) { group in
                for sub in batch {
                    group.addTask {
                        do {
                            _ = try await self.addSubscription(sub)
                            return true
                        } catch {
                            return false
                        }
                    }
                }
                
                for await success in group {
                    if success {
                        added += 1
                    } else {
                        failed += 1
                    }
                }
            }
        }
        
        return (added, failed)
    }
    
    /// Memory-efficient filtering for large subscription lists
    func filteredSubscriptions(
        matching predicate: (Subscription) -> Bool,
        limit: Int? = nil
    ) -> [Subscription] {
        var result: [Subscription] = []
        result.reserveCapacity(limit ?? subscriptions.count / 2)
        
        for sub in subscriptions {
            if predicate(sub) {
                result.append(sub)
                if let limit = limit, result.count >= limit {
                    break
                }
            }
        }
        
        return result
    }
    
    // MARK: - Optimized Calculation (Async for Large Datasets)
    
    private func calculateTotals() {
        // Cancel previous calculation to prevent UI lag
        calculationTask?.cancel()
        
        let currentSubscriptions = subscriptions
        // Simple hash based on count and total amount for change detection
        let currentHash = currentSubscriptions.count &+ Int(truncating: totalMonthlySpend as NSNumber)
        
        // Skip if data hasn't changed
        if lastCalculationHash == currentHash { return }
        lastCalculationHash = currentHash
        
        // For small datasets, calculate immediately
        if currentSubscriptions.count < 100 {
            performCalculation(activeSubscriptions: currentSubscriptions.filter { $0.status == .active })
            return
        }
        
        // For large datasets, calculate in background
        calculationTask = Task { [weak self] in
            guard let self = self else { return }
            
            let active = currentSubscriptions.filter { $0.status == .active }
            
            // Process in chunks to prevent blocking
            let chunkSize = 50
            let chunks = stride(from: 0, to: active.count, by: chunkSize).map {
                Array(active[$0..<min($0 + chunkSize, active.count)])
            }
            
            var monthlyTotal: Decimal = 0
            
            for chunk in chunks {
                if Task.isCancelled { return }
                
                let chunkTotal = chunk.reduce(Decimal(0)) { total, sub in
                    total + self.monthlyEquivalent(for: sub)
                }
                monthlyTotal += chunkTotal
                
                // Yield to prevent blocking
                try? await Task.sleep(nanoseconds: 1_000)
            }
            
            await MainActor.run {
                self.totalMonthlySpend = monthlyTotal
                self.totalAnnualSpend = monthlyTotal * 12
            }
        }
    }
    
    private func monthlyEquivalent(for sub: Subscription) -> Decimal {
        guard sub.status == .active else { return 0 }
        
        switch sub.billingFrequency {
        case .monthly:
            return sub.amount
        case .yearly:
            return sub.amount / 12
        case .weekly:
            return sub.amount * Decimal(52) / 12
        case .biweekly:
            return sub.amount * Decimal(26) / 12
        case .quarterly:
            return sub.amount / 3
        case .semiannual:
            return sub.amount / 6
        }
    }
    
    private func performCalculation(activeSubscriptions: [Subscription]) {
        var monthlyTotal: Decimal = 0
        for sub in activeSubscriptions {
            monthlyTotal += monthlyEquivalent(for: sub)
        }
        totalMonthlySpend = monthlyTotal
        totalAnnualSpend = monthlyTotal * 12
    }
    
    // MARK: - Computed Properties
    
    var activeSubscriptions: [Subscription] {
        subscriptions.filter { $0.status == .active }
    }
    
    var pausedSubscriptions: [Subscription] {
        subscriptions.filter { $0.status == .paused }
    }
    
    var pausableSubscriptions: [Subscription] {
        subscriptions.filter { $0.canPause && $0.status == .active }
    }
    
    var upcomingRenewals: [Subscription] {
        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysFromNow = calendar.date(byAdding: .day, value: 30, to: now) ?? now
        
        return activeSubscriptions
            .filter { sub in
                guard let nextBilling = sub.nextBillingDate else { return false }
                return nextBilling >= now && nextBilling <= thirtyDaysFromNow
            }
            .sorted { ($0.nextBillingDate ?? now) < ($1.nextBillingDate ?? now) }
    }
    
    func subscriptionsByCategory() -> [(category: String, subscriptions: [Subscription], total: Decimal)] {
        let grouped = Dictionary(grouping: activeSubscriptions) { $0.category ?? "Other" }
        return grouped.map { (category: $0.key, subscriptions: $0.value, total: calculateCategoryTotal($0.value)) }
            .sorted { $0.total > $1.total }
    }
    
    private func calculateCategoryTotal(_ subscriptions: [Subscription]) -> Decimal {
        var total: Decimal = 0
        for sub in subscriptions {
            let monthlyAmount: Decimal
            switch sub.billingFrequency {
            case .monthly:
                monthlyAmount = sub.amount
            case .yearly:
                monthlyAmount = sub.amount / 12
            case .weekly:
                monthlyAmount = sub.amount * Decimal(52) / 12
            case .biweekly:
                monthlyAmount = sub.amount * Decimal(26) / 12
            case .quarterly:
                monthlyAmount = sub.amount / 3
            case .semiannual:
                monthlyAmount = sub.amount / 6
            }
            total += monthlyAmount
        }
        return total
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let subscriptionAdded = Notification.Name("subscriptionAdded")
    static let subscriptionUpdated = Notification.Name("subscriptionUpdated")
    static let subscriptionDeleted = Notification.Name("subscriptionDeleted")
}
