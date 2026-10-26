import Foundation
import Auth
import PostgREST
import os.log
import ActivityKit
import Combine

@MainActor
class SubscriptionStore: ObservableObject {
    @Published var subscriptions: [Subscription] = []
    @Published var totalMonthlySpend: Decimal = 0
    @Published var totalAnnualSpend: Decimal = 0
    @Published var totalLifetimeSpend: Decimal = 0
    @Published var isLoading = false
    @Published var lastErrorMessage: String?
    @Published var lastFetchDate: Date?
    static let shared = SubscriptionStore()

    private let client = SupabaseManager.shared.client
    private var fetchTask: Task<Void, Never>?

    private var currencyCancellables: Set<AnyCancellable> = []

    private init() {
        loadFromCache()
        // Totals are in the display currency: redo them when it changes or when live rates arrive.
        // @Published sends before the new value is stored, so take the new code from the event and
        // let rate updates finish before reading them.
        CurrencyManager.shared.$selectedCurrency
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] code in self?.calculateTotals(in: code) }
            .store(in: &currencyCancellables)
        CurrencyManager.shared.$exchangeRates
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.calculateTotals() }
            .store(in: &currencyCancellables)
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
                // Don't wipe locally-added subscriptions if Supabase returns empty
                // (user may be in demo/offline mode with locally-tracked subs)
                if fetchedSubscriptions.isEmpty && !self.subscriptions.isEmpty {
                    return
                }
                self.subscriptions = fetchedSubscriptions
                self.calculateTotals()
                self.lastFetchDate = Date()
                self.lastErrorMessage = nil
                self.saveToCache()
                WidgetDataStore.shared.publish(subscriptions: self.subscriptions)
                SpotlightManager.shared.index(subscriptions: self.subscriptions)
                self.startLiveActivityIfNeeded()
                PriceIncreaseMonitor.shared.checkForPriceChanges(subscriptions: self.subscriptions)
            }

            // Process pending sync operations after successful fetch
            await SyncQueue.shared.processQueue()
            await SubscriptionLifecycle.shared.run()

        } catch {
            os_log("Error fetching subscriptions: %{public}@", log: .default, type: .error, error.localizedDescription)
            await MainActor.run {
                if self.subscriptions.isEmpty {
                    self.loadFromCache()
                    if self.subscriptions.isEmpty {
                        self.lastErrorMessage = "Couldn't load subscriptions. Pull to refresh."
                    }
                }
            }
            // Offline: reminders still come from the cached subscriptions.
            await SubscriptionLifecycle.shared.run()
        }
    }
    
    
    // MARK: - CRUD Operations
    
    enum SubscriptionLimitError: Error, LocalizedError {
        case freeTierLimitReached
        
        var errorDescription: String? {
            switch self {
            case .freeTierLimitReached:
                return "You've reached the free tier limit of \(FreeTier.subscriptionLimit) subscriptions. Upgrade to Pro for unlimited subscriptions."
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
        // A renewal date is a calendar day, not a moment: store it at local noon (see RenewalSchedule).
        localSub.nextBillingDate = localSub.nextBillingDate.map { Calendar.current.noon(of: $0) }

        // 1. Update local state immediately (offline-first)
        await MainActor.run {
            self.subscriptions.insert(localSub, at: 0)
            self.calculateTotals()
            self.saveToCache()
            WidgetDataStore.shared.publish(subscriptions: self.subscriptions)
            SpotlightManager.shared.index(subscriptions: self.subscriptions)
        }

        LifecycleEventLog.shared.record(.added, for: localSub)
        // Rebuild every reminder from the current list (heads-up, day before, day of, trial ending).
        await ReminderScheduler.shared.reschedule(self.subscriptions)

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
            return true
        } catch {
            os_log("Error adding subscription to cloud: %{public}@", log: .default, type: .error, error.localizedDescription)
            // 3. Enqueue for retry
            if let payload = try? JSONEncoder().encode(SubscriptionRecord(from: localSub)) {
                let op = SyncOperation(type: .create, subscriptionId: localSub.id, payload: payload)
                SyncQueue.shared.enqueue(op)
            }
            throw error
        }
    }
    
    func updateSubscription(_ subscription: Subscription) async throws {
        // 1. Update local state immediately (offline-first)
        await MainActor.run {
            if let index = self.subscriptions.firstIndex(where: { $0.id == subscription.id }) {
                let oldAmount = self.subscriptions[index].amount
                self.subscriptions[index] = subscription
                self.calculateTotals()
                self.saveToCache()
                WidgetDataStore.shared.publish(subscriptions: self.subscriptions)
                SpotlightManager.shared.index(subscriptions: self.subscriptions)
                PriceHistoryTracker.shared.recordPriceIfChanged(subscription)
                if subscription.amount != oldAmount {
                    LifecycleEventLog.shared.record(.priceChanged, for: subscription, previousAmount: oldAmount)
                }
            }
        }

        await ReminderScheduler.shared.reschedule(self.subscriptions)

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
            throw error
        }
    }

    func deleteSubscription(id: UUID) async throws {
        // 1. Update local state immediately (offline-first)
        await MainActor.run {
            if let removed = self.subscriptions.first(where: { $0.id == id }) {
                LifecycleEventLog.shared.record(.deleted, for: removed)
            }
            self.subscriptions.removeAll { $0.id == id }
            self.calculateTotals()
            self.saveToCache()
            WidgetDataStore.shared.publish(subscriptions: self.subscriptions)
            SpotlightManager.shared.index(subscriptions: self.subscriptions)
        }
        await ReminderScheduler.shared.reschedule(self.subscriptions)

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
            self.lastErrorMessage = "Couldn't delete — will retry when online"
            throw error
        }
    }

    func updateSubscriptionStatus(id: UUID, status: SubscriptionStatus) async throws {
        // 1. Update local state immediately (offline-first)
        await MainActor.run {
            if let index = self.subscriptions.firstIndex(where: { $0.id == id }) {
                let before = self.subscriptions[index]
                // The charge this cancellation avoids, worked out while it still renews.
                let avoided = RenewalDecisions.upcomingCharge(for: before, now: Date())?.date
                self.subscriptions[index].status = status
                self.calculateTotals()
                self.saveToCache()
                WidgetDataStore.shared.publish(subscriptions: self.subscriptions)
                SpotlightManager.shared.index(subscriptions: self.subscriptions)
                if status == .cancelled, before.status != .cancelled {
                    LifecycleEventLog.shared.record(.cancelled, for: before, renewalDate: avoided)
                } else if before.status == .cancelled, status == .active || status == .trial {
                    LifecycleEventLog.shared.record(.reactivated, for: self.subscriptions[index])
                }
            }
        }
        await ReminderScheduler.shared.reschedule(self.subscriptions)
        if status == .cancelled {
            await MainActor.run { ReviewPromptManager.shared.askAfterMoneyKept() }
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
            self.lastErrorMessage = "Saved locally, will sync when back online"
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
        await ReminderScheduler.shared.reschedule(self.subscriptions)

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
            self.lastErrorMessage = "Saved locally, will sync when back online"
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
        await ReminderScheduler.shared.reschedule(self.subscriptions)

        // 2. Attempt Supabase write
        struct ResumePayload: Encodable {
            let paused_until: String?
        }
        do {
            try await client
                .from("subscriptions")
                .update(ResumePayload(paused_until: nil))
                .eq("id", value: id)
                .execute()
        } catch {
            os_log("Error resuming subscription in cloud: %{public}@", log: .default, type: .error, error.localizedDescription)
            // 3. Enqueue for retry
            if let payload = try? JSONEncoder().encode(ResumePayload(paused_until: nil)) {
                let op = SyncOperation(type: .resume, subscriptionId: id, payload: payload)
                SyncQueue.shared.enqueue(op)
            }
        }
    }
    
    /// Removes every subscription from this device (account deletion, or a different person signing in).
    /// The server copy is not touched.
    func removeAllLocalData() {
        subscriptions = []
        calculateTotals()
        AppSettings.shared.cachedSubscriptions = Data()
        WidgetDataStore.shared.publish(subscriptions: [])
        SpotlightManager.shared.index(subscriptions: [])
        lastFetchDate = nil
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
        guard !data.isEmpty else {
            // Demo data for screenshots / simulator
            #if DEBUG
            if subscriptions.isEmpty {
                let demoSubs = Self.makeDemoSubscriptions()
                self.subscriptions = demoSubs
                self.calculateTotals()
                self.saveToCache()
            }
            #endif
            return
        }

        do {
            let cached = try JSONDecoder().decode([Subscription].self, from: data)
            // SubscriptionStore is @MainActor so we can update synchronously here
            self.subscriptions = cached
            self.calculateTotals()
        } catch {
            os_log("Cache load failed: %{public}@", log: .default, type: .error, error.localizedDescription)
        }
    }

    #if DEBUG
    static func makeDemoSubscriptions() -> [Subscription] {
        let calendar = Calendar.current
        let now = Date()
        return [
            Subscription(
                id: UUID(),
                name: "Netflix",
                bundleIdentifier: "com.netflix.Netflix",
                category: "Entertainment",
                amount: 15.99,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 5, to: now),
                status: .active,
                canPause: true,
                startDate: calendar.date(byAdding: .year, value: -2, to: now)
            ),
            Subscription(
                id: UUID(),
                name: "Spotify",
                bundleIdentifier: "com.spotify.client",
                category: "Music",
                amount: 10.99,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 12, to: now),
                status: .active,
                canPause: true,
                startDate: calendar.date(byAdding: .year, value: -1, to: now)
            ),
            Subscription(
                id: UUID(),
                name: "ChatGPT Plus",
                category: "AI Tools",
                amount: 20.00,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 18, to: now),
                status: .active,
                canPause: false,
                startDate: calendar.date(byAdding: .month, value: -8, to: now)
            ),
            Subscription(
                id: UUID(),
                name: "Apple One",
                category: "Productivity",
                amount: 32.95,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 2, to: now),
                status: .active,
                canPause: true,
                startDate: calendar.date(byAdding: .month, value: -6, to: now)
            ),
            Subscription(
                id: UUID(),
                name: "YouTube Premium",
                category: "Entertainment",
                amount: 13.99,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 24, to: now),
                status: .active,
                canPause: true,
                startDate: calendar.date(byAdding: .year, value: -3, to: now)
            ),
            Subscription(
                id: UUID(),
                name: "Notion",
                category: "Productivity",
                amount: 10.00,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 8, to: now),
                status: .active,
                canPause: true,
                startDate: calendar.date(byAdding: .month, value: -4, to: now)
            ),
            Subscription(
                id: UUID(),
                name: "Peloton",
                category: "Health & Fitness",
                amount: 44.00,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 15, to: now),
                status: .active,
                canPause: true,
                startDate: calendar.date(byAdding: .month, value: -3, to: now)
            )
        ]
    }
    #endif

    
    // MARK: - Batch Operations for Scale
    
    /// Efficiently add multiple subscriptions in batch
    func batchAddSubscriptions(_ newSubscriptions: [Subscription]) async -> (added: Int, failed: Int) {
        var added = 0
        var failed = 0
        
        // Deduplication check
        let existingNames = Set(subscriptions.map { $0.name.lowercased() })
        let uniqueSubs = newSubscriptions.filter { !existingNames.contains($0.name.lowercased()) }
        
        for sub in uniqueSubs {
            do {
                _ = try await addSubscription(sub)
                added += 1
            } catch {
                failed += 1
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
    
    // MARK: - Totals

    /// Monthly, yearly and lifetime totals of active subscriptions in the display currency. Every
    /// subscription is converted from its own currency first (see MoneyMath); cheap enough to redo
    /// on every change, so there's no cache to go stale.
    private func calculateTotals(in currency: String = CurrencyManager.shared.selectedCurrency) {
        let active = subscriptions.filter { $0.status == .active }
        let rates = CurrencyManager.shared.rates
        let monthly = active.monthlyTotal(in: currency, rates: rates)
        totalMonthlySpend = monthly
        totalAnnualSpend = monthly * 12
        totalLifetimeSpend = MoneyMath.total(active, in: currency, rates: rates,
                                             amount: \.lifetimeSpend, currencyOf: \.currency)
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
                guard sub.calculatedNextBillingDate != nil, let days = sub.daysUntilRenewal else { return false }
                return days >= 0 && days <= calendar.calendarDays(from: now, to: thirtyDaysFromNow)
            }
            .sorted { ($0.calculatedNextBillingDate ?? now) < ($1.calculatedNextBillingDate ?? now) }
    }
    
    func subscriptionsByCategory() -> [(category: String, subscriptions: [Subscription], total: Decimal)] {
        let grouped = Dictionary(grouping: activeSubscriptions) { $0.category ?? "Other" }
        return grouped.map { (category: $0.key, subscriptions: $0.value, total: calculateCategoryTotal($0.value)) }
            .sorted { $0.total > $1.total }
    }
    
    /// Monthly total of these subscriptions in the display currency.
    private func calculateCategoryTotal(_ subscriptions: [Subscription]) -> Decimal {
        subscriptions.monthlyTotal()
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

