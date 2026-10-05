import SwiftUI

// MARK: - Artistic Profile View
struct PremiumProfileView: View {
    @ObservedObject private var authManager = RevolutionaryAuthManager.shared
    @ObservedObject private var paymentManager = PaymentManager.shared
    @ObservedObject private var store = SubscriptionStore.shared
    @State private var showingPaywall = false
    @State private var showingNotifications = false
    @State private var showingCurrency = false
    @State private var showingPrivacy = false
    @State private var showingHelp = false
    @State private var showingExport = false
    @State private var showingWhatsNew = false
    @State private var showingWrapped = false
    @State private var showingGmailImport = false
    @State private var showingLanguage = false

    var body: some View {
        ZStack {
            PremiumBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Profile Header with artistic design
                    ProfileHeaderCard(
                        user: authManager.currentUser,
                        isPremium: paymentManager.isPremium,
                        subscriptionCount: store.subscriptions.count
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Membership Status
                    if !paymentManager.isPremium {
                        UpgradePromptCard {
                            showingPaywall = true
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .accessibilityIdentifier("upgradePromptCard")
                    } else {
                        PremiumStatusCard(
                            memberSince: authManager.currentUser?.createdAt ?? Date()
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }

                    // Stats Grid
                    ProfileStatsGrid(store: store)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // Personality Card (always visible, drives Wrapped engagement)
                    PersonalityProfileCard(subscriptions: store.activeSubscriptions) {
                        if paymentManager.isPremium {
                            showingWrapped = true
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Subscription Wrapped
                    if paymentManager.isPremium {
                        WrappedEntryCard {
                            showingWrapped = true
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }

                    // Settings Section
                    SettingsSection(
                        onNotifications: { showingNotifications = true },
                        onCurrency: { showingCurrency = true },
                        onPrivacy: { showingPrivacy = true },
                        onHelp: { showingHelp = true },
                        onExport: { showingExport = true },
                        onGmailImport: { showingGmailImport = true },
                        onLanguage: { showingLanguage = true }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    // What's New Button
                    Button(action: {
                        HapticStyle.medium.trigger()
                        showingWhatsNew = true
                    }) {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.accentMint.opacity(0.15))
                                    .frame(width: 36, height: 36)

                                Image(systemName: "sparkles")
                                    .font(.body)
                                    .foregroundColor(Color.accentMint)
                            }

                            Text("What's New")
                                .font(.body)
                                .foregroundColor(.white)

                            Spacer()

                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                                .font(.body)
                                .foregroundColor(Color.obsidianTextSecondary)

                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Color.obsidianTextTertiary)
                        }
                        .padding(14)
                        .background(Color.obsidianSurface)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .accessibilityIdentifier("whatsNewButton")

                    // About Section
                    AboutSection()
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    // Sign Out
                    SignOutButton {
                        Task {
                            await authManager.signOut()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 32)
                    .padding(.bottom, 40)
                    .accessibilityIdentifier("signOutButton")
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            StoreKitUpgradeView(currentSubscriptionCount: store.subscriptions.count)
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsSettingsView()
        }
        .sheet(isPresented: $showingCurrency) {
            CurrencySettingsView()
        }
        .sheet(isPresented: $showingPrivacy) {
            PrivacySecurityView()
        }
        .sheet(isPresented: $showingHelp) {
            HelpSupportView()
        }
        .sheet(isPresented: $showingExport) {
            ExportDataView()
        }
        .sheet(isPresented: $showingWhatsNew) {
            WhatsNewSheet()
        }
        .sheet(isPresented: $showingWrapped) {
            SubscriptionWrappedView(subscriptions: store.subscriptions)
        }
        .sheet(isPresented: $showingGmailImport) {
            GmailImportView()
        }
        .sheet(isPresented: $showingLanguage) {
            NavigationStack {
                LanguageSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showingLanguage = false }
                                .foregroundStyle(Color.accentMint)
                        }
                    }
            }
        }
    }
}

// MARK: - Profile Header Card
struct ProfileHeaderCard: View {
    let user: User?
    let isPremium: Bool
    let subscriptionCount: Int

    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.accentMint.opacity(0.15))
                    .frame(width: 72, height: 72)

                Text(user?.initials ?? "U")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.accentMint)

                if isPremium {
                    Circle()
                        .fill(Color.accentMint)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.black)
                        )
                        .offset(x: 24, y: -24)
                }
            }
            .accessibilityHidden(true)

            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user?.displayName ?? "User")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.obsidianText)

                if let email = user?.email, !email.isEmpty {
                    Text(email)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.obsidianTextSecondary)
                        .lineLimit(1)
                }

                if isPremium {
                    Text("Pro Member")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.accentMint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentMint.opacity(0.12))
                        .clipShape(Capsule())
                        .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding(20)
        .surfaceCard(cornerRadius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Profile, \(user?.displayName ?? "User"), \(isPremium ? "Pro member" : "Free tier")")
    }
}

// MARK: - Premium Status Card
struct PremiumStatusCard: View {
    let memberSince: Date
    
    var memberSinceText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: memberSince)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "crown.fill")
                    .font(.system(.title2, design: .rounded))
                    .foregroundColor(Color.accentMint)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pro Member")
                        .font(.headline.bold())
                        .foregroundColor(.white)

                    Text("Member since \(memberSinceText)")
                        .font(.subheadline)
                        .foregroundColor(Color.obsidianTextSecondary)
                }
                
                Spacer()
                
                PremiumBadge(text: "ACTIVE", badgeColor: Color.semanticSuccess)
            }
            
            PremiumDivider()
            
            HStack(spacing: 24) {
                ProFeatureItem(icon: "infinity", text: "Unlimited")
                ProFeatureItem(icon: "pause.circle", text: "Smart Pause")
                ProFeatureItem(icon: "chart.bar", text: "Insights")
            }
        }
        .padding(20)
        .surfaceCard(cornerRadius: 20)
    }
}

// MARK: - Pro Feature Item
struct ProFeatureItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(Color.accentMint)

            Text(text)
                .font(.caption)
                .foregroundColor(Color.obsidianTextSecondary)
        }
    }
}

// MARK: - Upgrade Prompt Card
struct UpgradePromptCard: View {
    let onUpgrade: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticStyle.medium.trigger()
            onUpgrade()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentMint.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: "sparkles")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.accentMint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Upgrade to Pro")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.obsidianText)

                    Text("Unlimited subscriptions & all features")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.obsidianTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.obsidianTextTertiary)
            }
            .padding(16)
            .surfaceCard(cornerRadius: 16)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = false } }
        )
    }
}

// MARK: - Benefit Pill
struct BenefitPill: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(Color.accentMint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.accentMint.opacity(0.15))
            )
    }
}

// MARK: - Profile Stats Grid
struct ProfileStatsGrid: View {
    @ObservedObject var store: SubscriptionStore

    var body: some View {
        VStack(spacing: 12) {
            // Hero row: monthly spend spans full width — the most important number
            ProfileStatHero(
                value: formatCurrency(store.totalMonthlySpend),
                label: "Monthly Spend"
            )

            // Secondary row: two equal smaller stats
            HStack(spacing: 12) {
                let subCount = store.subscriptions.count
                ProfileStatBox(
                    value: "\(subCount)",
                    label: subCount == 1 ? "subscription" : "subscriptions",
                    icon: "list.bullet.rectangle",
                    color: Color.accentMint
                )

                ProfileStatBox(
                    value: "\(store.upcomingRenewals.count)",
                    label: "renewing soon",
                    icon: "checkmark.shield",
                    color: Color.semanticSuccess
                )
            }
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        return CurrencyManager.shared.format(amount)
    }
}

// MARK: - Profile Stat Hero (full-width featured stat)
struct ProfileStatHero: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Color.accentMint)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(maxWidth: .infinity)
                .frame(height: 1)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.obsidianTextSecondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Profile Stat Box
struct ProfileStatBox: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(value)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.accentMint)
                Spacer()
                Image(systemName: icon)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(color.opacity(0.6))
            }

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(maxWidth: .infinity)
                .frame(height: 1)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.obsidianTextSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Settings Section
struct SettingsSection: View {
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @Environment(\.openURL) private var openURL
    let onNotifications: () -> Void
    let onCurrency: () -> Void
    let onPrivacy: () -> Void
    let onHelp: () -> Void
    let onExport: () -> Void
    var onGmailImport: (() -> Void)? = nil
    var onLanguage: (() -> Void)? = nil
    @AppStorage("app_language") private var appLanguage = "system"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                SettingsRow(icon: "arrow.down.circle.fill", title: "Import from App Store", color: Color.accentMint, action: {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        openURL(url)
                    }
                })
                .accessibilityIdentifier("importFromAppStoreButton")
                SettingsRow(
                    icon: "envelope.fill",
                    title: GmailSubscriptionScanner.shared.isConnected ? "Gmail Connected" : "Import from Gmail",
                    value: GmailSubscriptionScanner.shared.connectedEmail,
                    color: Color.accentMint,
                    action: { onGmailImport?() }
                )
                .accessibilityIdentifier("gmailImportButton")
                SettingsRow(icon: "bell.fill", title: "Notifications", color: Color.semanticWarning, action: onNotifications)
                    .accessibilityIdentifier("notificationsSettingsButton")
                SettingsRow(icon: "dollarsign.circle.fill", title: "Currency", value: currencyManager.selectedCurrency, color: Color.semanticSuccess, action: onCurrency)
                    .accessibilityIdentifier("currencySettingsButton")
                SettingsRow(icon: "globe", title: "Language", value: LanguageSettingsView.displayName(for: appLanguage), color: Color.accentMint, action: { onLanguage?() })
                    .accessibilityIdentifier("languageSettingsButton")
                SettingsRow(icon: "square.and.arrow.up", title: "Export Data", color: Color.semanticInfo, action: onExport)
                    .accessibilityIdentifier("exportDataButton")
                SettingsRow(icon: "lock.fill", title: "Privacy & Security", color: Color.semanticInfo, action: onPrivacy)
                    .accessibilityIdentifier("privacySecurityButton")
                SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support", color: Color.obsidianTextSecondary, action: onHelp)
                    .accessibilityIdentifier("helpSupportButton")
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.obsidianSurface)
            )
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    let color: Color
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticStyle.light.trigger()
            action()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.body)
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.body)
                    .foregroundColor(.white)

                Spacer()

                if let value = value {
                    Text(value)
                        .font(.body)
                        .foregroundColor(Color.obsidianTextSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.obsidianTextTertiary)
            }
            .padding(14)
            .background(Color.obsidianSurface)
            .scaleEffect(isPressed ? 0.98 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = false } }
        )
    }
}

// MARK: - About Section
struct AboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                AboutRow(title: "Version", value: "2.0.1")
                AboutRow(title: "Build", value: "2024.02")
                AboutRow(title: "Terms of Service", action: {
                    if let url = URL(string: "https://pausely.app/terms") {
                        UIApplication.shared.open(url)
                    }
                })
                AboutRow(title: "Privacy Policy", action: {
                    if let url = URL(string: "https://pausely.app/privacy") {
                        UIApplication.shared.open(url)
                    }
                })
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.obsidianSurface)
            )
        }
    }
}

// MARK: - About Row
struct AboutRow: View {
    let title: String
    var value: String? = nil
    var action: (() -> Void)? = nil
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticStyle.light.trigger()
            action?()
        }) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)

                Spacer()

                if let value = value {
                    Text(value)
                        .font(.body)
                        .foregroundColor(Color.obsidianTextSecondary)
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.subheadline)
                        .foregroundColor(Color.obsidianTextTertiary)
                }
            }
            .padding(14)
            .background(Color.obsidianSurface)
            .scaleEffect(isPressed ? 0.98 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
        .accessibilityHint(action == nil ? "No action available for this row" : "")
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = false } }
        )
    }
}

// MARK: - Sign Out Button
struct SignOutButton: View {
    let action: () -> Void
    @State private var isPressed = false
    @State private var showConfirm = false

    var body: some View {
        Button(action: {
            HapticStyle.medium.trigger()
            showConfirm = true
        }) {
            HStack {
                Image(systemName: "arrow.left.circle.fill")
                    .font(.title3)

                Text("Sign Out")
                    .font(.body.weight(.semibold))
            }
            .foregroundColor(Color.semanticDestructive)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.semanticDestructive.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.semanticDestructive.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = false } }
        )
        .confirmationDialog("Sign out of Pausely?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                HapticStyle.heavy.trigger()
                action()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your data is saved and will be here when you return.")
        }
    }
}

// MARK: - Wrapped Entry Card

struct WrappedEntryCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticStyle.medium.trigger()
            action()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [Color.accentMint.opacity(0.3), Color.accentMint.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 44, height: 44)
                    Image(systemName: "chart.bar.xaxis.ascending.badge.clock")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentMint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Subscription Wrapped")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Your year in subscriptions — shareable")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.obsidianTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.obsidianTextTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.obsidianSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.accentMint.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Subscription Wrapped View (Story Format)

struct SubscriptionWrappedView: View {
    let subscriptions: [Subscription]
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    @MainActor
    private var stats: WrappedStats { WrappedStats(subscriptions: subscriptions) }

    @MainActor
    private var personality: SubscriptionPersonality {
        PersonalityEngine.compute(subscriptions: subscriptions)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            // Story cards — full screen TabView
            TabView(selection: $currentPage) {
                WrappedStory1_TotalSpent(stats: stats).tag(0)
                WrappedStory2_TopService(stats: stats).tag(1)
                WrappedStory3_VsAverage(stats: stats).tag(2)
                WrappedStory4_CouldBuy(stats: stats).tag(3)
                WrappedStory5_Personality(personality: personality).tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Progress dots + controls
            VStack(spacing: 0) {
                // Progress bar strip
                HStack(spacing: 4) {
                    ForEach(0..<5) { i in
                        Capsule()
                            .fill(i <= currentPage ? Color.white : Color.white.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .frame(height: 3)
                            .animation(.easeInOut(duration: 0.25), value: currentPage)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                Spacer()

                // Share + Done
                HStack(spacing: 12) {
                    Button {
                        HapticStyle.medium.trigger()
                        shareCurrentCard()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Share")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentMint)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 80, height: 50)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .statusBar(hidden: true)
    }

    @MainActor
    private func shareCurrentCard() {
        let view: AnyView
        switch currentPage {
        case 0: view = AnyView(WrappedStory1_TotalSpent(stats: stats).frame(width: 390, height: 844))
        case 1: view = AnyView(WrappedStory2_TopService(stats: stats).frame(width: 390, height: 844))
        case 2: view = AnyView(WrappedStory3_VsAverage(stats: stats).frame(width: 390, height: 844))
        case 3: view = AnyView(WrappedStory4_CouldBuy(stats: stats).frame(width: 390, height: 844))
        default: view = AnyView(WrappedStory5_Personality(personality: personality).frame(width: 390, height: 844))
        }
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }
        let vc = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(vc, animated: true)
        }
    }
}

// MARK: - Story Card Base

private struct StoryBackground: View {
    let gradient: [Color]
    var body: some View {
        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

private struct StoryPausleyBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .bold))
            Text("pausely")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .tracking(0.5)
        }
        .foregroundStyle(Color.accentMint)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.4))
        .clipShape(Capsule())
    }
}

// MARK: - Story 1: Total Spent

private struct WrappedStory1_TotalSpent: View {
    let stats: WrappedStats
    var body: some View {
        ZStack {
            StoryBackground(gradient: [Color(hex: "#050810"), Color(hex: "#0A1A12")])
            // Glow
            Circle().fill(Color.accentMint.opacity(0.12))
                .frame(width: 400).offset(x: 100, y: -200).blur(radius: 80)

            VStack(alignment: .leading, spacing: 0) {
                HStack { StoryPausleyBadge(); Spacer() }
                    .padding(.horizontal, 32).padding(.top, 64)

                Spacer()

                VStack(alignment: .leading, spacing: 16) {
                    Text("\(stats.year) WRAPPED")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .tracking(2)

                    Text("This year,\nyou spent")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineSpacing(4)

                    Text(CurrencyManager.shared.format(stats.totalSpent))
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(Color.accentMint)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)

                    Text("on \(stats.totalCount) subscription\(stats.totalCount == 1 ? "" : "s")")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
    }
}

// MARK: - Story 2: Top Service

private struct WrappedStory2_TopService: View {
    let stats: WrappedStats
    var body: some View {
        ZStack {
            StoryBackground(gradient: [Color(hex: "#100510"), Color(hex: "#1A0A1A")])
            Circle().fill(Color.purple.opacity(0.15))
                .frame(width: 350).offset(x: -80, y: 150).blur(radius: 70)

            VStack(alignment: .leading, spacing: 0) {
                HStack { StoryPausleyBadge(); Spacer() }
                    .padding(.horizontal, 32).padding(.top, 64)

                Spacer()

                VStack(alignment: .leading, spacing: 16) {
                    Text("YOUR TOP SERVICE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .tracking(2)

                    Text(stats.topService)
                        .font(.system(size: 58, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.4)
                        .lineLimit(2)

                    Text("most expensive\nsubscription")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineSpacing(4)

                    if stats.cancelledCount > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("You cancelled \(stats.cancelledCount) subscription\(stats.cancelledCount == 1 ? "" : "s") this year")
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                .foregroundStyle(Color.white.opacity(0.8))
                        }
                        .padding(12)
                        .background(Color.green.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
    }
}

// MARK: - Story 3: vs Average

private struct WrappedStory3_VsAverage: View {
    let stats: WrappedStats

    private var localAverage: Decimal {
        CurrencyManager.shared.convertToSelected(Decimal(219), from: "USD")
    }
    private var monthlySpend: Decimal {
        stats.totalCount > 0 ? stats.totalSpent / Decimal(max(1, Calendar.current.component(.month, from: Date()))) : 0
    }
    private var isBelow: Bool {
        monthlySpend < localAverage
    }
    private var pct: Int {
        guard NSDecimalNumber(decimal: localAverage).doubleValue > 0 else { return 0 }
        let diff = abs(NSDecimalNumber(decimal: monthlySpend - localAverage).doubleValue)
        return Int((diff / NSDecimalNumber(decimal: localAverage).doubleValue) * 100)
    }

    var body: some View {
        ZStack {
            StoryBackground(gradient: isBelow
                ? [Color(hex: "#051005"), Color(hex: "#0A1A0A")]
                : [Color(hex: "#100800"), Color(hex: "#1A1000")]
            )
            Circle().fill((isBelow ? Color.green : Color.orange).opacity(0.12))
                .frame(width: 400).offset(y: 100).blur(radius: 80)

            VStack(alignment: .leading, spacing: 0) {
                HStack { StoryPausleyBadge(); Spacer() }
                    .padding(.horizontal, 32).padding(.top, 64)

                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    Text("VS. THE AVERAGE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .tracking(2)

                    Text(isBelow ? "You spend\n\(pct)% less\nthan average" : "You spend\n\(pct)% more\nthan average")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(isBelow ? Color.green : Color.orange)
                        .lineSpacing(4)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("You")
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            Spacer()
                            Text(CurrencyManager.shared.format(monthlySpend) + "/mo")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(.white)
                        }
                        HStack {
                            Text("Avg. Pausely User")
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(.white.opacity(0.5))
                            Spacer()
                            Text(CurrencyManager.shared.format(localAverage) + "/mo")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
    }
}

// MARK: - Story 4: What You Could've Bought

private struct WrappedStory4_CouldBuy: View {
    let stats: WrappedStats

    private var annual: Double {
        NSDecimalNumber(decimal: stats.totalSpent).doubleValue
    }
    private var localAnnual: Double {
        NSDecimalNumber(decimal: CurrencyManager.shared.convertToSelected(stats.totalSpent, from: CurrencyManager.shared.currentCurrency.code)).doubleValue
    }
    private func convertedPrice(_ usdPrice: Double) -> Double {
        NSDecimalNumber(decimal: CurrencyManager.shared.convertToSelected(Decimal(usdPrice), from: "USD")).doubleValue
    }

    private var comparisons: [(emoji: String, count: Int, item: String)] {
        let coffee = convertedPrice(3)
        let dinner = convertedPrice(45)
        let drinks = convertedPrice(11)
        return [
            ("☕️", coffee > 0 ? Int(localAnnual / coffee) : 0, "coffees"),
            ("🍽️", dinner > 0 ? Int(localAnnual / dinner) : 0, "dinners out"),
            ("🍹", drinks > 0 ? Int(localAnnual / drinks) : 0, "cocktails"),
        ]
    }

    var body: some View {
        ZStack {
            StoryBackground(gradient: [Color(hex: "#080510"), Color(hex: "#10080A")])
            Circle().fill(Color.blue.opacity(0.12))
                .frame(width: 350).offset(x: 120, y: -100).blur(radius: 70)

            VStack(alignment: .leading, spacing: 0) {
                HStack { StoryPausleyBadge(); Spacer() }
                    .padding(.horizontal, 32).padding(.top, 64)

                Spacer()

                VStack(alignment: .leading, spacing: 24) {
                    Text("WHAT ELSE YOU COULD'VE DONE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .tracking(1.5)

                    Text("With \(CurrencyManager.shared.format(stats.totalSpent))\nyou could've had…")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineSpacing(4)

                    VStack(spacing: 12) {
                        ForEach(comparisons.indices, id: \.self) { i in
                            let c = comparisons[i]
                            HStack(spacing: 16) {
                                Text(c.emoji)
                                    .font(.system(size: 36))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(c.count)")
                                        .font(.system(size: 36, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text(c.item)
                                        .font(.system(.caption, design: .rounded).weight(.medium))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
    }
}

// MARK: - Story 5: Personality

private struct WrappedStory5_Personality: View {
    let personality: SubscriptionPersonality

    var body: some View {
        ZStack {
            StoryBackground(gradient: [Color(hex: "#050A10"), Color(hex: "#0A1015")])
            Circle().fill(Color.accentMint.opacity(0.10))
                .frame(width: 450).offset(y: 200).blur(radius: 100)

            VStack(alignment: .leading, spacing: 0) {
                HStack { StoryPausleyBadge(); Spacer() }
                    .padding(.horizontal, 32).padding(.top, 64)

                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    Text("YOUR SUBSCRIPTION PERSONALITY")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .tracking(1.5)

                    Text(personality.emoji)
                        .font(.system(size: 72))

                    Text(personality.name)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(Color.accentMint)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)

                    Text(personality.headline)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .lineSpacing(4)

                    Text(personality.description)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .lineSpacing(3)
                        .lineLimit(4)
                }
                .padding(.horizontal, 32)

                Spacer()

                Text("Track & optimize at pausely.app")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 100)
            }
        }
    }
}

// MARK: - Wrapped Card (shareable content)

struct WrappedCard: View {
    let stats: WrappedStats

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "#0A0A0F"), Color(hex: "#0D1A14")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle glow
            Circle()
                .fill(Color.accentMint.opacity(0.08))
                .frame(width: 300, height: 300)
                .offset(x: 80, y: -120)
                .blur(radius: 60)

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("pausely")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.accentMint)
                            .tracking(1)
                        Text("\(stats.year) WRAPPED")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.accentMint)
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)

                Spacer()

                // Hero number
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Spent")
                        .font(.system(size: 13, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(.horizontal, 28)
                    Text(CurrencyManager.shared.format(stats.totalSpent))
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.accentMint, Color.accentMint.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, 28)
                }

                Spacer()

                // Stats grid
                HStack(spacing: 0) {
                    WrappedStat(value: "\(stats.totalCount)", label: "services\ntracked")
                    Divider().background(Color.white.opacity(0.1)).frame(height: 44)
                    WrappedStat(value: stats.topService, label: "top\nservice")
                    Divider().background(Color.white.opacity(0.1)).frame(height: 44)
                    WrappedStat(value: "\(stats.cancelledCount)", label: "cancelled\nthis year")
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                .background(Color.white.opacity(0.04))

                // Footer
                HStack {
                    Text("Track smarter. Save more.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.3))
                    Spacer()
                    Text("pausely.app")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.accentMint.opacity(0.6))
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
            }
        }
        .frame(width: 380, height: 520)
    }
}

private struct WrappedStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Wrapped Stats

struct WrappedStats {
    let year: Int
    let totalSpent: Decimal
    let totalCount: Int
    let cancelledCount: Int
    let topService: String
    let topCategory: String

    init(subscriptions: [Subscription]) {
        year = Calendar.current.component(.year, from: Date())
        let active = subscriptions.filter { $0.status == .active || $0.status == .trial }
        let yearStart = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        let cancelled = subscriptions.filter {
            $0.status == .cancelled &&
            $0.updatedAt >= yearStart
        }
        totalCount = active.count
        cancelledCount = cancelled.count
        let monthsThisYear = max(1, Calendar.current.component(.month, from: Date()))
        let monthly = active.reduce(Decimal(0)) { $0 + $1.monthlyCost }
        totalSpent = monthly * Decimal(monthsThisYear)
        topService = active.max(by: { $0.monthlyCost < $1.monthlyCost })?.name ?? "–"
        let grouped = Dictionary(grouping: active) { $0.category ?? "Other" }
        topCategory = grouped.max(by: { a, b in
            a.value.reduce(Decimal(0)) { $0 + $1.monthlyCost } < b.value.reduce(Decimal(0)) { $0 + $1.monthlyCost }
        })?.key ?? "–"
    }
}

#Preview {
    PremiumProfileView()
}
