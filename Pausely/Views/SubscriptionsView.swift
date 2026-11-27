import SwiftUI

/// The list of everything the person pays for, grouped by when each one next charges.
struct SubscriptionsView: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @ObservedObject private var pausePlanStore = PausePlanStore.shared
    @State private var searchText = ""
    @State private var activeSheet: ActiveSheet?
    @State private var pendingRemoval: UUID?
    @State private var pendingPaywallFromPicker = false
    @ObservedObject private var payments = PaymentManager.shared
    /// Read so the list is drawn again when what waits for room changes.
    @AppStorage(TallyImporter.waitingVersionKey) private var waitingVersion = 0
    @ScaledMetric(relativeTo: .title3) private var addButtonSize: CGFloat = Layout.tapTarget
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var deepLinkedSubscription: Subscription?

    init(deepLinkedSubscription: Binding<Subscription?> = .constant(nil)) {
        self._deepLinkedSubscription = deepLinkedSubscription
    }

    enum ActiveSheet: Identifiable {
        case browser
        case detail(Subscription)
        case choose
        case paywall

        var id: String {
            switch self {
            case .browser: return "browser"
            case .detail(let sub): return "detail-\(sub.id)"
            case .choose: return "choose"
            case .paywall: return "paywall"
            }
        }
    }

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sections: [SubscriptionGroups.Section] {
        let query = trimmedSearch
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
        let shown = query.isEmpty
            ? store.subscriptions
            : store.subscriptions.filter { sub in
                sub.name.range(of: query, options: options, locale: L10n.locale) != nil
                    || (sub.paymentMethod?.range(of: query, options: options, locale: L10n.locale) != nil)
                    || (sub.notes?.range(of: query, options: options, locale: L10n.locale) != nil)
                    || SubscriptionCategory.localizedLabel(for: sub.category).range(of: query, options: options, locale: L10n.locale) != nil
                    || sub.currency.range(of: query, options: options, locale: L10n.locale) != nil
                    || sub.billingFrequency.displayName.range(of: query, options: options, locale: L10n.locale) != nil
                    || sub.status.displayName.range(of: query, options: options, locale: L10n.locale) != nil
            }
        let pending = Set(VerdictCenter.shared.pendingDecisions(rotating: pausePlanStore.activePlan).map(\.subscriptionId))
        return SubscriptionGroups.sections(shown, pending: pending, now: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            // The title stays put at ordinary text sizes. At the accessibility sizes it scrolls away
            // with the list: pinned, it and a section header left two fifths of the screen for rows.
            if !typeSize.isAccessibilitySize {
                header
                    .padding(.horizontal, Layout.margin)
                    .padding(.top, 16)
                    .frame(maxWidth: ReadableWidth.maxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
            }

            if store.subscriptions.isEmpty {
                let waiting = waitingVersion >= 0 ? TallyImporter.waitingLines() : []
                ScrollView {
                    if typeSize.isAccessibilitySize {
                        header
                            .padding(.horizontal, Layout.margin)
                            .padding(.top, 16)
                    }
                    VStack(alignment: .leading, spacing: 28) {
                        switch store.listState {
                        case .loading: ListLoading()
                        case .couldNotLoad: ListCouldNotLoad()
                        default: empty
                        }
                        if !waiting.isEmpty, !payments.isUnlocked(.unlimitedSubscriptions) {
                            WaitingSection(lines: waiting, totalCount: store.activeSubscriptions.count + waiting.count,
                                           currencyManager: currencyManager,
                                           onChoose: { activeSheet = .choose },
                                           onSeePro: { activeSheet = .paywall })
                        }
                    }
                    .padding(.horizontal, Layout.margin)
                    .padding(.top, 40)
                    .padding(.bottom, 24)
                }
                .readableScroll()
            } else {
                list
            }
        }
        .inkScreen()
        .sheet(item: $activeSheet, onDismiss: {
            if pendingPaywallFromPicker {
                pendingPaywallFromPicker = false
                activeSheet = .paywall
            }
        }) { sheet in
            switch sheet {
            case .browser:
                SubscriptionBrowserView()
            case .detail(let subscription):
                // A page on iPad: a 540-point card cut the page mid-row (the reach rating of 2026-11-23).
                SubscriptionManagementView(subscription: subscription)
                    .presentationSizing(.page)
            case .choose:
                FreeLimitPickerSheet(store: store, currencyManager: currencyManager,
                                     onSeePro: { pendingPaywallFromPicker = true })
                    .presentationSizing(.page)
            case .paywall:
                StoreKitUpgradeView(trigger: .unlimitedSubscriptions)
            }
        }
        // A widget, a search result or a link asked for one subscription. The request can be set before
        // this tab is first drawn (a tap that started the app), so it is read on arrival as well.
        .onChange(of: deepLinkedSubscription, initial: true) { _, requested in
            guard let subscription = requested else { return }
            activeSheet = .detail(subscription)
            deepLinkedSubscription = nil
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 12) {
                ScreenTitle(text: L10n.string("Subscriptions"))
                Spacer(minLength: 8)
                Button { activeSheet = .browser } label: {
                    let size = min(addButtonSize, 68)
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                        .frame(width: size, height: size)
                        .overlay(Circle().stroke(Color.outline, lineWidth: 1))
                        .contentShape(Circle())
                }
                .accessibilityLabel(Text("Add subscription"))
                .accessibilityIdentifier("addSubscriptionButton")
            }
            // Under the title and the button, so it has the whole width: beside the button, the count
            // and the total broke into four lines at the largest text sizes.
            if !store.subscriptions.isEmpty {
                let count = L10n.string("\(store.activeSubscriptions.count) subscriptions")
                let monthly = L10n.string("\(MoneyFormat.total(store.totalMonthlySpend, currencyManager.selectedCurrency, converted: store.totalIsConverted)) a month")
                Group {
                    if typeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: count).fixedSize(horizontal: false, vertical: true)
                            Text(verbatim: monthly).fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text(verbatim: count + " · " + monthly)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                if store.unconvertibleCount > 0 {
                    Text(store.unconvertibleCount == 1
                         ? L10n.string("1 subscription is in a currency without an exchange rate and isn't in this total.")
                         : L10n.string("\(store.unconvertibleCount) subscriptions are in currencies without an exchange rate and aren't in this total."))
                        .font(.footnote)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            if typeSize.isAccessibilitySize {
                header
                    .listRowInsets(EdgeInsets(top: 16, leading: Layout.margin, bottom: 0, trailing: Layout.margin))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            // Search earns its place once the list is long enough to lose something in, and stays
            // visible while a query is active so deleting a row past the threshold never locks the list.
            if store.subscriptions.count > 8 || !searchText.isEmpty {
                SearchField(text: $searchText, identifier: "subscriptionSearchField")
                    .listRowInsets(EdgeInsets(top: 12, leading: Layout.margin, bottom: 4, trailing: Layout.margin))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if sections.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("Nothing matches \"\(trimmedSearch)\"."))
                        .font(.body)
                        .foregroundStyle(Color.inkTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Text("Clear search")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.inkText)
                                .underline()
                                .tapArea(.leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                // On the screen's margin, like the field above it (it sat four points to its left).
                .listRowInsets(EdgeInsets(top: 12, leading: Layout.margin, bottom: 12, trailing: Layout.margin))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            ForEach(sections) { section in
                Section {
                    // The group's title is its first row and scrolls with it. As a section header
                    // it was pinned, and iOS 18 does not push a pinned header away: the next
                    // title slides under it, and where the list came to rest in between, two
                    // titles lay over each other ("Needs a decision" on half of "This week",
                    // seen 2026-11-17 on the first run of the app on iOS 18.0).
                    sectionTitle(section, first: section.id == sections.first?.id)
                    ForEach(section.subscriptions) { subscription in
                        SubscriptionRow(subscription: subscription, group: section.group) {
                            activeSheet = .detail(subscription)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: Layout.margin, bottom: 0, trailing: Layout.margin))
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(Color.line)
                        .asksFirst(Text("Remove \"\(subscription.name)\"?"), isPresented: removing(subscription),
                                   message: Text("This only removes it from Pausely. It won't cancel the subscription itself.")) {
                            Button("Remove", role: .destructive) {
                                Task { await store.deleteSubscription(id: subscription.id) }
                            }
                            Button("Keep", role: .cancel) {}
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button { pendingRemoval = subscription.id } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .tint(Color.due)
                            .accessibilityIdentifier("swipeRemove")
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button { activeSheet = .detail(subscription) } label: {
                                Label("Details", systemImage: "info.circle")
                            }
                            .tint(Color.inkLifted)
                        }
                    }
                }
            }

            // What was kept for later has a place on the list: it was listed nowhere, and Home's row about
            // it came and went (the rating of 2026-11-23).
            let waiting = waitingVersion >= 0 ? TallyImporter.waitingLines() : []
            if !waiting.isEmpty, !payments.isUnlocked(.unlimitedSubscriptions), searchText.isEmpty {
                Section {
                    WaitingSection(lines: waiting, totalCount: store.activeSubscriptions.count + waiting.count,
                                   currencyManager: currencyManager,
                                   onChoose: { activeSheet = .choose },
                                   onSeePro: { activeSheet = .paywall })
                        .listRowInsets(EdgeInsets(top: 20, leading: Layout.margin, bottom: 8, trailing: Layout.margin))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .readableScroll()
        .contentMargins(.bottom, 24, for: .scrollContent)
        .refreshable {
            await store.fetchSubscriptions(force: true)
        }
    }

    /// True while this row is the one being asked about: the question comes up from its row.
    private func removing(_ subscription: Subscription) -> Binding<Bool> {
        Binding(get: { pendingRemoval == subscription.id }, set: { if !$0 { pendingRemoval = nil } })
    }

    private func sectionTitle(_ section: SubscriptionGroups.Section, first: Bool) -> some View {
        HStack(spacing: 8) {
            if let state = Self.state(for: section.group) { StateMark(state: state) }
            Text(verbatim: Self.title(for: section.group))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Self.state(for: section.group)?.color ?? Color.inkTextMuted)
            Spacer()
            Text(verbatim: L10n.number(section.subscriptions.count))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.inkTextFaint)
        }
        // The gap between two groups is larger than the gap inside one.
        .padding(.top, Self.titleTopPadding(first: first))
        .padding(.bottom, 4)
        .padding(.horizontal, Layout.margin)
        .frame(maxWidth: .infinity)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        // The line under the title is the first row's; none above it.
        .listRowSeparator(.hidden, edges: .top)
        .listRowSeparatorTint(Color.line)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// Above a group's title: what the list gave a section header, so the page reads as it did.
    nonisolated static func titleTopPadding(first: Bool) -> CGFloat { first ? 12 : 34 }

    static func title(for group: SubscriptionGroups.Group) -> String {
        switch group {
        case .decide: return L10n.string("Needs a decision")
        // What the groups are: renewals within 7 and 30 days. "This month" headed December's on Nov 23 (2026-11-23).
        case .thisWeek: return L10n.string("In the next 7 days")
        case .thisMonth: return L10n.string("In the next 30 days")
        case .later: return L10n.string("Later")
        case .undated: return L10n.string("No renewal date")
        case .cancelled: return L10n.string("Cancelled")
        }
    }

    static func state(for group: SubscriptionGroups.Group) -> MoneyState? {
        switch group {
        case .decide: return .decide
        case .cancelled: return .kept
        case .thisWeek, .thisMonth, .later, .undated: return nil
        }
    }

    // MARK: - Empty

    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nothing on your list yet.")
                .font(.question(.title2))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
            Text("Add what you pay for. Pausely asks before each renewal whether it's still worth it.")
                .font(.body)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button { activeSheet = .browser } label: { Text("Add subscription") }
                .buttonStyle(.ink)
                .padding(.top, 12)
        }
    }
}

/// One subscription: its logo, its name, when it next charges, and the price in its own currency.
private struct SubscriptionRow: View {
    let subscription: Subscription
    let group: SubscriptionGroups.Group
    let onTap: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // One button, read as one sentence: a single thing to tap, swipe and hear. As a button it
        // shows the press; as a tap gesture on a stack it gave no sign of being touched.
        Button {
            Feel.selection()
            onTap()
        } label: {
            HStack(spacing: 12) {
                if typeSize.isAccessibilitySize {
                    words
                    Spacer(minLength: 8)
                } else {
                    ServiceLogoView(name: subscription.name, category: subscription.category, size: 40)
                    // The price beside the name while it takes no more than half the row; a wider
                    // one (millions of rupiah, one text size up) goes under the name. Squeezed
                    // beside it, the price broke between its currency and its figure.
                    LineOrStack(spacing: 8, lineSpacing: 2, spread: true, besideShare: 0.5) {
                        words
                        price
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: [subscription.name, subscription.billingFrequency.priced(subscription.chargeText), detail].filter { !$0.isEmpty }.joined(separator: ", ")))
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: subscription.name)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.inkText)
                .strikethrough(group == .cancelled, color: Color.inkTextFaint)
                .fixedSize(horizontal: false, vertical: true)
            Facts(detail)
                .font(.subheadline)
                .foregroundStyle(detailColor)
                .fixedSize(horizontal: false, vertical: true)
            if typeSize.isAccessibilitySize { price }
        }
    }

    /// The amount and how often, on a line. Where the two do not fit (millions of rupiah at the
    /// largest text size), "/mo" goes under the amount: beside it, it took its width first and
    /// the amount broke after its currency ("IDR", "/mo", then "8,500,000" on the next line).
    private var price: some View {
        LineOrStack(spacing: 2, lineSpacing: 0, alignment: .firstTextBaseline) {
            Text(verbatim: subscription.chargeText)
                .font(.body.monospacedDigit())
                .foregroundStyle(group == .cancelled ? Color.inkTextFaint : Color.inkText)
            Text(verbatim: subscription.billingFrequency.shortDisplay)
                .font(.footnote)
                .foregroundStyle(Color.inkTextFaint)
        }
    }

    private var detailColor: Color {
        guard group == .decide || group == .thisWeek,
              let charge = RenewalDecisions.upcomingCharge(for: subscription, now: Date()),
              Calendar.billing.calendarDays(from: Date(), to: charge.date) <= 1 else { return Color.inkTextMuted }
        return Color.due
    }

    private var detail: String {
        switch group {
        case .cancelled:
            return L10n.string("Cancelled")
        case .undated:
            return subscription.status == .trial
                ? L10n.string("Add when the free trial ends")
                : L10n.string("Add its renewal date")
        case .decide, .thisWeek, .thisMonth, .later:
            guard let charge = RenewalDecisions.upcomingCharge(for: subscription, now: Date()) else { return "" }
            let days = Calendar.billing.calendarDays(from: Date(), to: charge.date)
            let day = L10n.day(charge.date)
            let relative = L10n.whole(L10n.relativeDay(days, capitalized: true))
            return L10n.breakingAfterDots(charge.isTrialEnd ? L10n.string("Trial ends \(day) · \(relative)") : "\(day) · \(relative)")
        }
    }
}

#Preview {
    SubscriptionsView()
}

/// Subscriptions kept for when there's room on the free plan, with ways to swap or unlock all with Pro.
private struct WaitingSection: View {
    let lines: [TallyLine]
    let totalCount: Int
    let currencyManager: CurrencyManager
    let onChoose: () -> Void
    let onSeePro: () -> Void

    private var subtitle: String {
        if let risk = PaywallCase.waitingRisk(lines: lines, displayCurrency: currencyManager.selectedCurrency,
                                              proYearly: nil, proCurrency: nil, rates: currencyManager.rates) {
            let yearly = MoneyFormat.string(risk.yearlyAmount, risk.currency,
                                            locale: L10n.locale, wholeUnits: true)
            return L10n.string("About \(yearly) a year without reminders. The free plan tracks \(FreeTier.subscriptionLimit).")
        }
        return L10n.string("Kept for later: the free plan tracks \(FreeTier.subscriptionLimit). These aren't in your totals or reminders.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Waiting for room")
                    .font(.headline)
                    .foregroundStyle(Color.inkText)
                    // Wraps, never cut: "Waiting for ro…" at the largest text (2026-11-23).
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 0) {
                ForEach(lines) { line in
                    LineOrStack(spacing: 8, lineSpacing: 2, spread: true, alignment: .firstTextBaseline) {
                        Text(verbatim: line.name)
                            .font(.body)
                            .foregroundStyle(Color.inkTextMuted)
                        Text(verbatim: (line.frequency ?? .monthly).priced(MoneyFormat.string(line.amount, line.currency)))
                            .font(.subheadline)
                            .foregroundStyle(Color.inkTextFaint)
                    }
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                    Hairline()
                }
            }
            LineOrStack(spacing: 16, lineSpacing: 4) {
                Button(action: onChoose) {
                    Text("Choose which to track")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                        .tapArea(.leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chooseWaitingButton")

                Button(action: onSeePro) {
                    Text("Track all \(totalCount) with Pro")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.inkTextMuted)
                        .underline()
                        .tapArea(.leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("waitingSeeProButton")
            }
        }
    }
}
