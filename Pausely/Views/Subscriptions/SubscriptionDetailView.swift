import SwiftUI

struct SubscriptionDetailView: View {
    let subscription: Subscription
    @Binding var isPresented: Bool
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var store = SubscriptionStore.shared
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirm = false
    @State private var showingCancelSheet = false
    @State private var showingPauseSheet = false
    @State private var cancellationURL: URL?

    var cardColor: Color {
        BrandColors.primary
    }

    var body: some View {
        ZStack {
            PremiumBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Top Bar
                    HStack {
                        Button(action: { isPresented = false }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.body.weight(.medium))
                            .foregroundColor(TextColors.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    // Header Card
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [cardColor.opacity(0.3), cardColor.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)

                            Text(String(subscription.name.prefix(1)))
                                .font(.title2.weight(.bold))
                                .foregroundColor(.white)
                        }

                        Text(subscription.name)
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)

                        let converted = currencyManager.convertToSelected(
                            subscription.amount,
                            from: subscription.currency
                        )
                        Text(currencyManager.format(converted))
                            .font(.title.weight(.bold))
                            .foregroundColor(cardColor)

                        Text("per \(subscription.billingFrequency.displayName.lowercased())")
                            .font(.subheadline)
                            .foregroundColor(TextColors.secondary)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(BackgroundColors.secondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(cardColor.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)

                    // Details Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Details")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)

                        VStack(spacing: 1) {
                            SubscriptionDetailRow(icon: "calendar", title: "Next Billing", value: renewalDateText)
                            SubscriptionDetailRow(icon: "tag", title: "Category", value: subscription.category ?? "Other")
                            SubscriptionDetailRow(icon: "checkmark.circle", title: "Status", value: subscription.status.displayName)
                        }
                        .padding(.horizontal, 20)
                    }

                    // Actions
                    VStack(spacing: 12) {
                        Button(action: { openCancellationPage() }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                Text("Cancel Subscription")
                            }
                            .font(.callout.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.red.opacity(0.8))
                            )
                        }

                        Button(action: { showingPauseSheet = true }) {
                            HStack {
                                Image(systemName: "pause.circle")
                                Text("Remind Me to Pause")
                            }
                            .font(.callout.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.orange.opacity(0.8))
                            )
                        }

                        Button(action: { showingEditSheet = true }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Subscription")
                            }
                            .font(.callout.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(BackgroundColors.tertiary)
                            )
                        }

                        Button(action: {
                            HapticStyle.heavy.trigger()
                            showingDeleteConfirm = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete")
                            }
                            .font(.callout.weight(.semibold))
                            .foregroundColor(SemanticColors.error)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(SemanticColors.error.opacity(0.1))
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer(minLength: 60)
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .alert("Delete Subscription?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    _ = try? await store.deleteSubscription(id: subscription.id)
                    await MainActor.run { isPresented = false }
                }
            }
        } message: {
            Text("This will permanently remove \(subscription.name) from your subscriptions.")
        }
        .sheet(isPresented: $showingEditSheet) {
            SubscriptionManagementView(subscription: subscription)
        }
        .sheet(isPresented: $showingCancelSheet) {
            if let url = cancellationURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showingPauseSheet) {
            RevolutionaryPauseSheet(
                subscription: subscription,
                onPause: { duration in
                    let reminderDate = Calendar.current.date(
                        byAdding: duration.calendarComponent,
                        value: duration.value,
                        to: Date()
                    ) ?? Date()
                    let pauseURL = SubscriptionActionManager.shared.getService(for: subscription.name)?.pauseURL
                    NotificationManager.shared.schedulePauseReminder(
                        for: subscription,
                        reminderDate: reminderDate,
                        pauseURL: pauseURL
                    )
                    showingPauseSheet = false
                },
                onDismiss: { showingPauseSheet = false }
            )
        }
    }

    private func openCancellationPage() {
        // Look up the cancellation URL from the catalog
        if let entry = SubscriptionCatalogService.shared.entry(for: subscription.bundleIdentifier ?? "") {
            if let urlString = entry.cancellationURL, let url = URL(string: urlString) {
                cancellationURL = url
                showingCancelSheet = true
                return
            }
        }

        // Fallback: search by subscription name in catalog
        if let entry = SubscriptionCatalogService.shared.catalog.first(where: {
            $0.name.lowercased() == subscription.name.lowercased() ||
            subscription.name.lowercased().contains($0.name.lowercased())
        }) {
            if let urlString = entry.cancellationURL, let url = URL(string: urlString) {
                cancellationURL = url
                showingCancelSheet = true
                return
            }
        }

        // No cancellation URL found - use App Store subscriptions page as fallback
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            cancellationURL = url
            showingCancelSheet = true
        }
    }

    var renewalDateText: String {
        guard let date = subscription.nextBillingDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
