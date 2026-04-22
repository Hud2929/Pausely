import SwiftUI

// MARK: - Legacy Theme Compatibility
// These components were part of the deleted Futuristic/Cyberpunk theme
// Providing minimal stubs to maintain compatibility with existing views

// MARK: - Cancellation Types (from deleted RevolutionaryCancellationService)
enum CancellationResult {
    case success(savings: Decimal)
    case failure(Error)
    case notAvailable

    var message: String {
        switch self {
        case .success(let savings):
            return "Cancelled! You saved \(savings.formatted(.currency(code: "USD")))"
        case .failure:
            return "Cancellation failed. Please try again."
        case .notAvailable:
            return "Cancellation not available for this subscription."
        }
    }

    var refundEligible: Bool {
        switch self {
        case .success: return true
        default: return false
        }
    }
}

enum PauseResult {
    case success(endDate: Date)
    case failure(Error)
    case notAvailable

    var message: String {
        switch self {
        case .success(let endDate):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Paused until \(formatter.string(from: endDate))"
        case .failure:
            return "Pause failed. Please try again."
        case .notAvailable:
            return "Pause not available for this subscription."
        }
    }

    var monthlySavings: Decimal? {
        switch self {
        case .success: return 0
        default: return nil
        }
    }
}

enum ResumeResult {
    case success
    case failure(Error)
}

enum RevolutionaryPauseDuration: CaseIterable {
    case oneWeek
    case twoWeeks
    case oneMonth
    case threeMonths

    var value: Int {
        switch self {
        case .oneWeek: return 1
        case .twoWeeks: return 2
        case .oneMonth: return 1
        case .threeMonths: return 3
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .oneWeek, .twoWeeks: return .weekOfYear
        case .oneMonth, .threeMonths: return .month
        }
    }

    var displayName: String {
        switch self {
        case .oneWeek: return "1 Week"
        case .twoWeeks: return "2 Weeks"
        case .oneMonth: return "1 Month"
        case .threeMonths: return "3 Months"
        }
    }
}

// MARK: - Cyber Colors (stub for deleted FuturisticTheme.CyberColors)
struct CyberColors {
    static let primary = Color(hex: "6366F1")
    static let secondary = Color(hex: "8B5CF6")
    static let accent = Color(hex: "A855F7")
    static let background = Color(hex: "0F0F1A")
    static let surface = Color(hex: "1A1A2E")
    static let cardBackground = Color(hex: "252540")
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)
    static let border = Color.white.opacity(0.08)
    static let glow = Color(hex: "6366F1")
    static let cyan = Color(hex: "06B6D4")
    static let electric = Color(hex: "6366F1")
    static let magenta = Color(hex: "EC4899")
    static let hotPink = Color(hex: "EC4899")
    static let lime = Color(hex: "84CC16")
    static let gold = Color(hex: "F59E0B")
}

// MARK: - Holographic Background (stub for deleted theme)
struct HolographicBackground: View {
    var body: some View {
        ZStack {
            Color(hex: "0F0F1A")
                .ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "6366F1").opacity(0.15), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.6
                            )
                        )
                        .frame(width: geo.size.width * 0.8)
                        .blur(radius: 60)
                        .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.1)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "8B5CF6").opacity(0.1), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: geo.size.width * 0.5
                            )
                        )
                        .frame(width: geo.size.width * 0.7)
                        .blur(radius: 80)
                        .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.3)
                }
            }
        }
    }
}

// MARK: - Futuristic Glass Card (stub for deleted theme)
struct FuturisticGlassCard<Content: View>: View {
    var glowColor: Color = CyberColors.primary
    let content: Content

    init(glowColor: Color = CyberColors.primary, @ViewBuilder content: () -> Content) {
        self.glowColor = glowColor
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "1A1A2E"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(glowColor.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Cyber Toggle (stub for deleted theme)
struct CyberToggle: View {
    @Binding var isOn: Bool
    var glowColor: Color = Color(hex: "6366F1")
    var onToggle: ((Bool) -> Void)? = nil

    var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .tint(glowColor)
            .onChange(of: isOn) { _, newValue in
                HapticStyle.light.trigger()
                onToggle?(newValue)
            }
    }
}
