import SwiftUI

/// The four things a password must have. One list for the sign-up form, the reset screen and the checks
/// behind their buttons.
enum PasswordStrength {
    static let minimumLength = 8

    /// How many of the four rules the password meets; 4 means it's accepted.
    static func rulesMet(_ password: String) -> Int {
        rules(password).filter(\.met).count
    }

    static func rules(_ password: String) -> [(text: String, met: Bool)] {
        [
            (L10n.string("8 or more characters"), password.count >= minimumLength),
            (L10n.string("A capital letter"), password.range(of: "[A-Z]", options: .regularExpression) != nil),
            (L10n.string("A small letter"), password.range(of: "[a-z]", options: .regularExpression) != nil),
            (L10n.string("A number"), password.range(of: "[0-9]", options: .regularExpression) != nil)
        ]
    }
}

/// What the password still needs, ticked off as it's typed. No "weak" or "strong" verdict: the rules are
/// the whole test, so the rules are what's shown.
struct PasswordStrengthMeter: View {
    let password: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(PasswordStrength.rules(password).enumerated()), id: \.offset) { _, rule in
                HStack(spacing: 8) {
                    Image(systemName: rule.met ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(rule.met ? Color.inkText : Color.inkTextFaint)
                        .accessibilityHidden(true)
                    Text(verbatim: rule.text)
                        .foregroundStyle(rule.met ? Color.inkText : Color.inkTextMuted)
                }
                .font(.footnote)
                .accessibilityElement(children: .combine)
                .accessibilityValue(rule.met ? Text("met") : Text("not met yet"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Motion.unlessReduced(Motion.touch), value: PasswordStrength.rulesMet(password))
    }
}
