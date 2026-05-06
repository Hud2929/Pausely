import SwiftUI

// MARK: - Prominent Compare Section
struct ComparePromoSection: View {
    @ObservedObject private var store = SubscriptionStore.shared
    @ObservedObject private var catalogService = SubscriptionCatalogService.shared
    @State private var showingCompareSheet = false
    @State private var showingCatalogCompare = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compare & Save")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)

                    Text("Find the best value before you subscribe")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.luxuryGold, .luxuryPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: "arrow.left.arrow.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }

            // Quick stats
            HStack(spacing: 12) {
                CompareStatPill(
                    icon: "list.bullet.rectangle",
                    value: "\(catalogService.catalog.count)",
                    label: "Services"
                )

                CompareStatPill(
                    icon: "folder",
                    value: "\(SubscriptionCategory.allCases.count)",
                    label: "Categories"
                )

                CompareStatPill(
                    icon: "checkmark.shield",
                    value: "\(store.subscriptions.count)",
                    label: "Yours"
                )
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    HapticStyle.medium.trigger()
                    showingCompareSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                        Text("Compare Yours")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.luxuryTeal, .luxuryPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    HapticStyle.medium.trigger()
                    showingCatalogCompare = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                        Text("Browse Catalog")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.luxuryGold.opacity(0.4),
                                    Color.luxuryPink.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .sheet(isPresented: $showingCompareSheet) {
            SubscriptionCompareView()
        }
        .sheet(isPresented: $showingCatalogCompare) {
            CatalogCategoryCompareView()
        }
    }
}

// MARK: - Compare Stat Pill
struct CompareStatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(Color.luxuryGold)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
        )
    }
}
