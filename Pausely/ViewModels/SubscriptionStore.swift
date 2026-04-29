import Foundation
import Auth
import PostgREST
import os.log
import ActivityKit

@MainActor
class SubscriptionStore: ObservableObject {
    @Published var subscriptions: [Subscription] = []
    @Published var totalMonthlySpend: Decimal = 0
    @Published var totalAnnualSpend: Decimal = 0
    @Published var totalLifetimeSpend: Decimal = 0
    @Published var isLoading = false
    @Published var error: Error?
    @Published var lastFetchDate: Date?
    static let shared = SubscriptionStore()

    private let client = SupabaseManager.shared.client
    private var fetchTask: Task<Void, Never>?

    // MARK: - Performance Optimizations for Scale
    private var backgroundQueue = DispatchQueue(label: "com.pausely.store", qos: .userInitiated)
    private var calculationTask: Task<Void, Never>?
    private var lastCalculationHash: Int?
    private var cachedSubscriptions: [Subscription]?
    private var cacheTimestamp: Date?

    private init() {
        loadFromCache()
    }
    
    // MARK: - Data Fetching
    
    func fetchSubscriptions(force: Bool = false) async {
        fetchTask?.cancel()

        if !force, let lastFetch = lastFetchDate,
           Date().timeIntervalSince(lastFetch) < 60 {
            return
        }

        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        // Always load from local cache first for responsiveness
        if subscriptions.isEmpty {
            loadFromCache()
        }

        // Attempt to fetch from Supabase and process any pending sync operations
        do {
            guard let session = client.auth.currentSession else {
                throw DatabaseError.notAuthenticated
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
                WidgetDataStore.shared.publish(subscriptions: self.subscriptions)
                SpotlightManager.shared.index(subscriptions: self.subscriptions)
                self.startLiveActivityIfNeeded()
                PriceIncreaseMonitor.shared.checkForPriceChanges(subscriptions: self.subscriptions)
            }

            // Process pending sync operations after successful fetch
            await SyncQueue.shared.processQueue()

        } catch {
            os_log("Error fetching subscriptions: %{public}@", log: .default, type: .error, error.localizedDescription)
            await MainActor.run {
                self.error = DatabaseError.from(error)
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
    
    /// Adds a subscription. Always updates local state first, then attempts cloud sync.
    @discardableResult
    func addSubscription(_ subscription: Subscription) async throws -> Bool {
        let paymentManager = PaymentManager.shared
        if paymentManager.hasReachedSubscriptionLimit(currentCount: subscriptions.count) {
            throw SubscriptionLimitError.freeTierLimitReached
        }

        var localSub = subscription
        localSub.id = subscription.id ?? UUID()

        // 1. Update local state immediately (offline-first)
        await MainActor.run {
            self.subscriptions.insert(localSub, at: 0)
            self.calculateTotals()
            self.saveToCache()
            WidgetDataStore.shared.publish(subscriptions: self.subscriptions)
            SpotlightManager.shared.index(subscriptions: self.subscriptions)
            if self.subscriptions.count == 1 {
                ReviewPromptManager.shared.requestReviewIfAppropriate(after: .firstSubscriptionAdded)
            }
        }

        // 2. Attempt Supabase write
        do {
            guard let session = client.auth.currentSession else {
                throw DatabaseError.notAuthenticated
            }
            var record = SubscriptionRecord(from: localSub)
            record.user_id = session.user.id

            let inserted: [SubscriptionRecord] = try await client
                .from("subscriptions")
                .insert(record)
                .select()
                .execute()
                .value

            if let newRecord = inserted.first {
                await MainActor.run {
                    if let idx = self.subscriptions.firstIndex(where: { $0.id == localSub.id }) {
                        self.subscriptions[idx] = newRecord.toSubscription()
                        self.saveToCache()
                    }
                }
            }
            return false
        } catch {
            os_log("Error adding subscription to cloud: %{public}@", log: .default, type: .error, error.localizedDescription)
            // 3. Enqueue for retry
            if let payload = try? JSONEncoder().encode(SubscriptionRecord(from: localSub)) {
                let op = SyncOperation(type: .create, subscriptionId: localSub.id, payload: payload)
                SyncQueue.shared.enqueue(op)
            }
            return true
        }
    }
    
    func updateSubscription(_ subscription: Subscription) async throws {
        // 1. Update local state immediately (offline-first)
        await MainActor.run {
            if let index = self.subscriptions.firstIndex(where: { $0.id == subscription.id }) {
                self.subscriptions[index] = subscription
                self.calculateTotals()
                self.saveToCache()
                WidgetDataStore.shared.publish(subscriptions: self.subscriptions)
                SpotlightManager.shared.index(subscriptions: self.subscriptions)
                PriceHistoryTracker.shared.recordPriceIfChanged(subscription)
            }
        }

        // 2. Attempt Supabase write
        do {
            let record = SubscriptionRecord(from: subscription)
            _ = try await client
                .from("subscriptions")
                .update(record)
                .eq("id", value: subscription.id)
                .execute()
        } catch {
            os_log("Error updating subscription in cloud: %{public}@", log: .default, type: .error, error.localizedDescription)
            // 3. Enqueue for retry
            if let payload = try? JSONEncoder().encode(SubscriptionRecord(from: subscription)) {
                let op = SyncOperation(type: .update, subscriptionId: subscription.id, payload: payload)
                SyncQueue.shared.enqueue(op)
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
        // 1. Update local state immediately (offline-first)
        await MainActor.run {
            self.subscriptions.removeAll { $0.id == id }
            self.calculateTotals()
            self.saveToCache()
            WidgetDataStore.shared.publish(subscriptions: self.subscriptions)
            SpotlightManager.shared.index(subscriptions: self.subscriptions)
        }

        // 2. Attempt Supabase write
        do {
            try await client
                .from("subscriptions")
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            os_log("Error deleting subscription from cloud: %{public}@", log: .default, type: .error, error.localizedDescription)
            // 3. Enqueue for retry
            let op = SyncOperation(type: .delete, subscriptionId: id, payload: Data())
            SyncQueue.shared.enqueue(op)
        }
    }

    func updateSubscriptionStatus(id: UUID, status: SubscriptionStatus) async throws {
        // 1. Update local state immediately (offline-first)
        await MainActor.run {
            if let index = self.subscriptions.firstIndex(where: { $0.id == id }) {
                self.subscriptions[index].status = status
                self.calculateTotals()
                self.saveToCache()
                WidgetDataStore.shared.publish(subscriptions: self.subscriptions)
                SpotlightManager.shared.index(subscriptions: self.subscriptions)
            }
        }
        if status != .active {
            checkSavingsMilestone()
        }

        // 2. Attempt Supabase write
        do {
            try await client
                .from("subscriptions")
                .update(["status": status.rawValue])
                .eq("id", value: id)
                .execute()
        } catch {
            os_log("Error updating subscription status in cloud: %{public}@", log: .default, type: .error, error.localizedDescription)
            // 3. Enqueue for retry
            if let payload = try? JSONEncoder().encode(["status": status.rawValue]) {
                let op = SyncOperation(type: .updateStatus, subscriptionId: id, payload: payload)
                SyncQueue.shared.enqueue(op)
            }
        }
    }

    func pauseSubscription(id: UUID, until date: Date) async throws {
        // 1. Update local state immediately (offline-first)
        await MainActor.run {
            if let index = self.subscriptions.firstIndex(where: { $0.id == id }) {
                self.subscriptions[index].pausedUntil = date
                self.calculateTotals()
                self.saveToCache()
                WidgetDataStore.shared.publish(subscriptions: self.subscriptions)
                SpotlightManager.shared.index(subscriptions: self.subscriptions)
            }
        }

        // 2. Attempt Supabase write
        do {
            let dateFormatter = ISO8601DateFormatter()
            try await client
                .from("subscriptions")
                .update(["paused_until": dateFormatter.string(from: date)])
                .eq("id", value: id)
                .execute()
        } catch {
            os_log("Error pausing subscription in cloud: %{public}@", log: .default, type: .error, error.localizedDescription)
            // 3. Enqueue for retry
            let dateFormatter = ISO8601DateFormatter()
            if let payload = try? JSONEncoder().encode(["paused_until": dateFormatter.string(from: date)]) {
                let op = SyncOperation(type: .pause, subscriptionId: id, payload: payload)
                SyncQueue.shared.enqueue(op)
            }
        }
    }

    func resumeSubscription(id: UUID) async throws {
        // 1. Update local state immediately (offline-first)
        await MainActor.run {
            if let index = self.subscriptions.firstIndex(where: { $0.id == id }) {
                self.subscriptions[index].pausedUntil = nil
                self.calculateTotals()
                self.saveToCache()
                WidgetDataStore.shared.publish(subscriptions: self.subscriptions)
                SpotlightManager.shared.index(subscriptions: self.subscriptions)
            }
        }

        // 2. Attempt Supabase write
        do {
            struct ResumePayload: Encodable {
                let paused_until: String?
            }
            try await client
                .from("subscriptions")
                .update(ResumePayload(paused_until: nil))
                .eq("id", value: id)
                .execute()
        } catch {
            os_log("Error resuming subscription in cloud: %{public}@", log: .default, type: .error, error.localizedDescription)
            // 3. Enqueue for retry
            if let payload = try? JSONEncoder().encode(["paused_until": "null"]) {
                let op = SyncOperation(type: .resume, subscriptionId: id, payload: payload)
                SyncQueue.shared.enqueue(op)
            }
        }
    }
    
    // MARK: - Caching

    private func saveToCache() {
        do {
            let data = try JSONEncoder().encode(subscriptions)
            AppSettings.shared.cachedSubscriptions = data
            AppSettings.shared.subscriptionsCacheDate = Date()
        } catch {
            os_log("Cache save failed: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }

    private func loadFromCache() {
        let data = AppSettings.shared.cachedSubscriptions
        guard !data.isEmpty else { return }

        do {
            let cached = try JSONDecoder().decode([Subscription].self, from: data)
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.subscriptions = cached
                self.calculateTotals()
            }
        } catch {
            os_log("Cache load failed: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }

    /// Process any pending sync operations with the cloud
    func processPendingSync() async {
        await SyncQueue.shared.processQueue()
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
                    group.addTask { [weak self] in
                        guard let self = self else { return false }
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
            
            let lifetimeTotal = currentSubscriptions.reduce(0) { $0 + $1.lifetimeSpend }
            await MainActor.run {
                self.totalMonthlySpend = monthlyTotal
                self.totalAnnualSpend = monthlyTotal * 12
                self.totalLifetimeSpend = lifetimeTotal
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
        var lifetimeTotal: Decimal = 0
        for sub in activeSubscriptions {
            monthlyTotal += monthlyEquivalent(for: sub)
            lifetimeTotal += sub.lifetimeSpend
        }
        totalMonthlySpend = monthlyTotal
        totalAnnualSpend = monthlyTotal * 12
        totalLifetimeSpend = lifetimeTotal
    }
    
    // MARK: - Computed Properties
    
    var activeSubscriptions: [Subscription] {
        subscriptions.filter { $0.status == .active && !$0.isPaused }
    }

    var pausedSubscriptions: [Subscription] {
        subscriptions.filter { $0.isPaused }
    }

    var pausableSubscriptions: [Subscription] {
        subscriptions.filter { $0.canPause && $0.status == .active && !$0.isPaused }
    }
    
    var upcomingRenewals: [Subscription] {
        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysFromNow = calendar.date(byAdding: .day, value: 30, to: now) ?? now

        return activeSubscriptions
            .filter { sub in
                guard let nextBilling = sub.calculatedNextBillingDate else { return false }
                return nextBilling >= now && nextBilling <= thirtyDaysFromNow
            }
            .sorted { ($0.calculatedNextBillingDate ?? now) < ($1.calculatedNextBillingDate ?? now) }
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

    // MARK: - Live Activity

    private func startLiveActivityIfNeeded() {
        guard AppSettings.shared.liveActivitiesEnabled else { return }

        // Find the most urgent upcoming renewal
        let upcoming = activeSubscriptions
            .filter { ($0.daysUntilRenewal ?? 999) <= 14 }
            .sorted { ($0.daysUntilRenewal ?? 999) < ($1.daysUntilRenewal ?? 999) }

        if let first = upcoming.first {
            LiveActivityManager.shared.startLiveActivity(for: first)
        } else {
            LiveActivityManager.shared.endCurrentActivity()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let subscriptionAdded = Notification.Name("subscriptionAdded")
    static let subscriptionUpdated = Notification.Name("subscriptionUpdated")
    static let subscriptionDeleted = Notification.Name("subscriptionDeleted")
}
