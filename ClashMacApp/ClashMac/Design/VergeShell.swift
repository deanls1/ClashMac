import SwiftUI

// MARK: - Verge Rev 截图配色（侧栏彩色图标）

enum VergeNavStyle {
    static func gradient(for section: DashboardSection) -> [Color] {
        switch section {
        case .home:
            [Color(red: 0.58, green: 0.38, blue: 0.98), Color(red: 0.45, green: 0.28, blue: 0.92)]
        case .proxy:
            [Color(red: 0.28, green: 0.72, blue: 0.98), Color(red: 0.18, green: 0.55, blue: 0.95)]
        case .subscription:
            [Color(red: 0.42, green: 0.38, blue: 0.96), Color(red: 0.32, green: 0.28, blue: 0.88)]
        case .connections:
            [Color(red: 0.32, green: 0.82, blue: 0.58), Color(red: 0.22, green: 0.68, blue: 0.48)]
        case .rules:
            [Color(red: 0.96, green: 0.42, blue: 0.62), Color(red: 0.88, green: 0.32, blue: 0.52)]
        case .logs:
            [Color(red: 0.98, green: 0.58, blue: 0.28), Color(red: 0.92, green: 0.45, blue: 0.18)]
        case .unlock:
            [Color(red: 0.98, green: 0.78, blue: 0.22), Color(red: 0.92, green: 0.65, blue: 0.12)]
        case .settings:
            [Color(red: 0.55, green: 0.62, blue: 0.72), Color(red: 0.42, green: 0.48, blue: 0.58)]
        }
    }
}

struct VergeNavIcon: View {
    let section: DashboardSection

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: VergeNavStyle.gradient(for: section),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30, height: 30)
            Image(systemName: section.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

struct VergePageHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(VergeTypography.pageTitle)
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                trailing()
            }
        }
        .padding(.horizontal, VergeLayout.contentPadding)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
}

// MARK: - 共享视觉组件

struct VergeHeaderIconButton: View {
    let symbol: String
    var help: String = ""
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hovered ? VergeColor.accent : .secondary)
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(hovered ? VergeColor.accentSoft : VergeColor.surface)
                }
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovered = $0 }
    }
}

struct VergeCardIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.18), color.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 38, height: 38)
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

struct VergeStatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(VergeTypography.smallMedium)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.12)))
    }
}

struct VergeMiniStat: View {
    let title: String
    let value: String
    let color: Color
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(VergeTypography.small)
                .foregroundStyle(.secondary)
            Text(value)
                .font(VergeTypography.statValue)
                .foregroundStyle(color)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(VergeColor.cardFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(VergeColor.border, lineWidth: 0.5)
                }
        }
    }
}

struct VergeWebsiteTestTile: View {
    let name: String
    let symbol: String
    let tint: Color
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(hovered ? 0.14 : 0.08))
                    .frame(width: 48, height: 48)
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(tint)
            }
            Text(name)
                .font(VergeTypography.captionMedium)
            Button("测试", action: action)
                .font(VergeTypography.smallMedium)
                .buttonStyle(.plain)
                .foregroundStyle(VergeColor.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .onHover { hovered = $0 }
    }
}

struct VergeSidebarTrafficFooter: View {
    let traffic: TrafficSnapshot
    let samples: [TrafficSample]
    let isRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isRunning, samples.count > 2 {
                TrafficChartView(samples: samples, height: 48)
                    .padding(8)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(VergeColor.cardFill)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(VergeColor.border, lineWidth: 0.5)
                            }
                    }
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(VergeColor.surface)
                    .frame(height: 48)
                    .overlay {
                        Text("流量曲线")
                            .font(VergeTypography.small)
                            .foregroundStyle(.tertiary)
                    }
            }

            footerStat(symbol: "arrow.up", color: VergeColor.upload, value: traffic.uploadFormatted)
            footerStat(symbol: "arrow.down", color: VergeColor.download, value: traffic.downloadFormatted)
            footerStat(symbol: "memorychip", color: .secondary, value: "—")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background {
            VergeColor.sidebarBG
                .overlay(alignment: .top) {
                    Rectangle().fill(VergeColor.border).frame(height: 1)
                }
        }
    }

    private func footerStat(symbol: String, color: Color, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(VergeTypography.mono)
                .foregroundStyle(color == .secondary ? Color.secondary : color)
        }
    }
}
