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
        ("How do I add a subscription?", "Tap the + button on the Subscriptions tab, pick a service from the catalog or paste a link, then check the price and renewal date."),
        ("How many subscriptions can I track for free?", "Up to \(FreeTier.subscriptionLimit). Pausely Pro removes the limit."),
        ("How do I stop a subscription I no longer want?", "Open it from the Subscriptions tab and tap Cancel subscription. Pausely Pro guides you to the service's cancellation page. You always cancel with the service itself."),
        ("How do I change currency?", "Go to Profile > Settings > Currency and select your preferred currency."),
        ("Is my data secure?", "Your subscriptions are stored in your account and sent over encrypted connections. We never sell your data. See the Privacy Policy for details."),
        ("How do I cancel Pausely Pro?", "Pausely Pro is billed by Apple. Open Settings on your iPhone, tap your name, then Subscriptions, and choose Pausely Pro.")
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
            Color.ink.ignoresSafeArea()

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
                            .foregroundColor(Color.inkTextMuted)
                        }

                        Spacer()

                        Text("Help & Support")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.inkText)

                        Spacer()

                        Color.clear.frame(width: 60)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 80, height: 80)

                        Image(systemName: "questionmark.bubble.fill")
                            .font(.title)
                            .foregroundColor(Color.inkText)
                    }

                    // Search
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.body)
                            .foregroundColor(Color.inkTextFaint)

                        TextField("Search help articles...", text: $searchText)
                            .font(.body)
                            .foregroundStyle(Color.inkText)
                            .keyboardType(.default)
                            .submitLabel(.search)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.inkLifted)
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
                            .foregroundColor(Color.inkTextFaint)
                            .padding(.leading, 4)
                            .padding(.horizontal, 20)

                        VStack(spacing: 8) {
                            if filteredFAQs.isEmpty {
                                Text("No results for \"\(searchText)\"")
                                    .font(.subheadline)
                                    .foregroundColor(Color.inkTextMuted)
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
                            .foregroundColor(Color.inkTextFaint)
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
                                .fill(Color.inkRaised)
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
            action()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.callout)
                        .foregroundColor(Color.inkText)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.inkText)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(Color.inkTextMuted)
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color.inkTextFaint)
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
                    .foregroundColor(Color.inkTextMuted)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            },
            label: {
                Text(question)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.inkText)
            }
        )
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.inkRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .tint(Color.inkText)
        .onChange(of: isExpanded) { _, expanded in
            if expanded { Feel.selection() }
        }
    }
}


#Preview {
    HelpSupportView()
}
