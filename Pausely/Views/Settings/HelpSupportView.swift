import SwiftUI
import StoreKit

struct HelpSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private func openMailto(subject: String = "") {
        var urlString = "mailto:pausely@proton.me"
        if !subject.isEmpty {
            urlString += "?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func openAppStoreReview() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if #available(iOS 18.0, *) {
                AppStore.requestReview(in: windowScene)
            } else {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
    }

    private func openSupportWebsite() {
        if let url = URL(string: AppConfig.supportURL) {
            UIApplication.shared.open(url)
        }
    }

    let faqs = [
        ("How do I add a subscription?", "Tap the + button on the Subscriptions tab and enter the details."),
        ("Can I pause a subscription?", "Yes, Pro members can pause subscriptions they're not using."),
        ("How do I change currency?", "Go to Profile > Currency and select your preferred currency."),
        ("Is my data secure?", "Yes, all your data is encrypted end-to-end and stored securely."),
        ("How do I cancel my subscription?", "Go to Profile > Subscriptions and swipe left on any item."),
        ("What is Smart Pause?", "Smart Pause analyzes your usage and suggests subscriptions to pause.")
    ]

    var filteredFAQs: [(String, String)] {
        guard !searchText.isEmpty else { return faqs }
        return faqs.filter {
            $0.0.localizedCaseInsensitiveContains(searchText) ||
            $0.1.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            PremiumBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.body.weight(.medium))
                            .foregroundColor(Color.obsidianTextSecondary)
                        }

                        Spacer()

                        Text("Help & Support")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)

                        Spacer()

                        Color.clear.frame(width: 60)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.accentMint.opacity(0.12))
                            .frame(width: 80, height: 80)

                        Image(systemName: "questionmark.bubble.fill")
                            .font(.title)
                            .foregroundColor(Color.accentMint)
                    }

                    // Search
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.body)
                            .foregroundColor(Color.obsidianTextTertiary)

                        TextField("Search help articles...", text: $searchText)
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
                    .padding(.horizontal, 20)

                    // FAQ Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FREQUENTLY ASKED QUESTIONS")
                            .font(.caption.weight(.bold))
                            .foregroundColor(Color.obsidianTextTertiary)
                            .tracking(1.5)
                            .padding(.leading, 4)
                            .padding(.horizontal, 20)

                        VStack(spacing: 8) {
                            if filteredFAQs.isEmpty {
                                Text("No results for \"\(searchText)\"")
                                    .font(.subheadline)
                                    .foregroundColor(Color.obsidianTextSecondary)
                                    .padding(.horizontal, 20)
                            } else {
                                ForEach(filteredFAQs, id: \.0) { question, answer in
                                    HelpFAQItem(question: question, answer: answer)
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                    }

                    // Contact Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CONTACT US")
                            .font(.caption.weight(.bold))
                            .foregroundColor(Color.obsidianTextTertiary)
                            .tracking(1.5)
                            .padding(.leading, 4)

                        VStack(spacing: 0) {
                            ContactRow(icon: "envelope.fill", title: "Email Support", subtitle: "pausely@proton.me") {
                                openMailto()
                            }
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 68)
                            ContactRow(icon: "globe", title: "Help Center", subtitle: "Visit our support website") {
                                openSupportWebsite()
                            }
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 68)
                            ContactRow(icon: "star.fill", title: "Rate App", subtitle: "Let us know what you think") {
                                openAppStoreReview()
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.obsidianSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 60)
                }
            }
        }
    }
}

private struct ContactRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticStyle.light.trigger()
            action()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentMint.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.callout)
                        .foregroundColor(Color.accentMint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(Color.obsidianTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color.obsidianTextTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HelpFAQItem: View {
    let question: String
    let answer: String

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                Text(answer)
                    .font(.subheadline)
                    .foregroundColor(Color.obsidianTextSecondary)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            },
            label: {
                Text(question)
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.white)
            }
        )
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .tint(Color.accentMint)
        .onChange(of: isExpanded) { _, expanded in
            if expanded { HapticStyle.light.trigger() }
        }
    }
}

// Legacy ContactButton kept for backwards compat
struct ContactButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let glowColor: Color
    let action: () -> Void

    var body: some View {
        ContactRow(icon: icon, title: title, subtitle: subtitle, action: action)
    }
}

#Preview {
    HelpSupportView()
}
