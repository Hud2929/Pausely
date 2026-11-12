import Foundation
import Auth
import PostgREST
import os.log
import Combine

@MainActor
class SubscriptionStore: ObservableObject {
    @Published var subscriptions: [Subscription] = []
    @Published var totalMonthlySpend: Decimal = 0
    @Published var totalAnnualSpend: Decimal = 0
    /// Some of what is being paid for is charged in another currency, so the totals are estimates ("≈").
    @Published private(set) var totalIsConverted = false
    @Published var isLoading = false
    @Published var lastErrorMessage: String?
    @Published var lastFetchDate: Date?
    static let shared = SubscriptionStore()

    private let client = SupabaseManager.shared.client

    /// Tests switch this off: every change still lands on the device and is queued for sync, exactly as
    /// when offline, nothing is fetched, and the live database is never touched.
    static var cloudSyncEnabled = true

    /// The way to the account. Every change is noted here; tests put a stand-in for the server behind it.
    var sync: SyncQueue = .shared {
        didSet { sync.currentCopy = copyForSync }
    }

    /// What the sync queue sends is always the subscription as it is here at that moment.
    private var copyForSync: (UUID) -> Subscription? {
        { [weak self] id in self?.subscriptions.first { $0.id == id } }
    }

    private var currencyCancellables: Set<AnyCancellable> = []

    private init() {
        loadFromCache()
        sync.currentCopy = copyForSync
        #if DEBUG
        // UI tests: start from the demo list on every launch and never write to the cloud.
        if ProcessInfo.processInfo.arguments.contains("--fresh-demo-data") {
            Self.cloudSyncEnabled = false
            subscriptions = Self.makeDemoSubscriptions()
            calculateTotals()
            saveToCache()
        } else if ProcessInfo.processInfo.arguments.contains("--empty-demo-data") {
            // A new person's empty list (an empty array, so the demo data isn't loaded in its place)
            // and no history from earlier runs.
            Self.cloudSyncEnabled = false
            LifecycleEventLog.shared.removeAll()
            subscriptions = []
            calculateTotals()
            saveToCache()
        }
        #endif
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
    
    /// The account whose list was last fetched on this iPhone (see SubscriptionSyncMerge).
    static let syncedUserKey = "subscriptions_synced_user"

    func fetchSubscriptions(force: Bool = false) async {
        guard Self.cloudSyncEnabled else { return }

        if !force, let lastFetch = lastFetchDate,
           Date().timeIntervalSince(lastFetch) < 60 {
            return
        }

        isLoading = true
        defer { isLoading = false }

        // Always load from local cache first for responsiveness
        if subscriptions.isEmpty {
            loadFromCache()
        }

        do {
            guard let session = client.auth.currentSession else { throw SyncFailure.signedOut }
            let userId = session.user.id
            // A list left here by a different account is removed by `LocalUserData.claim` before
            // anything is fetched into it or sent from it.
            guard LocalUserData.belongs(to: userId.uuidString) else { return }

            // This iPhone's waiting changes go up first, so the server's list below already has them.
            await sync.drain(force: true)
            let mark = sync.sequence

            let response: [SubscriptionRecord] = try await client
                .from("subscriptions")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            // Nothing waits between reading this iPhone's list and replacing it, so no change can
            // slip in between. A change made while the answer was on its way counts as still waiting:
            // the answer may be older than it is.
            let firstSync = UserDefaults.standard.string(forKey: Self.syncedUserKey) != userId.uuidString
            let waiting = sync.changes(since: mark)
                .merging(sync.pendingKinds) { _, queued in queued }
            let merge = SubscriptionSyncMerge.merge(server: response.map { $0.toSubscription() },
                                                    local: subscriptions,
                                                    pending: waiting,
                                                    firstSyncForUser: firstSync)
            subscriptions = merge.subscriptions
            listChanged()
            lastFetchDate = Date()
            lastErrorMessage = nil
            PriceIncreaseMonitor.shared.checkForPriceChanges(subscriptions: subscriptions)
            UserDefaults.standard.set(userId.uuidString, forKey: Self.syncedUserKey)

            // Send up what only this iPhone had, and renewal dates the server was missing.
            for sub in merge.upload { sync.noteAdded(sub.id) }
            for sub in merge.backfill { sync.noteChanged(sub.id) }
            if !merge.upload.isEmpty || !merge.backfill.isEmpty {
                await sync.drain()
            }
            await SubscriptionLifecycle.shared.run()

        } catch {
            os_log("Error fetching subscriptions: %{public}@", log: .default, type: .error, error.localizedDescription)
            if subscriptions.isEmpty {
                loadFromCache()
                if subscriptions.isEmpty {
                    lastErrorMessage = L10n.string("Couldn't load subscriptions. Pull to refresh.")
                }
            }
            // Offline: reminders still come from the cached subscriptions.
            await SubscriptionLifecycle.shared.run()
        }
    }

    /// Everything that follows from the list changing: totals, the saved copy, the widget and Spotlight.
    private func listChanged() {
        calculateTotals()
        saveToCache()
        WidgetDataStore.shared.publish(subscriptions: subscriptions)
        SpotlightManager.shared.index(subscriptions: subscriptions)
    }

    /// Sends what is waiting. If this change is still on this iPhone only, says so, and says why.
    @discardableResult
    private func send(_ id: UUID, removed: Bool = false) async -> Bool {
        await sync.drain()
        guard let waiting = sync.intent(for: id) else { return true }
        lastErrorMessage = Self.waitingNotice(removed: removed, refused: waiting.refused)
        return false
    }

    /// "When you're back online" is only said when being offline is the reason.
    static func waitingNotice(removed: Bool, refused: Bool) -> String {
        switch (removed, refused) {
        case (false, false): return L10n.string("Saved on this iPhone. It will sync when you're back online.")
        case (true, false): return L10n.string("Removed from this iPhone. It will sync when you're back online.")
        case (false, true): return L10n.string("Saved on this iPhone. It hasn't reached your account yet. Pausely will keep trying.")
        case (true, true): return L10n.string("Removed from this iPhone. Your account still has it. Pausely will keep trying.")
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
    
    /// Adds a subscription. It is on this iPhone, and waiting to be sent, before this returns; whether
    /// it has reached the account yet is the result (false: still waiting). The only thing that can
    /// stop an add is a refusal, like the free tier's limit.
    @discardableResult
    func addSubscription(_ subscription: Subscription) async throws -> Bool {
        if PaymentManager.shared.hasReachedSubscriptionLimit(currentCount: subscriptions.count) {
            throw SubscriptionLimitError.freeTierLimitReached
        }

        var added = subscription
        // A renewal date is a calendar day, not a moment: store it at local noon (see RenewalSchedule).
        added.nextBillingDate = added.nextBillingDate.map { Calendar.current.noon(of: $0) }

        subscriptions.insert(added, at: 0)
        listChanged()
        sync.noteAdded(added.id)
        LifecycleEventLog.shared.record(.added, for: added)
        // Rebuild every reminder from the current list (heads-up, day before, day of, trial ending).
        await ReminderScheduler.shared.reschedule(subscriptions)
        return await send(added.id)
    }

    /// Every change below lands on this iPhone and in the sync queue in one step, with nothing able to
    /// come between, and cannot fail: if the account can't be reached the change waits and a notice says so.

    func updateSubscription(_ subscription: Subscription) async {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) else { return }
        let oldAmount = subscriptions[index].amount
        subscriptions[index] = subscription
        listChanged()
        sync.noteChanged(subscription.id)
        PriceHistoryTracker.shared.recordPriceIfChanged(subscription)
        if subscription.amount != oldAmount {
            LifecycleEventLog.shared.record(.priceChanged, for: subscription, previousAmount: oldAmount)
        }
        await ReminderScheduler.shared.reschedule(subscriptions)
        await send(subscription.id)
    }

    func deleteSubscription(id: UUID) async {
        guard let removed = subscriptions.first(where: { $0.id == id }) else { return }
        LifecycleEventLog.shared.record(.deleted, for: removed)
        subscriptions.removeAll { $0.id == id }
        listChanged()
        sync.noteDeleted(id)
        await ReminderScheduler.shared.reschedule(subscriptions)
        await send(id, removed: true)
    }

    func updateSubscriptionStatus(id: UUID, status: SubscriptionStatus) async {
        guard let index = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        let before = subscriptions[index]
        // The charge this cancellation avoids, worked out while it still renews.
        let avoided = RenewalDecisions.upcomingCharge(for: before, now: Date())?.date
        subscriptions[index].status = status
        listChanged()
        sync.noteChanged(id)
        if status == .cancelled, before.status != .cancelled {
            LifecycleEventLog.shared.record(.cancelled, for: before, renewalDate: avoided)
        } else if before.status == .cancelled, status == .active || status == .trial {
            LifecycleEventLog.shared.record(.reactivated, for: subscriptions[index])
        }
        await ReminderScheduler.shared.reschedule(subscriptions)
        if status == .cancelled {
            ReviewPromptManager.shared.askAfterMoneyKept()
        }
        await send(id)
    }

    func pauseSubscription(id: UUID, until date: Date) async {
        guard let index = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        subscriptions[index].pausedUntil = date
        listChanged()
        sync.noteChanged(id)
        await ReminderScheduler.shared.reschedule(subscriptions)
        await send(id)
    }

    func resumeSubscription(id: UUID) async {
        guard let index = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        subscriptions[index].pausedUntil = nil
        listChanged()
        sync.noteChanged(id)
        await ReminderScheduler.shared.reschedule(subscriptions)
        await send(id)
    }

    /// Removes every subscription from this device (account deletion, or a different person signing in).
    /// The server copy is not touched.
    func removeAllLocalData() {
        subscriptions = []
        calculateTotals()
        AppSettings.shared.cachedSubscriptions = Data()
        sync.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.syncedUserKey)
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
                canPause: true
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
                canPause: true
            ),
            Subscription(
                id: UUID(),
                name: "ChatGPT Plus",
                category: "AI Tools",
                amount: 20.00,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 18, to: now),
                status: .active,
                canPause: false
            ),
            Subscription(
                id: UUID(),
                name: "Apple One",
                category: "Productivity",
                amount: 32.95,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 2, to: now),
                status: .active,
                canPause: true
            ),
            Subscription(
                id: UUID(),
                name: "YouTube Premium",
                category: "Entertainment",
                amount: 13.99,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 24, to: now),
                status: .active,
                canPause: true
            ),
            Subscription(
                id: UUID(),
                name: "Notion",
                category: "Productivity",
                amount: 10.00,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 8, to: now),
                status: .active,
                canPause: true
            ),
            Subscription(
                id: UUID(),
                name: "Peloton",
                category: "Health & Fitness",
                amount: 44.00,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 15, to: now),
                status: .active,
                canPause: true
            )
        ]
    }
    #endif

    
    // MARK: - Batch Operations for Scale
    
    
    // MARK: - Totals

    /// Monthly and yearly totals of active subscriptions in the display currency. Every
    /// subscription is converted from its own currency first (see MoneyMath); cheap enough to redo
    /// on every change, so there's no cache to go stale.
    private func calculateTotals(in currency: String = CurrencyManager.shared.selectedCurrency) {
        let charging = subscriptions.charging
        let monthly = charging.monthlyTotal(in: currency, rates: CurrencyManager.shared.rates)
        totalIsConverted = charging.isConverted(to: currency)
        totalMonthlySpend = monthly
        totalAnnualSpend = monthly * 12
    }

    // MARK: - Computed Properties
    
    /// What is being paid for (see `charging`): the list behind the totals above.
    var activeSubscriptions: [Subscription] { subscriptions.charging }

    var pausedSubscriptions: [Subscription] {
        subscriptions.filter { $0.isPaused }
    }

}

// MARK: - Notification Names

