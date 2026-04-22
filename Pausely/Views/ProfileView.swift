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
                    
                    // Settings Section
                    SettingsSection(
                        onNotifications: { showingNotifications = true },
                        onCurrency: { showingCurrency = true },
                        onPrivacy: { showingPrivacy = true },
                        onHelp: { showingHelp = true }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    
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
    }
}

// MARK: - Profile Header Card
struct ProfileHeaderCard: View {
    let user: User?
    let isPremium: Bool
    let subscriptionCount: Int

    var body: some View {
        VStack(spacing: 24) {
            // Avatar with artistic ring
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    BrandColors.primary.opacity(0.3 - Double(i) * 0.1),
                                    BrandColors.secondary.opacity(0.2 - Double(i) * 0.05),
                                    BrandColors.primary.opacity(0.3 - Double(i) * 0.1)
                                ],
                                center: .center
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 140 + CGFloat(i * 20), height: 140 + CGFloat(i * 20))
                        .rotationEffect(.degrees(Double(i) * 45))
                }

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [BrandColors.primary, BrandColors.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 110)
                        .shadow(color: BrandColors.primary.opacity(0.4), radius: 20, x: 0, y: 10)

                    Text(user?.initials ?? "U")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                }

                if isPremium {
                    ZStack {
                        Circle()
                            .fill(BrandColors.accent)
                            .frame(width: 36, height: 36)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    .offset(x: 45, y: -45)
                    .accessibilityLabel("Pro member")
                }
            }
            .frame(height: 180)

            // User info
            VStack(spacing: 6) {
                Text(user?.displayName ?? "User")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                if let email = user?.email, !email.isEmpty {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(TextColors.secondary)
                }

                if isPremium {
                    PremiumBadge(text: "PRO MEMBER", badgeColor: BrandColors.accent)
                        .padding(.top, 4)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(BackgroundColors.secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
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
                    .font(.system(size: 24))
                    .foregroundColor(BrandColors.accent)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pro Member")
                        .font(.headline.bold())
                        .foregroundColor(.white)

                    Text("Member since \(memberSinceText)")
                        .font(.subheadline)
                        .foregroundColor(TextColors.secondary)
                }
                
                Spacer()
                
                PremiumBadge(text: "ACTIVE", badgeColor: SemanticColors.success)
            }
            
            PremiumDivider()
            
            HStack(spacing: 24) {
                ProFeatureItem(icon: "infinity", text: "Unlimited")
                ProFeatureItem(icon: "pause.circle", text: "Smart Pause")
                ProFeatureItem(icon: "chart.bar", text: "Insights")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            BrandColors.accent.opacity(0.15),
                            BrandColors.primary.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(BrandColors.accent.opacity(0.3), lineWidth: 1)
                )
        )
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
                .foregroundColor(BrandColors.accent)

            Text(text)
                .font(.caption)
                .foregroundColor(TextColors.secondary)
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
            VStack(spacing: 16) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(BrandColors.primary.opacity(0.2))
                            .frame(width: 52, height: 52)
                        
                        Image(systemName: "crown.fill")
                            .font(.system(size: 24))
                            .foregroundColor(BrandColors.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Upgrade to Pro")
                            .font(.headline.bold())
                            .foregroundColor(.white)

                        Text("Unlock unlimited subscriptions and more")
                            .font(.subheadline)
                            .foregroundColor(TextColors.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(BrandColors.primary)
                }
                
                // Benefits
                HStack(spacing: 16) {
                    BenefitPill(text: "Unlimited")
                    BenefitPill(text: "Smart Pause")
                    BenefitPill(text: "Export")
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(BackgroundColors.secondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(BrandColors.primary.opacity(0.3), lineWidth: 1)
                    )
            )
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
            .foregroundColor(BrandColors.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(BrandColors.primary.opacity(0.15))
            )
    }
}

// MARK: - Profile Stats Grid
struct ProfileStatsGrid: View {
    @ObservedObject var store: SubscriptionStore
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ProfileStatBox(
                value: "\(store.subscriptions.count)",
                label: "Subscriptions",
                icon: "list.bullet.rectangle",
                color: BrandColors.primary
            )
            
            ProfileStatBox(
                value: formatCurrency(store.totalMonthlySpend),
                label: "Monthly",
                icon: "calendar",
                color: BrandColors.secondary
            )
            
            ProfileStatBox(
                value: "12",
                label: "Categories",
                icon: "folder",
                color: SemanticColors.info
            )
            
            ProfileStatBox(
                value: "98%",
                label: "Uptime",
                icon: "checkmark.shield",
                color: SemanticColors.success
            )
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Profile Stat Box
struct ProfileStatBox: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text(label)
                    .font(.subheadline)
                    .foregroundColor(TextColors.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(BackgroundColors.secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Settings Section
struct SettingsSection: View {
    let onNotifications: () -> Void
    let onCurrency: () -> Void
    let onPrivacy: () -> Void
    let onHelp: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                SettingsRow(icon: "bell.fill", title: "Notifications", color: SemanticColors.warning, action: onNotifications)
                SettingsRow(icon: "dollarsign.circle.fill", title: "Currency", value: "USD", color: SemanticColors.success, action: onCurrency)
                SettingsRow(icon: "lock.fill", title: "Privacy & Security", color: SemanticColors.info, action: onPrivacy)
                SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support", color: TextColors.secondary, action: onHelp)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(BackgroundColors.secondary)
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
                        .foregroundColor(TextColors.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(TextColors.tertiary)
            }
            .padding(14)
            .background(BackgroundColors.secondary)
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
                    .fill(BackgroundColors.secondary)
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
                        .foregroundColor(TextColors.secondary)
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.subheadline)
                        .foregroundColor(TextColors.tertiary)
                }
            }
            .padding(14)
            .background(BackgroundColors.secondary)
            .scaleEffect(isPressed ? 0.98 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
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

    var body: some View {
        Button(action: {
            HapticStyle.heavy.trigger()
            action()
        }) {
            HStack {
                Image(systemName: "arrow.left.circle.fill")
                    .font(.title3)

                Text("Sign Out")
                    .font(.body.weight(.semibold))
            }
            .foregroundColor(SemanticColors.error)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(SemanticColors.error.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(SemanticColors.error.opacity(0.2), lineWidth: 1)
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
    }
}

#Preview {
    PremiumProfileView()
}
