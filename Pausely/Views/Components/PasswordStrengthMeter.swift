import SwiftUI

// MARK: - Password Strength
enum PasswordStrength: Int {
    case weak = 0
    case fair = 1
    case strong = 2

    static func evaluate(_ password: String) -> PasswordStrength {
        let score = rulesMet(password)
        switch score {
        case 0...2: return .weak
        case 3:     return .fair
        default:    return .strong
        }
    }

    static func rulesMet(_ password: String) -> Int {
        var score = 0
        if password.count >= 8 { score += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        return score
    }

    static let minimumLength = 8

    var color: Color {
        switch self {
        case .weak:  return .red
        case .fair:  return .yellow
        case .strong: return .green
        }
    }

    var label: String {
        switch self {
        case .weak:   return "Weak"
        case .fair:   return "Fair"
        case .strong: return "Strong"
        }
    }
}

// MARK: - Password Strength Meter View
struct PasswordStrengthMeter: View {
    let password: String

    private var strength: PasswordStrength {
        PasswordStrength.evaluate(password)
    }

    private var progress: CGFloat {
        let rules = PasswordStrength.rulesMet(password)
        return CGFloat(rules) / 4.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(strength.color)
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.easeInOut(duration: 0.2), value: progress)
                }
            }
            .frame(height: 4)

            // Strength label
            HStack {
                Text(strength.label)
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(strength.color)

                Spacer()
            }

            // Rules checklist
            VStack(alignment: .leading, spacing: 3) {
                RuleRow(
                    text: "8+ characters",
                    isMet: password.count >= PasswordStrength.minimumLength
                )
                RuleRow(
                    text: "Uppercase",
                    isMet: password.range(of: "[A-Z]", options: .regularExpression) != nil
                )
                RuleRow(
                    text: "Lowercase",
                    isMet: password.range(of: "[a-z]", options: .regularExpression) != nil
                )
                RuleRow(
                    text: "Number",
                    isMet: password.range(of: "[0-9]", options: .regularExpression) != nil
                )
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Rule Row
private struct RuleRow: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(isMet ? Color.semanticSuccess : Color.white.opacity(0.3))

            Text(text)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(isMet ? .white : Color.white.opacity(0.5))

            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        PasswordStrengthMeter(password: "weak")
        PasswordStrengthMeter(password: "Fair1234")
        PasswordStrengthMeter(password: "StrongPass1")
    }
    .padding()
    .background(Color.black)
}
