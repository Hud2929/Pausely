import SwiftUI
import TipKit
import UserNotifications

/// Sets the layout direction only when a language was chosen in the app.
struct ChosenDirection: ViewModifier {
    let direction: LayoutDirection?
    @Environment(\.layoutDirection) private var inherited

    func body(content: Content) -> some View {
        // One branch, so the app keeps its place when the language changes: an if/else here rebuilt every screen,
        // and choosing a language in Profile landed on Home (the reach rating of 2026-11-23).
        content
            .environment(\.layoutDirection, direction ?? inherited)
            .onAppear { SceneDirection.apply(direction) }
            .onChange(of: direction) { _, now in SceneDirection.apply(now) }
    }
}

/// The chosen direction on every window scene's traits. Sheets, alerts and the system's bars take theirs from
/// UIKit, not from SwiftUI's environment: with Arabic chosen in the app on an English iPhone, Find in Email,
/// its forms and the Language sheet stayed left to right (the reach rating of 2026-11-23).
@MainActor
enum SceneDirection {
    static func apply(_ direction: LayoutDirection?) {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            if let direction {
                scene.traitOverrides.layoutDirection = direction == .rightToLeft ? .rightToLeft : .leftToRight
            } else if scene.traitOverrides.contains(UITraitLayoutDirection.self) {
                scene.traitOverrides.remove(UITraitLayoutDirection.self)
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Before the phone's first unlock: nothing else is set up (see `PauselyApp.init`).
        if LockedLaunchDelegate.isActive {
            LockedLaunchDelegate.shared.start()
            return true
        }
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor.label
        ]

        // Once content scrolls under the bar it gets a solid background, so text never runs
        // under the buttons; at the top it stays transparent.
        let scrolledAppearance = UINavigationBarAppearance()
        scrolledAppearance.configureWithDefaultBackground()
        scrolledAppearance.backgroundColor = UIColor(Color.ink).withAlphaComponent(0.92)
        scrolledAppearance.shadowColor = .clear
        scrolledAppearance.titleTextAttributes = appearance.titleTextAttributes

        UINavigationBar.appearance().standardAppearance = scrolledAppearance
        UINavigationBar.appearance().compactAppearance = scrolledAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // Switches: green would read as "money kept", so an "on" switch is a quiet grey.
        UISwitch.appearance().onTintColor = UIColor(Color.inkTextMuted)

        // iOS 26 draws the tab bar as Liquid Glass by itself. Earlier versions get a solid ink bar.
        if #unavailable(iOS 26) {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor(Color.ink)
            tabBarAppearance.shadowColor = UIColor(Color.line)
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }

        // Configure TipKit for contextual tips
        TipKitConfiguration.configure()

        // The app switcher shows the app's name, not what someone pays for.
        PrivacyCover.install()

        // Reminder taps and their Keep / Review buttons. Set before launch finishes so a tap that
        // launched the app is delivered.
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        ReminderActions.registerCategories()

        // Handle URL if app was launched via deep link
        if let url = launchOptions?[.url] as? URL {
            handleDeepLink(url)
        }

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        handleDeepLink(url)
        return true
    }

    private func handleDeepLink(_ url: URL) {
        DeepLinkManager.shared.process(url)
    }
}

/// The launch screen: the pause mark on ink, for a little over half a second. No tagline, no spinner.
struct SplashScreen: View {
    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            PauseMark(height: 44)
                .foregroundStyle(Color.paper)
        }
    }
}
