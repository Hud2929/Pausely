import SwiftUI

/// The copy and action buttons for the welcome auth screen, separated so `ContentView.swift` stays focused on root routing.
struct WelcomeWallBody: View {
    let onSignUp: () -> Void
    let onSignIn: () -> Void
    let onGuest: () -> Void

    var body: some View {
        ActionScreen {
            authWallText
        } actions: {
            authWallButtons
        }
        .scrollBounceBehavior(.basedOnSize)
        .inkScreen()
    }

    private var authWallText: some View {
        VStack(alignment: .leading, spacing: 0) {
            PauseMark(height: 30)
                .foregroundStyle(Color.paper)
                .padding(.top, 48)

            Text("Welcome to Pausely")
                .font(.question(.largeTitle, weight: .bold))
                .foregroundStyle(Color.inkText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 28)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 0) {
                promise("Every renewal, before it hits", "What each subscription costs and the day it charges you")
                Hairline()
                promise("Keep it or cancel it", "A reminder before each charge, with the facts to decide")
                Hairline()
                promise("Your Savings Receipt", "Exactly what your cancellations saved you")
            }
            .padding(.top, 24)
        }
        .padding(.horizontal, Layout.margin)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var authWallButtons: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Button(action: onSignUp) { Text("Get started") }
                    .buttonStyle(.ink)
                    .accessibilityIdentifier("getStartedButton")
                Button(action: onSignIn) { Text("I already have an account") }
                    .buttonStyle(.ink(.quiet))
                    .accessibilityIdentifier("signInButton")
                Button(action: onGuest) {
                    Text("Continue without an account")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.inkTextMuted)
                        .frame(maxWidth: .infinity, minHeight: Layout.tapTarget)
                }
                .accessibilityIdentifier("welcomeGuestButton")
                #if DEBUG
                // Debug builds only (never in the App Store build): the app without an account.
                if !LaunchFlag.uiTesting.isSet {
                    Button(action: { AuthManager.shared.enterAsDebugUser() }) {
                        Text(verbatim: "Test without an account (debug build)")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.inkTextMuted)
                            .frame(maxWidth: .infinity, minHeight: Layout.tapTarget)
                    }
                    .accessibilityIdentifier("debugTestUserButton")
                }
                #endif
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, Layout.margin)
        .padding(.top, 8)
        .background(Color.ink)
    }

    private func promise(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inkText)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Color.inkTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}
