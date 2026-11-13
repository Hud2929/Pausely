import SwiftUI

/// The list of everything the person pays for, grouped by when each one next charges.
struct SubscriptionsView: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var eventLog = LifecycleEventLog.shared
    @State private var searchText = ""
    @State private var activeSheet: ActiveSheet?
    @State private var pendingRemoval: Subscription?
    @Environment(\.dynamicTypeSize) private var typeSize
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
            // The title stays put at ordinary text sizes. At the accessibility sizes it scrolls away
            // with the list: pinned, it and a section header left two fifths of the screen for rows.
            if !typeSize.isAccessibilitySize {
                header
                    .padding(.horizontal, Layout.margin)
                    .padding(.top, 16)
            }

            if store.subscriptions.isEmpty {
                ScrollView {
                    if typeSize.isAccessibilitySize {
                        header
                            .padding(.horizontal, Layout.margin)
                            .padding(.top, 16)
                    }
                    Group {
                        switch store.listState {
                        case .loading: ListLoading()
                        case .couldNotLoad: ListCouldNotLoad()
                        default: empty
                        }
                    }
                    .padding(.horizontal, Layout.margin)
                    .padding(.top, 40)
                    .padding(.bottom, 24)
                }
            } else {
                list
            }
        }
        .inkScreen()
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .browser:
                SubscriptionBrowserView()
            case .detail(let subscription):
                SubscriptionManagementView(subscription: subscription)
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
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                        .frame(width: Layout.tapTarget, height: Layout.tapTarget)
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

            // Search earns its place only once the list is long enough to lose something in.
            if store.subscriptions.count > 8 {
                SearchField(text: $searchText, identifier: "subscriptionSearchField")
                    .listRowInsets(EdgeInsets(top: 12, leading: Layout.margin, bottom: 4, trailing: Layout.margin))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if sections.isEmpty {
                Text(L10n.string("Nothing matches \"\(searchText)\"."))
                    .font(.body)
                    .foregroundStyle(Color.inkTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    // On the screen's margin, like the field above it (it sat four points to its left).
                    .listRowInsets(EdgeInsets(top: 12, leading: Layout.margin, bottom: 12, trailing: Layout.margin))
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
                            .accessibilityIdentifier("swipeRemove")
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
                Task { await store.deleteSubscription(id: subscription.id) }
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
            Text(verbatim: L10n.number(section.subscriptions.count))
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(subscription.name), \(subscription.billingFrequency.priced(subscription.chargeText)), \(detail)"))
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
              Calendar.billing.calendarDays(from: Date(), to: charge.date) <= 1 else { return Color.inkTextMuted }
        return Color.due
    }

    private var detail: String {
        switch group {
        case .cancelled:
            return L10n.string("Cancelled")
        case .undated:
            return L10n.string("Add its renewal date")
        case .decide, .thisWeek, .thisMonth, .later:
            guard let charge = RenewalDecisions.upcomingCharge(for: subscription, now: Date()) else { return "" }
            let days = Calendar.billing.calendarDays(from: Date(), to: charge.date)
            let day = charge.date.formatted(.dateTime.month(.abbreviated).day().locale(L10n.locale))
            let relative = L10n.relativeDay(days, capitalized: true)
            return charge.isTrialEnd ? L10n.string("Trial ends \(day) · \(relative)") : "\(day) · \(relative)"
        }
    }
}

#Preview {
    SubscriptionsView()
}
