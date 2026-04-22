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
    
    var body: some View {
        ZStack {
            HolographicBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(CyberColors.electric)
                                .accessibilityLabel("Back")
                        }
                        
                        Spacer()
                        
                        Text("Help & Support")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Color.clear.frame(width: 44)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Icon
                    ZStack {
                        Circle()
                            .stroke(CyberColors.electric, lineWidth: 2)
                            .frame(width: 100, height: 100)
                            .shadow(color: CyberColors.electric.opacity(0.5), radius: 20, x: 0, y: 0)
                        
                        Image(systemName: "questionmark.bubble.fill")
                            .font(.system(size: 40))
                            .foregroundColor(CyberColors.electric)
                    }
                    .padding(.top, 20)
                    
                    // Search
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17))
                            .foregroundColor(.white.opacity(0.6))
                        
                        TextField("Search help articles...", text: $searchText)
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                            .keyboardType(.default)
                            .submitLabel(.search)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(CyberColors.electric.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    
                    // FAQ Section
                    VStack(spacing: 16) {
                        Text("FREQUENTLY ASKED QUESTIONS")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            ForEach(faqs, id: \.0) { question, answer in
                                HelpFAQItem(question: question, answer: answer)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                    
                    // Contact Section
                    VStack(spacing: 16) {
                        Text("CONTACT US")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                        
                        FuturisticGlassCard(glowColor: CyberColors.cyan) {
                            VStack(spacing: 16) {
                                ContactButton(
                                    icon: "envelope.fill",
                                    title: "Email Support",
                                    subtitle: "pausely@proton.me",
                                    glowColor: CyberColors.cyan
                                ) {
                                    openMailto()
                                }

                                Divider().background(Color.white.opacity(0.1))

                                ContactButton(
                                    icon: "message.fill",
                                    title: "Live Chat",
                                    subtitle: "Available 24/7",
                                    glowColor: CyberColors.lime
                                ) {
                                    openMailto(subject: "Live Chat Request")
                                }

                                Divider().background(Color.white.opacity(0.1))

                                ContactButton(
                                    icon: "globe",
                                    title: "Help Center",
                                    subtitle: "Visit our support website",
                                    glowColor: CyberColors.magenta
                                ) {
                                    openSupportWebsite()
                                }

                                Divider().background(Color.white.opacity(0.1))

                                ContactButton(
                                    icon: "star.fill",
                                    title: "Rate App",
                                    subtitle: "Let us know what you think",
                                    glowColor: CyberColors.gold
                                ) {
                                    openAppStoreReview()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
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
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 12)
                    .padding(.bottom, 4)
            },
            label: {
                Text(question)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
        )
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .accentColor(CyberColors.electric)
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                HapticStyle.light.trigger()
            }
        }
    }
}

struct ContactButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let glowColor: Color
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticStyle.light.trigger()
            action()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(glowColor.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(glowColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 16))
                    .foregroundColor(glowColor)
            }
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

#Preview {
    HelpSupportView()
}
