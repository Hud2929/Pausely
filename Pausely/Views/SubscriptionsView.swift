import SwiftUI

// MARK: - Revolutionary Subscriptions View
// A unique timeline-based layout showing subscriptions as cards flowing through time

struct PremiumSubscriptionsView: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var selectedFilter: FilterType = .all
    @State private var searchText = ""
    @State private var activeSheet: ActiveSheet?
    @Binding var deepLinkedSubscription: Subscription?

    init(deepLinkedSubscription: Binding<Subscription?> = .constant(nil)) {
        self._deepLinkedSubscription = deepLinkedSubscription
    }

    enum ActiveSheet: Identifiable {
        case add
        case browser
        case detail(Subscription)

        var id: String {
            switch self {
            case .add: return "add"
            case .browser: return "browser"
            case .detail(let sub): return "detail-\(sub.id)"
            }
        }
    }

    enum FilterType: String, CaseIterable {
        case all, active, upcoming

        var title: String {
            switch self {
            case .all: return L10n.string("All")
            case .active: return L10n.string("Active")
            case .upcoming: return L10n.string("Upcoming")
            }
        }
    }

    enum SortOrder: String, CaseIterable {
        case renewalDate, highestCost, alphabetical

        var title: String {
            switch self {
            case .renewalDate: return L10n.string("Renewal Date")
            case .highestCost: return L10n.string("Highest Cost")
            case .alphabetical: return L10n.string("A–Z")
            }
        }
    }

    @State private var sortOrder: SortOrder = .renewalDate
    @State private var pendingRemoval: Subscription?

    /// Still charging: active or in a trial, and not paused. Cancelled and expired ones aren't "active".
    static func isLive(_ subscription: Subscription) -> Bool {
        (subscription.status == .active || subscription.status == .trial) && !subscription.isPaused
    }

    /// Renews within the next week (never a date already past).
    static func isUpcoming(_ subscription: Subscription) -> Bool {
        guard isLive(subscription), let days = subscription.daysUntilRenewal else { return false }
        return (0...7).contains(days)
    }

    var filteredSubscriptions: [Subscription] {
        var result = store.subscriptions

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        switch selectedFilter {
        case .all: break
        case .active: result = result.filter(Self.isLive)
        case .upcoming: result = result.filter(Self.isUpcoming)
        }

        switch sortOrder {
        case .renewalDate:
            // Next renewal first; subscriptions that no longer renew go last.
            let key: (Subscription) -> Int = { sub in
                guard Self.isLive(sub), let days = sub.daysUntilRenewal, days >= 0 else { return Int.max }
                return days
            }
            result.sort { key($0) < key($1) }
        case .highestCost:
            result.sort { $0.monthlyCost > $1.monthlyCost }
        case .alphabetical:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        return result
    }

    var body: some View {
        ZStack {
            PremiumBackground()

            VStack(spacing: 0) {
                // Header
                subscriptionsHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Search & Filter
                searchAndFilterSection
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                // Subscription Cards
                if filteredSubscriptions.isEmpty {
                    EmptySubscriptionsArtisticView {
                        activeSheet = .browser
                    }
                    .padding(.top, 40)
                } else {
                    // A List, not a ScrollView: swipe actions only work on List rows.
                    List {
                        ForEach(Array(filteredSubscriptions.enumerated()), id: \.element.id) { index, subscription in
                            ArtisticSubscriptionCard(
                                subscription: subscription,
                                index: index,
                                onTap: { activeSheet = .detail(subscription) }
                            )
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                // Not role: .destructive, which would animate the row away before the
                                // person confirms.
                                Button {
                                    HapticStyle.heavy.trigger()
                                    pendingRemoval = subscription
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .tint(Color.semanticDestructive)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    HapticStyle.medium.trigger()
                                    activeSheet = .detail(subscription)
                                } label: {
                                    Label("Details", systemImage: "info.circle")
                                }
                                .tint(Color.accentMint)
                            }
                        }
                        // Room above the floating tab bar.
                        Color.clear
                            .frame(height: 100)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    .contentMargins(.top, 16, for: .scrollContent)
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .add:
                ArtisticAddSubscriptionView()
            case .browser:
                SubscriptionBrowserView()
            case .detail(let subscription):
                SubscriptionManagementView(subscription: subscription)
            }
        }
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
        .onChange(of: deepLinkedSubscription) { oldValue, newValue in
            if oldValue == nil, let subscription = newValue {
                activeSheet = .detail(subscription)
                deepLinkedSubscription = nil
            }
        }
    }

    private var subscriptionsHeader: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SUBSCRIPTIONS")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.obsidianTextTertiary)
                    .tracking(2)

                Text(currencyManager.format(store.totalMonthlySpend))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.accentMint)

                let count = store.subscriptions.filter(Self.isLive).count
                Text("\(count) active")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
            }

            Spacer()

            // Sort Button
            Menu {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Button(action: { withAnimation { sortOrder = order } }) {
                        if sortOrder == order {
                            Label(order.title, systemImage: "checkmark")
                        } else {
                            Text(order.title)
                        }
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.obsidianElevated)
                        .frame(width: 40, height: 40)
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.callout.weight(.semibold))
                        .foregroundColor(Color.obsidianTextSecondary)
                }
            }
            .accessibilityLabel("Sort subscriptions")

            // Add Button - opens premium catalog browser
            Button(action: { activeSheet = .browser }) {
                ZStack {
                    Circle()
                        .fill(Color.accentMint)
                        .frame(width: 40, height: 40)

                    Image(systemName: "plus")
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.white)
                }
            }
            .accessibilityLabel("Add subscription")
            .accessibilityIdentifier("addSubscriptionButton")
        }
    }

    private var searchAndFilterSection: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .foregroundColor(Color.obsidianTextTertiary)

                TextField("Search subscriptions...", text: $searchText)
                    .font(.body)
                    .foregroundColor(.white)
                    .keyboardType(.default)
                    .submitLabel(.search)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.obsidianElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )

            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FilterType.allCases, id: \.self) { filter in
                        SubscriptionFilterPill(
                            title: filter.title,
                            count: countForFilter(filter),
                            isSelected: selectedFilter == filter
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedFilter = filter
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func countForFilter(_ filter: FilterType) -> Int {
        switch filter {
        case .all:
            return store.subscriptions.count
        case .active:
            return store.subscriptions.filter(Self.isLive).count
        case .upcoming:
            return store.subscriptions.filter(Self.isUpcoming).count
        }
    }
}

#Preview {
    PremiumSubscriptionsView()
}
