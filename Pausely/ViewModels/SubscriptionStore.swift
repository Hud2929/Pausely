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
    /// The last fetch failed while nothing was on this iPhone (see `ListState.couldNotLoad`).
    @Published private(set) var lastFetchFailed = false
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
        #if DEBUG
        // A demo list saved by an earlier demo launch is shown offline in another demo launch, and
        // thrown away by an ordinary one, before anything can load it as the person's own.
        switch Self.savedDemoList(isDemo: UserDefaults.standard.bool(forKey: Self.savedListIsDemoKey),
                                  isDemoLaunch: LaunchFlag.isDemoLaunch) {
        case .none: break
        case .shownOffline: Self.cloudSyncEnabled = false
        case .discarded:
            AppSettings.shared.cachedSubscriptions = Data()
            UserDefaults.standard.removeObject(forKey: Self.savedListIsDemoKey)
        }
        #endif
        loadFromCache()
        sync.currentCopy = copyForSync
        #if DEBUG
        // UI tests: start from the demo list on every launch and never write to the cloud.
        // Every demo list starts with no history and no hours typed in, then puts in its own: one
        // list's cancellation and its two hours of Netflix showed on the lists opened after it.
        let demoLists = ["--varied-demo-data", "--large-demo-data", "--quiet-demo-data", "--fresh-demo-data", "--empty-demo-data"]
        if demoLists.contains(where: LaunchFlag.isSet) {
            LifecycleEventLog.shared.removeAll()
            UsageLog.shared.forgetAll()
        }
        if LaunchFlag.isSet("--varied-demo-data") {
            // One of everything a list can hold, with its history (see `DemoSubscriptions.varied`).
            let varied = DemoSubscriptions.varied()
            useDemoList(varied)
            DemoSubscriptions.seedVariedHistory(for: varied)
        } else if LaunchFlag.isSet("--large-demo-data") {
            useDemoList(DemoSubscriptions.large())
        } else if LaunchFlag.isSet("--quiet-demo-data") {
            useDemoList(DemoSubscriptions.quiet())
        } else if LaunchFlag.isSet("--fresh-demo-data") {
            // The demo list as it is first seen. `--demo-savings` puts its own history in afterwards.
            useDemoList()
        } else if LaunchFlag.isSet("--empty-demo-data") {
            // A new person's empty list (an empty array, so the demo data isn't loaded in its place).
            Self.cloudSyncEnabled = false
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
        NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.timeZoneChanged() }
            .store(in: &currencyCancellables)
    }
    
    // MARK: - Data Fetching
    
    /// The account whose list was last fetched on this iPhone (see SubscriptionSyncMerge).
    static let syncedUserKey = "subscriptions_synced_user"

    /// What a tab shows where the list would be.
    enum ListState: Equatable {
        /// There is a list, and it is on screen.
        case shown
        /// Being fetched for the first time, with nothing on this iPhone yet.
        case loading
        /// The fetch failed and nothing is on this iPhone. The person may well have a list.
        case couldNotLoad
        /// Nothing on the list, and nothing went wrong finding that out.
        case empty

        /// Whether "what you pay each month" can be said. Before the list has arrived it cannot:
        /// Home said "$0.00" until it did.
        var totalIsKnown: Bool { self == .shown || self == .empty }
    }

    /// Whether a failed fetch is a failure to tell. The built-in test user (DEBUG, "Test without an account")
    /// has no account to fetch from, so its empty list is empty: it said "Couldn't load your list" on every
    /// launch that started with nothing listed (2026-11-22).
    nonisolated static func fetchReallyFailed(_ error: Error, userID: String?) -> Bool {
        if case SyncFailure.signedOut = error, userID == AuthManager.localTestUserID { return false }
        return true
    }

    nonisolated static func listState(isEmpty: Bool, isLoading: Bool, lastFetchFailed: Bool) -> ListState {
        guard isEmpty else { return .shown }
        if isLoading { return .loading }
        return lastFetchFailed ? .couldNotLoad : .empty
    }

    var listState: ListState {
        // `--demo-loading` and `--demo-load-failed` (DEBUG) hold the two states that otherwise last
        // as long as a request does, so they can be looked at.
        Self.listState(isEmpty: subscriptions.isEmpty,
                       isLoading: isLoading || LaunchFlag.isSet("--demo-loading"),
                       lastFetchFailed: lastFetchFailed || LaunchFlag.isSet("--demo-load-failed"))
    }

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
            lastFetchFailed = false
            UserDefaults.standard.set(userId.uuidString, forKey: Self.syncedUserKey)

            // Send up what only this iPhone had, and renewal dates the server was missing.
            for sub in merge.upload { sync.noteAdded(sub.id) }
            for sub in merge.backfill { sync.noteChanged(sub.id) }
            // A row whose days an earlier version saved goes back once, with its days in the saved form.
            let listed = Set(subscriptions.map(\.id))
            let oldForm = response.filter(\.hasADayInTheOldForm).compactMap(\.id).filter(listed.contains)
            for id in oldForm { sync.noteChanged(id) }
            if !merge.upload.isEmpty || !merge.backfill.isEmpty || !oldForm.isEmpty {
                await sync.drain()
            }
            await SubscriptionLifecycle.shared.run()

        } catch {
            os_log("Error fetching subscriptions: %{public}@", log: .default, type: .error, error.localizedDescription)
            if subscriptions.isEmpty {
                loadFromCache()
                if subscriptions.isEmpty, Self.fetchReallyFailed(error, userID: AuthManager.shared.currentUser?.id) {
                    lastFetchFailed = true
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
    
    /// The free plan is full. Screens open the upgrade page; a Shortcut says it in a sentence.
    enum SubscriptionLimitError: Error, CustomLocalizedStringResourceConvertible {
        case freeTierLimitReached

        var localizedStringResource: LocalizedStringResource {
            "Free tracks \(FreeTier.subscriptionLimit). Pausely Pro tracks all of them."
        }
    }

    /// Adds a subscription. It is on this iPhone, and waiting to be sent, before this returns; whether
    /// it has reached the account yet is the result (false: still waiting). The only thing that can
    /// stop an add is a refusal, like the free tier's limit.
    @discardableResult
    func addSubscription(_ subscription: Subscription) async throws -> Bool {
        // Signed out, the list is out of memory and its copy on the iPhone waits for its owner. An add
        // now (a Shortcut can try) would save a list of one over that copy.
        guard !isHidden else { throw SyncFailure.signedOut }
        // The free plan's places are for what charges. Something already cancelled takes none.
        if subscription.renewsAutomatically, !PaymentManager.shared.hasRoom(in: subscriptions) {
            throw SubscriptionLimitError.freeTierLimitReached
        }

        let added = Self.withDaysAtNoon(subscription)
        subscriptions.insert(added, at: 0)
        listChanged()
        sync.noteAdded(added.id)
        LifecycleEventLog.shared.record(.added, for: added)
        // Rebuild every reminder from the current list (heads-up, day before, day of, trial ending).
        await ReminderScheduler.shared.reschedule(subscriptions)
        return await send(added.id)
    }

    /// A renewal day and the last day of a trial are calendar days, not moments. Whoever hands one in,
    /// it is kept at local noon, so a change of time zone can't move it to another day (see RenewalSchedule).
    static func withDaysAtNoon(_ subscription: Subscription, calendar: Calendar = .billing) -> Subscription {
        var fixed = subscription
        fixed.nextBillingDate = subscription.nextBillingDate.map { calendar.noon(of: $0) }
        fixed.trialEndsAt = subscription.trialEndsAt.map { calendar.noon(of: $0) }
        return fixed
    }

    /// Every change below lands on this iPhone and in the sync queue in one step, with nothing able to
    /// come between, and cannot fail: if the account can't be reached the change waits and a notice says so.

    func updateSubscription(_ changed: Subscription) async {
        let subscription = Self.withDaysAtNoon(changed)
        guard let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) else { return }
        let before = subscriptions[index]
        subscriptions[index] = subscription
        listChanged()
        sync.noteChanged(subscription.id)
        // What it costs is the amount, its currency and how often it is charged: a change to any of
        // them goes in the history (`PriceHistory` reads it from there).
        if subscription.amount != before.amount || subscription.currency != before.currency
            || subscription.billingFrequency != before.billingFrequency {
            LifecycleEventLog.shared.record(.priceChanged, for: subscription, previousAmount: before.amount)
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

    // MARK: - Paying for it again

    /// A cancelled subscription is on again from `date`, and renews on that day of the month from now
    /// on (see `PausePlanSchedule.restartAnchor`). The status change records a reactivation, which
    /// closes its Savings Receipt line. One that is already charging keeps the date it has.
    /// - Returns: false when the free plan has no place left for it (the caller shows the upgrade page).
    @discardableResult
    func startAgain(id: UUID, on date: Date = Date(), calendar: Calendar = .billing) async -> Bool {
        guard var updated = subscriptions.first(where: { $0.id == id }), !updated.renewsAutomatically else { return true }
        guard PaymentManager.shared.hasRoom(in: subscriptions) else { return false }
        let restart = PausePlanSchedule.restartAnchor(startedOn: date, frequency: updated.billingFrequency, calendar: calendar)
        updated.nextBillingDate = restart.anchor
        await updateSubscription(updated)
        await updateSubscriptionStatus(id: id, status: .active)
        if restart.isStartDay {
            // Today's charge is the one just paid: nothing to decide and nothing to be reminded of.
            LifecycleEventLog.shared.record(.kept, for: updated, date: date, renewalDate: restart.anchor)
            await ReminderScheduler.shared.reschedule(subscriptions)
        }
        return true
    }

    // MARK: - A change of time zone

    /// The time zone the days in memory were read in. A renewal day is held as noon in the phone's
    /// zone (`BillingDay`); after a flight that moment is another day, so the days are read again from
    /// their saved form, which names the same day everywhere.
    private var zoneOfDays = TimeZone.current.identifier

    /// Called when the app comes to the foreground.
    func noticeTimeZone() {
        if TimeZone.current.identifier != zoneOfDays { timeZoneChanged() }
    }

    func timeZoneChanged() {
        zoneOfDays = TimeZone.current.identifier
        LifecycleEventLog.shared.reload()
        guard !isHidden, !subscriptions.isEmpty else { return }
        loadFromCache()
        WidgetDataStore.shared.publish(subscriptions: subscriptions)
        Task { await ReminderScheduler.shared.reschedule(subscriptions) }
    }

    /// True while nobody is signed in: from signing out, or from a launch signed out, until someone
    /// signs in. (Tests set it back through `StoreSandbox`.)
    var isHidden = false

    /// Signed out: the list leaves memory, the widgets and Spotlight. The copy kept on the iPhone and
    /// the changes still waiting to be sent stay, for when the same person signs back in.
    func hideList() {
        isHidden = true
        subscriptions = []
        calculateTotals()
        WidgetDataStore.shared.publish(subscriptions: [])
        SpotlightManager.shared.index(subscriptions: [])
        lastFetchDate = nil
    }

    /// The main screen is up for a signed-in person: the copy kept on the iPhone comes back if it was
    /// hidden, and the widgets and Spotlight are given the list as it stands today. The widgets hold
    /// about a year of charge days from the day they were last told, so they are told at every start,
    /// not only when the list changes.
    func showList() {
        isHidden = false
        if subscriptions.isEmpty { loadFromCache() }
        WidgetDataStore.shared.publish(subscriptions: subscriptions)
        SpotlightManager.shared.index(subscriptions: subscriptions)
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
            #if DEBUG
            if Self.fillsWithDemoList(listIsEmpty: subscriptions.isEmpty, isDemoLaunch: LaunchFlag.isDemoLaunch) {
                useDemoList()
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
    /// Set while the saved list is the demo set.
    static let savedListIsDemoKey = "saved_list_is_demo"

    /// An empty list is filled with the demo set only in a demo launch (captures, UI tests, demos).
    /// Any debug build with an empty list used to get it, and when that build was signed in to a real
    /// account the next sync uploaded twelve made-up subscriptions to it.
    nonisolated static func fillsWithDemoList(listIsEmpty: Bool, isDemoLaunch: Bool) -> Bool {
        listIsEmpty && isDemoLaunch
    }

    enum SavedDemoList { case none, shownOffline, discarded }

    /// What a launch does with a saved list that is the demo set.
    nonisolated static func savedDemoList(isDemo: Bool, isDemoLaunch: Bool) -> SavedDemoList {
        guard isDemo else { return .none }
        return isDemoLaunch ? .shownOffline : .discarded
    }

    /// The demo set becomes the list: marked as such, and never sent anywhere.
    private func useDemoList(_ list: [Subscription] = SubscriptionStore.makeDemoSubscriptions()) {
        Self.cloudSyncEnabled = false
        UserDefaults.standard.set(true, forKey: Self.savedListIsDemoKey)
        subscriptions = list
        calculateTotals()
        saveToCache()
    }

    static func makeDemoSubscriptions() -> [Subscription] {
        let calendar = Calendar.billing
        let now = Date()
        return [
            Subscription(
                id: UUID(),
                name: "Netflix",
                category: "Entertainment",
                amount: 15.99,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 5, to: now),
                status: .active
            ),
            Subscription(
                id: UUID(),
                name: "Spotify",
                category: "Music",
                amount: 10.99,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 12, to: now),
                status: .active
            ),
            Subscription(
                id: UUID(),
                name: "ChatGPT Plus",
                category: "AI & Creativity",
                amount: 20.00,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 18, to: now),
                status: .active
            ),
            Subscription(
                id: UUID(),
                name: "Apple One",
                category: "Productivity",
                amount: 32.95,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 2, to: now),
                status: .active
            ),
            Subscription(
                id: UUID(),
                name: "YouTube Premium",
                category: "Entertainment",
                amount: 13.99,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 24, to: now),
                status: .active
            ),
            Subscription(
                id: UUID(),
                name: "Notion",
                category: "Productivity",
                amount: 10.00,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 8, to: now),
                status: .active
            ),
            Subscription(
                id: UUID(),
                name: "Peloton",
                category: "Health & Fitness",
                amount: 44.00,
                billingFrequency: .monthly,
                nextBillingDate: calendar.date(byAdding: .day, value: 15, to: now),
                status: .active
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


}

// MARK: - Notification Names

