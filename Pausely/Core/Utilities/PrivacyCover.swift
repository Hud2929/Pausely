import UIKit

/// What the app switcher shows for Pausely: the app's name on ink, not a list of what someone pays
/// for. iOS takes its picture of an app just after it goes to the background, so the cover is put over
/// every window at that moment and taken off when the app comes back. It is not shown for the brief
/// interruptions that only make an app inactive (Control Center, a permission prompt, Apple's purchase
/// sheet): there the screen behind stays as it is.
@MainActor
enum PrivacyCover {
    private static let tag = 0x50_41_55_53   // "PAUS"
    private static var observers: [NSObjectProtocol] = []

    /// Called once at launch.
    static func install() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { show() }
        })
        for name in [UIApplication.willEnterForegroundNotification, UIApplication.didBecomeActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { hide() }
            })
        }
    }

    private static var windows: [UIWindow] {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
    }

    static func show() {
        for window in windows where window.viewWithTag(tag) == nil {
            window.addSubview(makeCover(frame: window.bounds))
        }
    }

    static func hide() {
        for window in windows { window.viewWithTag(tag)?.removeFromSuperview() }
    }

    static func makeCover(frame: CGRect) -> UIView {
        let cover = UIView(frame: frame)
        cover.tag = tag
        cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cover.backgroundColor = UIColor(red: 0x0A / 255, green: 0x0B / 255, blue: 0x0D / 255, alpha: 1)   // Palette.ink
        cover.isAccessibilityElement = false

        let name = UILabel()
        name.text = "Pausely"
        name.font = UIFont(descriptor: UIFontDescriptor.preferredFontDescriptor(withTextStyle: .title1)
            .withDesign(.serif)?.withSymbolicTraits(.traitBold) ?? .preferredFontDescriptor(withTextStyle: .title1), size: 0)
        name.textColor = UIColor(red: 0xF5 / 255, green: 0xF4 / 255, blue: 0xF0 / 255, alpha: 1)             // Palette.text
        name.translatesAutoresizingMaskIntoConstraints = false
        cover.addSubview(name)
        NSLayoutConstraint.activate([name.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
                                     name.centerYAnchor.constraint(equalTo: cover.centerYAnchor)])
        return cover
    }
}
