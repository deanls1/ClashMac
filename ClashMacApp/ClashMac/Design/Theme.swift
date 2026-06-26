import SwiftUI

// MARK: - Layout & Metrics (HIG-aligned)

enum AppLayout {
    static let panelWidth: CGFloat = 320
    static let panelMinHeight: CGFloat = 420
    static let cornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 10
    static let sectionSpacing: CGFloat = 12
    static let rowHeight: CGFloat = 36
    static let horizontalPadding: CGFloat = 16
    static let compactPadding: CGFloat = 10
}

// MARK: - Semantic Colors

enum AppColor {
    static let running = Color.green
    static let stopped = Color.secondary
    static let accent = Color.accentColor

    static func latency(_ ms: Int?) -> Color {
        guard let ms else { return .secondary }
        switch ms {
        case ..<100: return .green
        case ..<300: return .orange
        default: return .red
        }
    }
}

// MARK: - Typography

enum AppFont {
    static let panelTitle = Font.system(.headline, design: .rounded, weight: .semibold)
    static let sectionTitle = Font.system(.subheadline, weight: .semibold)
    static let body = Font.system(.body)
    static let caption = Font.system(.caption)
    static let latency = Font.system(.caption, design: .monospaced, weight: .medium)
    static let statValue = Font.system(.caption, design: .monospaced, weight: .semibold)
}

// MARK: - Reusable Surfaces

struct PanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: AppLayout.cornerRadius, style: .continuous)
            .fill(.background)
            .overlay {
                RoundedRectangle(cornerRadius: AppLayout.cornerRadius, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(AppFont.sectionTitle)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
                .symbolRenderingMode(.hierarchical)

            content
        }
        .padding(AppLayout.compactPadding)
        .background {
            RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius, style: .continuous)
                .fill(.quaternary.opacity(0.45))
        }
    }
}

struct StatusDot: View {
    let isActive: Bool
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(isActive ? AppColor.running : AppColor.stopped)
            .frame(width: 8, height: 8)
            .overlay {
                if isActive {
                    Circle()
                        .stroke(AppColor.running.opacity(0.35), lineWidth: 2)
                        .scaleEffect(pulse ? 1.8 : 1.0)
                        .opacity(pulse ? 0 : 0.8)
                }
            }
            .onAppear { updatePulse(isActive) }
            .onChange(of: isActive) { _, active in updatePulse(active) }
    }

    private func updatePulse(_ active: Bool) {
        pulse = false
        guard active else { return }
        withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
            pulse = true
        }
    }
}

struct LatencyBadge: View {
    let milliseconds: Int?

    var body: some View {
        Group {
            if let ms = milliseconds {
                Text("\(ms) ms")
                    .font(AppFont.latency)
                    .foregroundStyle(AppColor.latency(ms))
            } else {
                Text("—")
                    .font(AppFont.latency)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(minWidth: 44, alignment: .trailing)
    }
}

struct PrimaryActionButton: View {
    let title: String
    let symbol: String
    let role: ButtonRole?
    let action: () -> Void

    init(_ title: String, symbol: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: symbol)
                .font(.system(.callout, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
    }
}

struct DividerInset: View {
    var body: some View {
        Divider()
            .padding(.horizontal, -AppLayout.compactPadding)
    }
}
