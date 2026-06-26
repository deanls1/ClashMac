import SwiftUI

enum VergePolicyStyle {
    static func color(for policy: String) -> Color {
        let upper = policy.uppercased()
        if upper == "DIRECT" { return .primary }
        if upper == "REJECT" || upper.hasPrefix("REJECT-") { return VergeColor.danger }
        if policy.localizedCaseInsensitiveContains("google") { return Color(red: 0.16, green: 0.65, blue: 0.27) }
        if policy.localizedCaseInsensitiveContains("codeium") { return VergeColor.accent }
        if policy.localizedCaseInsensitiveContains("cursor") { return VergeColor.accent }
        if policy.localizedCaseInsensitiveContains("netflix") { return VergeColor.danger }
        if policy.localizedCaseInsensitiveContains("apple") { return .primary }
        let hash = abs(policy.hashValue)
        let hues: [Color] = [
            Color(red: 0.18, green: 0.56, blue: 1.0),
            Color(red: 0.55, green: 0.36, blue: 0.96),
            Color(red: 0.24, green: 0.72, blue: 0.55),
            Color(red: 0.95, green: 0.45, blue: 0.22),
        ]
        return hues[hash % hues.count]
    }

    static func icon(for policy: String) -> String? {
        if policy.localizedCaseInsensitiveContains("google") { return "g.circle.fill" }
        if policy.uppercased() == "DIRECT" { return "globe" }
        return nil
    }
}

struct VergePolicyLabel: View {
    let policy: String

    var body: some View {
        HStack(spacing: 4) {
            if let icon = VergePolicyStyle.icon(for: policy) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(VergePolicyStyle.color(for: policy))
            }
            Text(policy)
                .font(VergeTypography.captionMedium)
                .foregroundStyle(VergePolicyStyle.color(for: policy))
        }
    }
}

enum VergeRelativeTime {
    static func chinese(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
