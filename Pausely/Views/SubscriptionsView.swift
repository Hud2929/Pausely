import SwiftUI

/// The list of everything the person pays for, grouped by when each one next charges.
struct PremiumSubscriptionsView: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @State private var searchText = ""
    @State private var activeSheet: ActiveSheet?
    @State private var pendingRemoval: Subscription?
    @Binding var deepLinkedSubscription: Subscription?

    init(deepLinkedSubscription: Binding<Subscription?> = .constant(nil)) {
        self._deepLinkedSubscription = deepLinkedSubscription
    }

    enum ActiveSheet: Identifiable {
        case browser
        case detail(Subscription)

        var id: String {
            switch self {
            case .browser: return "browser"
            case .detail(let sub): return "detail-\(sub.id)"
            }
        }
    }

    private var sections: [SubscriptionGroups.Section] {
        let shown = searchText.isEmpty
            ? store.subscriptions
            : store.subscriptions.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        let pending = Set(VerdictCenter.shared.pendingDecisions().map(\.subscriptionId))
        return SubscriptionGroups.sections(shown, pending: pending, now: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, Layout.margin)
                .padding(.top, 16)

            if store.subscriptions.isEmpty {
                ScrollView {
                    empty
                        .padding(.horizontal, Layout.margin)
                        .padding(.top, 40)
                        .padding(.bottom, 24)
                }
            } else {
                list
            }
        }
        .background(Color.ink.ignoresSafeArea())
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .browser:
                SubscriptionBrowserView()
            case .detail(let subscription):
                SubscriptionManagementView(subscription: subscription)
            }
        }
        .onChange(of: deepLinkedSubscription) { oldValue, newValue in
            if oldValue == nil, let subscription = newValue {
                activeSheet = .detail(subscription)
                deepLinkedSubscription = nil
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                ScreenTitle(text: L10n.string("Subscriptions"))
                if !store.subscriptions.isEmpty {
                    Text(L10n.string("\(store.activeSubscriptions.count) subscriptions") + " · "
                         + L10n.string("\(currencyManager.format(store.totalMonthlySpend)) a month"))
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTextMuted)
                }
            }
            Spacer(minLength: 8)
            Button { activeSheet = .browser } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.inkText)
                    .frame(width: Layout.tapTarget, height: Layout.tapTarget)
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .contentShape(Circle())
            }
            .accessibilityLabel(Text("Add Subscription"))
            .accessibilityIdentifier("addSubscriptionButton")
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            // Search earns its place only once the list is long enough to lose something in.
            if store.subscriptions.count > 8 {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.inkTextFaint)
                        .accessibilityHidden(true)
                    TextField("Search subscriptions...", text: $searchText)
                        .foregroundStyle(Color.inkText)
                        .submitLabel(.search)
                }
                .font(.body)
                .padding(.horizontal, 14)
                .frame(minHeight: Layout.tapTarget)
                .background(Color.inkRaised, in: RoundedRectangle(cornerRadius: Layout.tileRadius, style: .continuous))
                .listRowInsets(EdgeInsets(top: 12, leading: Layout.margin, bottom: 4, trailing: Layout.margin))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if sections.isEmpty {
                Text(L10n.string("Nothing matches \"\(searchText)\"."))
                    .font(.body)
                    .foregroundStyle(Color.inkTextMuted)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            ForEach(sections) { section in
                Section {
                    ForEach(section.subscriptions) { subscription in
                        SubscriptionRow(subscription: subscription, group: section.group) {
                            activeSheet = .detail(subscription)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: Layout.margin, bottom: 0, trailing: Layout.margin))
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(Color.line)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button { pendingRemoval = subscription } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .tint(Color.due)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button { activeSheet = .detail(subscription) } label: {
                                Label("Details", systemImage: "info.circle")
                            }
                            .tint(Color.inkLifted)
                        }
                    }
                } header: {
                    sectionHeader(section)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 24, for: .scrollContent)
        .confirmationDialog(Text("Remove \"\(pendingRemoval?.name ?? "")\"?"),
                            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
                            titleVisibility: .visible,
                            presenting: pendingRemoval) { subscription in
            Button("Remove", role: .destructive) {
                Task { try? await store.deleteSubscription(id: subscription.id) }
            }
            Button("Keep", role: .cancel) {}
        } message: { _ in
            Text("This only removes it from Pausely. It won't cancel the subscription itself.")
        }
    }

    private func sectionHeader(_ section: SubscriptionGroups.Section) -> some View {
        HStack(spacing: 8) {
            if let state = Self.state(for: section.group) { StateMark(state: state) }
            Text(verbatim: Self.title(for: section.group))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Self.state(for: section.group)?.color ?? Color.inkTextMuted)
            Spacer()
            Text(verbatim: "\(section.subscriptions.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.inkTextFaint)
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
        .padding(.horizontal, Layout.margin)
        .frame(maxWidth: .infinity)
        .background(Color.ink)
        .listRowInsets(EdgeInsets())
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    static func title(for group: SubscriptionGroups.Group) -> String {
        switch group {
        case .decide: return L10n.string("Needs a decision")
        case .thisWeek: return L10n.string("This week")
        case .thisMonth: return L10n.string("This month")
        case .later: return L10n.string("Later")
        case .undated: return L10n.string("No renewal date")
        case .paused: return L10n.string("Paused")
        case .cancelled: return L10n.string("Cancelled")
        }
    }

    static func state(for group: SubscriptionGroups.Group) -> MoneyState? {
        switch group {
        case .decide: return .decide
        case .paused: return .paused
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
            Button { activeSheet = .browser } label: { Text("Add Subscription") }
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
        // One element, not a button wrapped around text: a single thing to tap, swipe and read.
        HStack(spacing: 12) {
                if !typeSize.isAccessibilitySize {
                    ServiceLogoView(name: subscription.name, category: subscription.category, size: 40)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: subscription.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.inkText)
                        .strikethrough(group == .cancelled, color: Color.inkTextFaint)
                    Text(verbatim: detail)
                        .font(.subheadline)
                        .foregroundStyle(detailColor)
                    if typeSize.isAccessibilitySize { price }
                }
                Spacer(minLength: 8)
                if !typeSize.isAccessibilitySize { price }
            }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(subscription.name), \(subscription.chargeText) \(subscription.billingFrequency.billingPeriodLabel), \(detail)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onTap)
    }

    private var price: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
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
              Calendar.current.calendarDays(from: Date(), to: charge.date) <= 1 else { return Color.inkTextMuted }
        return Color.due
    }

    private var detail: String {
        switch group {
        case .cancelled:
            return L10n.string("Cancelled")
        case .paused:
            if let until = subscription.pausedUntil {
                return L10n.string("Paused until \(until.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale)))")
            }
            return L10n.string("Paused")
        case .undated:
            return L10n.string("Add its renewal date")
        case .decide, .thisWeek, .thisMonth, .later:
            guard let charge = RenewalDecisions.upcomingCharge(for: subscription, now: Date()) else { return "" }
            let days = Calendar.current.calendarDays(from: Date(), to: charge.date)
            let day = charge.date.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale))
            let relative = days == 0 ? L10n.string("Today") : days == 1 ? L10n.string("Tomorrow") : L10n.string("in \(days) days")
            return charge.isTrialEnd ? L10n.string("Trial ends \(day) · \(relative)") : "\(day) · \(relative)"
        }
    }
}

#Preview {
    PremiumSubscriptionsView()
}
