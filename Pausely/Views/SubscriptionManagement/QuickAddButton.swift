import SwiftUI

struct QuickAddButton: View {
    let minutes: Int
    let subscriptionName: String
    @State private var manager = ScreenTimeManager.shared

    var label: String {
        if minutes >= 60 {
            return "+\(minutes / 60)h"
        } else {
            return "+\(minutes)m"
        }
    }

    var body: some View {
        Button(action: {
            manager.updateUsage(minutes: minutes, for: subscriptionName)
            HapticStyle.light.trigger()
        }) {
            Label(label, systemImage: "plus.circle")
                .font(.caption.weight(.medium))
        }
        .buttonStyle(.bordered)
        .tint(.luxuryPurple)
    }
}
