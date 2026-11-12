import Foundation

/// Launch arguments used by UI tests, App Store captures and demos.
///
/// They exist in DEBUG builds only. A release build answers false to every one of them, so nothing
/// here can change what a customer sees: no screen without an account, no skipped age check.
enum LaunchFlag: String {
    /// UI tests are driving the app: no release notes or review prompts over the screen.
    case uiTesting = "--uitesting"
    /// The main app with demo data and no account.
    case demoMode = "--demo-mode"
    /// App Store captures, without the one-time permission card.
    case screenshots = "--screenshots"

    var isSet: Bool { Self.isSet(rawValue) }

    /// Any DEBUG launch argument, such as the `--demo-…` screens.
    static func isSet(_ argument: String) -> Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains(argument)
        #else
        return false
        #endif
    }

    /// The value of `--name=value`, or "" for a bare `--name`. Nil when it isn't there, and always
    /// nil in a release build.
    static func value(of name: String) -> String? {
        #if DEBUG
        for argument in ProcessInfo.processInfo.arguments {
            if argument == name { return "" }
            if argument.hasPrefix(name + "=") { return String(argument.dropFirst(name.count + 1)) }
        }
        #endif
        return nil
    }
}
