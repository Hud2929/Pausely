import SwiftUI

// MARK: - Pausely Custom Tab Bar

struct PauselyTabItem {
    let tag: Int
    let icon: String
    let label: String
}

private let tabItems: [PauselyTabItem] = [
    PauselyTabItem(tag: 0, icon: "house.fill",           label: "Home"),
    PauselyTabItem(tag: 1, icon: "creditcard.fill",      label: "Subs"),
    PauselyTabItem(tag: 2, icon: "sparkles",              label: "Analysis"),
    PauselyTabItem(tag: 3, icon: "person.fill",          label: "Profile"),
]

struct PauselyTabBar: View {
    @Binding var selectedTab: Int
    var badgeCounts: [Int: Int] = [:]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabItems, id: \.tag) { item in
                TabBarButton(
                    item: item,
                    isSelected: selectedTab == item.tag,
                    badgeCount: badgeCounts[item.tag] ?? 0
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                        selectedTab = item.tag
                    }
                    HapticStyle.light.trigger()
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 8)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

private struct TabBarButton: View {
    let item: PauselyTabItem
    let isSelected: Bool
    let badgeCount: Int
    let action: () -> Void

    private var accessLabel: String {
        switch item.tag {
        case 0: return "Dashboard"
        case 1: return "Subscriptions"
        case 2: return "Insights"
        case 3: return "Profile"
        default: return "Tab \(item.tag + 1)"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.accentMint.opacity(0.14))
                                .frame(width: 36, height: 28)
                                .transition(.scale.combined(with: .opacity))
                        }
                        Image(systemName: item.icon)
                            .font(.system(size: 18, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? Color.accentMint : Color.obsidianTextSecondary)
                            .scaleEffect(isSelected ? 1.08 : 1)
                    }

                    if badgeCount > 0 {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 7, height: 7)
                            .offset(x: 14, y: -4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(item.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Color.accentMint : Color.obsidianTextTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(badgeCount > 0 ? "\(accessLabel), \(badgeCount) alert\(badgeCount == 1 ? "" : "s")" : accessLabel)
        .animation(.spring(response: 0.3, dampingFraction: 0.72), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: badgeCount)
    }
}
