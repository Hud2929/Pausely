import SwiftUI

// MARK: - Revolutionary Subscriptions View
// A unique timeline-based layout showing subscriptions as cards flowing through time

struct PremiumSubscriptionsView: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var selectedFilter: FilterType = .all
    @State private var searchText = ""
    @State private var activeSheet: ActiveSheet?
    @State private var cardOffset: CGFloat = 0
    @Binding var deepLinkedSubscription: Subscription?

    init(deepLinkedSubscription: Binding<Subscription?> = .constant(nil)) {
        self._deepLinkedSubscription = deepLinkedSubscription
    }

    enum ActiveSheet: Identifiable {
        case add
        case browser
        case autoDetect
        case detail(Subscription)

        var id: String {
            switch self {
            case .add: return "add"
            case .browser: return "browser"
            case .autoDetect: return "autoDetect"
            case .detail(let sub): return "detail-\(sub.id)"
            }
        }
    }

    enum FilterType: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case upcoming = "Upcoming"
    }

    enum SortOrder: String, CaseIterable {
        case renewalDate = "Renewal Date"
        case highestCost = "Highest Cost"
        case alphabetical = "A–Z"
    }

    @State private var sortOrder: SortOrder = .renewalDate
    @State private var showingSortPicker = false

    var filteredSubscriptions: [Subscription] {
        var result = store.subscriptions

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        switch selectedFilter {
        case .all: break
        case .active: result = result.filter { !$0.isPaused }
        case .upcoming: result = result.filter { ($0.daysUntilRenewal ?? 999) <= 7 }
        }

        switch sortOrder {
        case .renewalDate:
            result.sort { ($0.daysUntilRenewal ?? 999) < ($1.daysUntilRenewal ?? 999) }
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

                // Apple Subscription Scanner Button
                appleScannerButton
                    .padding(.top, 12)

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
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(filteredSubscriptions.enumerated()), id: \.element.id) { index, subscription in
                                ArtisticSubscriptionCard(
                                    subscription: subscription,
                                    index: index,
                                    onTap: { activeSheet = .detail(subscription) }
                                )
                                .padding(.horizontal, 20)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        HapticStyle.heavy.trigger()
                                        Task {
                                            try? await SubscriptionStore.shared.deleteSubscription(id: subscription.id)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        HapticStyle.medium.trigger()
                                        activeSheet = .detail(subscription)
                                    } label: {
                                        Label("Details", systemImage: "info.circle")
                                    }
                                    .tint(Color.accentMint)
                                }
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .add:
                ArtisticAddSubscriptionView()
            case .browser:
                SubscriptionBrowserView()
            case .autoDetect:
                AutoDetectView(isPresented: Binding(
                    get: { true },
                    set: { if !$0 { activeSheet = nil } }
                ))
            case .detail(let subscription):
                SubscriptionDetailView(
                    subscription: subscription,
                    isPresented: Binding(
                        get: { true },
                        set: { if !$0 { activeSheet = nil } }
                    )
                )
            }
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

                let count = store.subscriptions.filter { !$0.isPaused }.count
                Text("\(count) active")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.obsidianTextSecondary)
            }

            Spacer()

            // Sort Button
            Menu {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Button(action: { withAnimation { sortOrder = order } }) {
                        Label(order.rawValue, systemImage: sortOrder == order ? "checkmark" : "")
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

    // MARK: - Apple Subscription Scanner Button
    private var appleScannerButton: some View {
        HStack(spacing: 0) {
            Button(action: { activeSheet = .autoDetect }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.accentMint.opacity(0.2))
                            .frame(width: 36, height: 36)

                        Image(systemName: "apple.logo")
                            .font(.callout.weight(.semibold))
                            .foregroundColor(Color.accentMint)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Subscriptions")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)

                        Text("Scan from App Store")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.accentMint.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
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
                            title: filter.rawValue,
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
            return store.subscriptions.filter { !$0.isPaused }.count
        case .upcoming:
            return store.subscriptions.filter { ($0.daysUntilRenewal ?? 999) <= 7 }.count
        }
    }
}

#Preview {
    PremiumSubscriptionsView()
}
