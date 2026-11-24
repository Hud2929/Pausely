import SwiftUI

/// Above the tabs when the build has no account server to talk to (no Supabase address in its
/// settings): what is added here goes nowhere. A build from the App Store always has one.
struct DemoModeBanner: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            StateMark(state: .decide)
            Text("Demo mode: nothing is saved")
                .font(.subheadline)
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Layout.margin)
        .padding(.vertical, 10)
        .background(Color.inkRaised.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Hairline() }
        .accessibilityElement(children: .combine)
    }
}
