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
    /// Active subscriptions whose currency lacked an exchange rate and were excluded from the totals.
    @Published private(set) var unconvertibleCount = 0
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
        didSet {
            sync.currentCopy = copyForSync
            sync.onNetworkRestored = recoverFirstSyncOnNetwork
        }
    }

    /// What the sync queue sends is always the subscription as it is here at that moment.
    private var copyForSync: (UUID) -> Subscription? {
        { [weak self] id in self?.subscriptions.first { $0.id == id } }
    }

    /// Retries first-sync reconciliation, history/plan syncs, exchange rates, and pending age consent
    /// automatically when connectivity returns.
    private var recoverFirstSyncOnNetwork: () async -> Void {
        { [weak self] in
            guard let self, Self.cloudSyncEnabled else { return }
            let auth = AuthManager.shared
            await CurrencyManager.shared.refreshRatesWhenDue()
            guard auth.isSignedIntoCloud else { return }
            if let uid = auth.currentUser?.id {
                await AgeConsentManager.shared.syncPendingConsent(userId: uid)
            }
            if Self.isFirstSync(for: auth.currentUser?.id) {
                await self.fetchSubscriptions(force: true)
            }
            await LifecycleSync.shared.sync()
            await PausePlanSync.shared.sync()
        }
    }

    private var currencyCancellables: Set<AnyCancellable> = []

    private init() {
        #if DEBUG
        switch Self.savedDemoList(isDemo: UserDefaults.standard.bool(forKey: Self.savedListIsDemoKey),
                                  isDemoLaunch: LaunchFlag.isDemoLaunch) {
        case .none: break
        case .shownOffline: Self.cloudSyncEnabled = false
        case .discarded:
            AppSettings.shared.cachedSubscriptions = Data()
            UserDefaults.standard.removeObject(forKey: Self.savedListIsDemoKey)
        }
        #endif
        // Start hidden whenever nobody is signed in so cached data never leaks to widgets/reminders on cold launch.
        let runningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        isHidden = !runningTests && !AuthManager.shared.isAuthenticated && !LaunchFlag.isDemoLaunch
        if !isHidden { loadFromCache() }
        sync.currentCopy = copyForSync
        sync.onNetworkRestored = recoverFirstSyncOnNetwork
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
            .sink { [weak self] code in
                guard let self else { return }
                self.calculateTotals(in: code)
                if !self.isHidden { WidgetDataStore.shared.publish(subscriptions: self.subscriptions) }
            }
            .store(in: &currencyCancellables)
        CurrencyManager.shared.$exchangeRates
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.calculateTotals()
                if !self.isHidden { WidgetDataStore.shared.publish(subscriptions: self.subscriptions) }
            }
            .store(in: &currencyCancellables)
        NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.timeZoneChanged() }
            .store(in: &currencyCancellables)
    }
    
    // MARK: - Data Fetching
    
    /// The account whose list was last fetched on this iPhone (see SubscriptionSyncMerge).
    nonisolated static let syncedUserKey = "subscriptions_synced_user"

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

    /// Whether a failed fetch is a failure to tell. The built-in test user (DEBUG) and local-only guest
    /// mode have no cloud account to fetch from, so an empty list is empty, not a load failure.
    nonisolated static func fetchReallyFailed(_ error: Error, userID: String?) -> Bool {
        if case SyncFailure.signedOut = error,
           userID == AuthManager.localTestUserID || userID == AuthManager.guestUserID { return false }
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
        if AuthManager.shared.isGuest {
            if subscriptions.isEmpty { loadFromCache() }
            await SubscriptionLifecycle.shared.run()
            return
        }

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
            // Require a valid, refreshed session so an expired token throws instead of querying PostgREST
            // as `anon` (which returns `[]` under RLS and would wipe local subscriptions).
            guard client.auth.currentSession != nil else { throw SyncFailure.signedOut }
            let session = try await client.auth.session
            guard !session.isExpired else { throw SyncFailure.signedOut }
            let userId = session.user.id
            // A list left here by a different account is removed by `LocalUserData.claim` before
            // anything is fetched into it or sent from it.
            guard LocalUserData.belongs(to: userId.uuidString) else { return }

            try await reconcileWithServer(userId: userId.uuidString) {
                let pageSize = 1_000
                let maxRows = 2_000
                var response: [SubscriptionRecord] = []
                var offset = 0
                while response.count < maxRows {
                    let end = min(offset + pageSize - 1, maxRows - 1)
                    let page: [SubscriptionRecord] = try await client
                        .from("subscriptions")
                        .select()
                        .eq("user_id", value: userId)
                        .order("created_at", ascending: false)
                        .order("id", ascending: false)
                        .range(from: offset, to: end)
                        .execute()
                        .value
                    response.append(contentsOf: page)
                    if page.count < pageSize { break }
                    offset += pageSize
                }
                let oldForm = response.filter(\.hasADayInTheOldForm).compactMap(\.id)
                return (response.map { $0.toSubscription() }, oldForm)
            }

        } catch {
            os_log("Error fetching subscriptions: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
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

    /// True until this account has reconciled its first server fetch on this device. While true,
    /// queued guest `.create`s wait for `SubscriptionSyncMerge` dedup before any upload can fire.
    nonisolated static func isFirstSync(for userId: String?, defaults: UserDefaults = .standard) -> Bool {
        guard let userId, !userId.isEmpty else { return true }
        return defaults.string(forKey: Self.syncedUserKey)?.caseInsensitiveCompare(userId) != .orderedSame
    }

    /// Runs the fetch-and-merge step cleanly, skipping pre-fetch drain on `firstSync` so local guest
    /// rows deduplicate against existing server rows before anything uploads.
    func reconcileWithServer(userId: String,
                             defaults: UserDefaults = .standard,
                             fetchRemote: () async throws -> (subscriptions: [Subscription], oldFormIDs: [UUID])) async throws {
        let firstSync = Self.isFirstSync(for: userId, defaults: defaults)
        if !firstSync {
            await sync.drain(force: true)
        }
        let mark = sync.sequence

        let remote = try await fetchRemote()

        let waiting = sync.changes(since: mark).merging(sync.pendingKinds) { sinceMark, queued in
            if sinceMark == .delete || queued == .delete { return .delete }
            if sinceMark == .create || queued == .create { return .create }
            return .update
        }
        let merge = SubscriptionSyncMerge.merge(server: remote.subscriptions,
                                                local: subscriptions,
                                                pending: waiting,
                                                firstSyncForUser: firstSync)
        subscriptions = merge.subscriptions
        listChanged()
        lastFetchDate = Date()
        lastErrorMessage = nil
        lastFetchFailed = false
        defaults.set(userId, forKey: Self.syncedUserKey)

        // Drop superseded guest creates and remap local Pause Plan, history, and usage IDs BEFORE syncing.
        for id in merge.supersededLocalIDs { sync.dropPendingCreate(id) }
        if !merge.remappedLocalIDs.isEmpty {
            PausePlanStore.shared.remapSubscriptionIDs(merge.remappedLocalIDs)
            LifecycleEventLog.shared.remapSubscriptionIDs(merge.remappedLocalIDs)
            UsageLog.shared.remapSubscriptionIDs(merge.remappedLocalIDs)
        }
        for sub in merge.upload { sync.noteAdded(sub.id) }
        for sub in merge.backfill { sync.noteChanged(sub.id) }
        let listed = Set(subscriptions.map(\.id))
        let oldForm = remote.oldFormIDs.filter(listed.contains)
        for id in oldForm { sync.noteChanged(id) }
        if !merge.upload.isEmpty || !merge.backfill.isEmpty || !oldForm.isEmpty {
            await sync.drain(force: true)
        }
        await SubscriptionLifecycle.shared.run()
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
        if AuthManager.shared.isGuest { return true }
        await sync.drain()
        guard let waiting = sync.intent(for: id) else { return true }
        lastErrorMessage = Self.waitingNotice(removed: removed, refused: waiting.refused)
        return false
    }

    /// Marks all local subscriptions for upload when a guest upgrades to a cloud account.
    func queueLocalSubscriptionsForUpload() {
        if subscriptions.isEmpty { loadFromCache() }
        for subscription in subscriptions where sync.intent(for: subscription.id) == nil {
            sync.noteAdded(subscription.id)
        }
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
            "The free plan tracks \(FreeTier.subscriptionLimit). Pausely Pro tracks all of them."
        }
    }

    /// Adds a subscription. It is on this iPhone, and waiting to be sent, before this returns; whether
    /// it has reached the account yet is the result (false: still waiting). The only thing that can
    /// stop an add is a refusal, like the free tier's limit.
    @discardableResult
    func addSubscription(_ subscription: Subscription, recordEvent: Bool = true) async throws -> Bool {
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
        if recordEvent {
            LifecycleEventLog.shared.record(.added, for: added)
        }
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
        if !before.renewsAutomatically, subscription.renewsAutomatically,
           !PaymentManager.shared.hasRoom(in: subscriptions) {
            return
        }
        subscriptions[index] = subscription
        listChanged()
        sync.noteChanged(subscription.id)
        let sameCurrency = MoneyFormat.normalizedCode(subscription.currency) == MoneyFormat.normalizedCode(before.currency)
        let samePeriod = subscription.billingFrequency == before.billingFrequency
        if subscription.amount != before.amount || !sameCurrency || !samePeriod {
            LifecycleEventLog.shared.record(.priceChanged, for: subscription,
                                            previousAmount: (sameCurrency && samePeriod) ? before.amount : nil)
        }
        await ReminderScheduler.shared.reschedule(subscriptions)
        await send(subscription.id)
    }

    func deleteSubscription(id: UUID, recordEvent: Bool = true) async {
        guard let removed = subscriptions.first(where: { $0.id == id }) else { return }
        if recordEvent {
            LifecycleEventLog.shared.record(.deleted, for: removed)
        }
        subscriptions.removeAll { $0.id == id }
        listChanged()
        sync.noteDeleted(id)
        await ReminderScheduler.shared.reschedule(subscriptions)
        await send(id, removed: true)
    }

    func updateSubscriptionStatus(id: UUID, status: SubscriptionStatus) async {
        guard let index = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        let before = subscriptions[index]
        if !before.renewsAutomatically, (status == .active || status == .trial),
           !PaymentManager.shared.hasRoom(in: subscriptions) {
            return
        }
        // The charge this cancellation avoids, worked out while it still renews.
        let avoided = RenewalDecisions.upcomingCharge(for: before, now: Date())?.date
        subscriptions[index].status = status
        if status == .cancelled, before.status != .cancelled {
            LifecycleEventLog.shared.record(.cancelled, for: before, renewalDate: avoided)
        } else if before.status == .cancelled, status == .active || status == .trial {
            LifecycleEventLog.shared.record(.reactivated, for: subscriptions[index])
        }
        // Record the lifecycle event BEFORE `listChanged()` so widgets publish the fresh Savings Receipt.
        listChanged()
        sync.noteChanged(id)
        await ReminderScheduler.shared.reschedule(subscriptions)
        if status == .cancelled {
            ReviewPromptManager.shared.askAfterMoneyKept()
        }
        await send(id)
    }

    /// Batch-applies the user's chosen default reminder lead time to non-Pausely subscriptions that
    /// still carry the previous default window, publishing widgets and rescheduling reminders once.
    func applyDefaultReminderDays(_ days: Int, from previousDefault: Int = 3) async {
        guard [1, 3, 7].contains(days), days != previousDefault else { return }
        var updatedIDs: [UUID] = []
        for idx in subscriptions.indices
            where subscriptions[idx].notifyBeforeDays == previousDefault && !subscriptions[idx].isPausely {
            subscriptions[idx].notifyBeforeDays = days
            updatedIDs.append(subscriptions[idx].id)
        }
        guard !updatedIDs.isEmpty else { return }
        listChanged()
        for id in updatedIDs { sync.noteChanged(id) }
        await ReminderScheduler.shared.reschedule(subscriptions)
        if !AuthManager.shared.isGuest { await sync.drain() }
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
        guard let index = subscriptions.firstIndex(where: { $0.id == id }) else { return true }
        var updated = subscriptions[index]
        guard !updated.renewsAutomatically else { return true }
        guard PaymentManager.shared.hasRoom(in: subscriptions) else { return false }

        var markKeptOn: Date?
        if let cancel = LifecycleEventLog.shared.events.last(where: { $0.subscriptionId == id && $0.kind == .cancelled }),
           Self.isUndo(of: cancel, on: date, calendar: calendar) {
            let stillInTrial = updated.trialEndsAt.map { calendar.startOfDay(for: $0) >= calendar.startOfDay(for: date) } ?? false
            updated.nextBillingDate = stillInTrial ? cancel.anchorDate : (cancel.anchorDate ?? cancel.renewalDate)
            updated.status = stillInTrial ? .trial : .active
        } else {
            let restart = PausePlanSchedule.restartAnchor(startedOn: date, frequency: updated.billingFrequency, calendar: calendar)
            updated.nextBillingDate = restart.anchor
            updated.trialEndsAt = nil
            updated.status = .active
            if restart.isStartDay { markKeptOn = restart.anchor }
        }
        updated = Self.withDaysAtNoon(updated, calendar: calendar)
        subscriptions[index] = updated
        LifecycleEventLog.shared.record(.reactivated, for: updated, date: date)
        if let keptDay = markKeptOn {
            LifecycleEventLog.shared.record(.kept, for: updated, date: date, renewalDate: keptDay)
        }
        listChanged()
        sync.noteChanged(id)
        await ReminderScheduler.shared.reschedule(subscriptions)
        await send(id)
        return true
    }

    /// Whether starting again on `date` takes back the cancellation: no charge it would have avoided
    /// fell strictly before `date` (matching `SavingsLedger.line` exactly on renewal-day reactivation).
    nonisolated static func isUndo(of cancel: LifecycleEvent, on date: Date, calendar: Calendar = .billing) -> Bool {
        guard let anchor = cancel.anchorDate ?? cancel.renewalDate else {
            return calendar.isDate(cancel.date, inSameDayAs: date)
        }
        let reactivatedDay = calendar.startOfDay(for: date)
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: reactivatedDay) else { return true }
        if dayBefore < calendar.startOfDay(for: cancel.date) { return true }
        let due = RenewalSchedule.renewals(anchor: anchor, frequency: cancel.frequency, after: cancel.date,
                                           through: dayBefore, calendar: calendar)
        return due.isEmpty
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
        } catch {
            os_log("Cache save failed: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
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
            os_log("Cache load failed: %{public}@", log: .default, type: .error, String(describing: type(of: error)))
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

    /// Recomputes totals after demo helpers mutate `subscriptions` directly.
    func recalculateDemoTotals() {
        calculateTotals()
    }

    static func makeDemoSubscriptions() -> [Subscription] {
        let cal = Calendar.billing
        let now = Date()
        func d(_ offset: Int) -> Date? { cal.date(byAdding: .day, value: offset, to: now) }
        return [
            Subscription(name: "Netflix", category: "Entertainment", amount: 15.99, billingFrequency: .monthly, nextBillingDate: d(5), status: .active),
            Subscription(name: "Spotify", category: "Music", amount: 10.99, billingFrequency: .monthly, nextBillingDate: d(12), status: .active),
            Subscription(name: "ChatGPT Plus", category: "AI & Creativity", amount: 20.00, billingFrequency: .monthly, nextBillingDate: d(18), status: .active),
            Subscription(name: "Apple One", category: "Productivity", amount: 32.95, billingFrequency: .monthly, nextBillingDate: d(2), status: .active),
            Subscription(name: "YouTube Premium", category: "Entertainment", amount: 13.99, billingFrequency: .monthly, nextBillingDate: d(24), status: .active),
            Subscription(name: "Notion", category: "Productivity", amount: 10.00, billingFrequency: .monthly, nextBillingDate: d(8), status: .active),
            Subscription(name: "Peloton", category: "Health & Fitness", amount: 44.00, billingFrequency: .monthly, nextBillingDate: d(15), status: .active),
        ]
    }
    #endif

    // MARK: - Totals

    /// Monthly and yearly totals of active subscriptions in the display currency. Unknown currencies
    /// are excluded and counted in `unconvertibleCount`; `totalIsConverted` is true only when a
    /// foreign subscription actually converted.
    private func calculateTotals(in currency: String = CurrencyManager.shared.selectedCurrency) {
        let charging = subscriptions.charging
        let rates = CurrencyManager.shared.rates
        let display = MoneyFormat.normalizedCode(currency)
        var monthly: Decimal = 0
        var converted = false
        var excluded = 0
        for sub in charging {
            if let value = rates.convert(sub.monthlyCost, from: sub.currency, to: currency) {
                monthly += value
                if MoneyFormat.normalizedCode(sub.currency) != display { converted = true }
            } else {
                excluded += 1
            }
        }
        totalIsConverted = converted
        unconvertibleCount = excluded
        totalMonthlySpend = monthly
        totalAnnualSpend = monthly * 12
    }

    // MARK: - Computed Properties
    
    /// What is being paid for (see `charging`): the list behind the totals above.
    var activeSubscriptions: [Subscription] { subscriptions.charging }


}

// MARK: - Notification Names

