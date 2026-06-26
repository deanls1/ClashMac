import AppKit
import SwiftUI

// MARK: - Verge-inspired design tokens

enum VergeLayout {
    static let sidebarWidth: CGFloat = 220
    static let topBarHeight: CGFloat = 0
    static let contentPadding: CGFloat = 22
    static let cardRadius: CGFloat = 12
    static let nodeCardMinWidth: CGFloat = 148
    static let powerButtonSize: CGFloat = 120
}

enum VergeColor {
    static let accent = Color(red: 0.09, green: 0.47, blue: 1.0)
    static let accentSoft = Color(red: 0.09, green: 0.47, blue: 1.0).opacity(0.14)
    static let accentGlow = Color(red: 0.09, green: 0.47, blue: 1.0).opacity(0.28)
    static let upload = Color(red: 0.96, green: 0.45, blue: 0.18)
    static let download = Color(red: 0.20, green: 0.58, blue: 0.98)
    static let running = Color(red: 0.18, green: 0.78, blue: 0.48)
    static let stopped = Color.secondary
    static let danger = Color(red: 0.94, green: 0.32, blue: 0.32)

    static var canvas: Color { adaptive(light: 0.965, dark: 0.08) }
    static var sidebarBG: Color { adaptive(light: 0.998, dark: 0.06) }
    static var cardFill: Color { adaptive(light: 1.0, dark: 0.12) }
    static var surface: Color { adaptive(light: 0.0, dark: 1.0, lightAlpha: 0.045, darkAlpha: 0.06) }
    static var surfaceElevated: Color { adaptive(light: 1.0, dark: 0.14) }
    static var border: Color { adaptive(light: 0.0, dark: 1.0, lightAlpha: 0.08, darkAlpha: 0.12) }
    static var shadow: Color { Color.black.opacity(0.045) }
    static var heroGlow: Color { accentGlow.opacity(0.45) }

    private static func adaptive(
        light: CGFloat,
        dark: CGFloat,
        lightAlpha: CGFloat? = nil,
        darkAlpha: CGFloat? = nil
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if let lightAlpha, let darkAlpha {
                return NSColor(white: 1.0, alpha: isDark ? darkAlpha : lightAlpha)
            }
            let value = isDark ? dark : light
            return NSColor(red: value, green: value, blue: value, alpha: 1)
        })
    }

    static func latency(_ ms: Int?) -> Color {
        guard let ms else { return .secondary }
        switch ms {
        case ..<80: return running
        case ..<200: return Color(red: 0.95, green: 0.75, blue: 0.2)
        default: return Color(red: 0.95, green: 0.35, blue: 0.35)
        }
    }
}

// MARK: - Shell

struct VergeSidebar: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            brandHeader
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(DashboardSection.allCases) { section in
                        VergeNavRow(
                            section: section,
                            badge: section.badgeCount(from: store),
                            isSelected: store.selectedSection == section
                        ) {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                store.selectedSection = section
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            VergeSidebarTrafficFooter(
                traffic: store.traffic,
                samples: store.trafficHistory,
                isRunning: store.coreState.isRunning
            )
        }
        .frame(width: VergeLayout.sidebarWidth)
        .background {
            VergeColor.sidebarBG
                .overlay(alignment: .trailing) {
                    Rectangle().fill(VergeColor.border).frame(width: 1)
                }
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let icon = NSApplication.shared.applicationIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                    } else {
                        Image(systemName: "cat.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text("NEW")
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red))
                    .offset(x: 8, y: -6)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Clash Mac")
                    .font(VergeTypography.sectionTitle)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }
}

private struct VergeNavRow: View {
    let section: DashboardSection
    let badge: Int?
    let isSelected: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VergeNavIcon(section: section)
                Text(section.label)
                    .font(isSelected ? VergeTypography.navSelected : VergeTypography.nav)
                    .foregroundStyle(isSelected ? VergeColor.accent : .primary.opacity(0.82))
                Spacer(minLength: 0)
                if let badge {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(isSelected ? VergeColor.accent : .secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(isSelected ? VergeColor.accentSoft : (hovered ? VergeColor.surface : Color.clear))
                    if isSelected {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(VergeColor.accent)
                            .frame(width: 3)
                            .padding(.vertical, 6)
                            .padding(.leading, 2)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

struct VergeTopBar: View {
    @Bindable var store: AppStore

    var body: some View {
        HStack(spacing: 14) {
            Text(store.selectedSection.label)
                .font(.system(size: 18, weight: .bold))

            if let profile = store.activeProfile {
                HStack(spacing: 5) {
                    Circle()
                        .fill(VergeColor.accent)
                        .frame(width: 6, height: 6)
                    Text(profile.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(VergeColor.surface))
            }

            Spacer()

            VergeModePills(store: store)

            Button {
                Task { await store.togglePower() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: store.coreState.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(store.coreState.isRunning ? "停止" : "启动")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .tint(store.coreState.isRunning ? VergeColor.danger : VergeColor.accent)
            .disabled(isBusy)
        }
        .padding(.horizontal, VergeLayout.contentPadding)
        .frame(height: VergeLayout.topBarHeight)
        .background(VergeColor.cardFill.opacity(0.72))
        .overlay(alignment: .bottom) {
            Rectangle().fill(VergeColor.border).frame(height: 1)
        }
    }

    private var isBusy: Bool {
        if case .starting = store.coreState { return true }
        if case .stopping = store.coreState { return true }
        return false
    }
}

struct VergeModePills: View {
    @Bindable var store: AppStore

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RunMode.allCases) { mode in
                Button {
                    Task { await store.setMode(mode) }
                } label: {
                    Text(mode.label)
                        .font(store.mode == mode ? VergeTypography.captionMedium : VergeTypography.caption)
                        .foregroundStyle(store.mode == mode ? Color.white : Color.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background {
                            if store.mode == mode {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(VergeColor.accent)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
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

// MARK: - Home

struct VergePowerButton: View {
    let isRunning: Bool
    let isBusy: Bool
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: isRunning
                                ? [VergeColor.running.opacity(0.28), .clear]
                                : [VergeColor.accent.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(pulse ? 1.08 : 1.0)
                    .opacity(pulse ? 0.55 : 0.85)

                Circle()
                    .stroke(
                        AngularGradient(
                            colors: isRunning
                                ? [VergeColor.running, VergeColor.running.opacity(0.2), VergeColor.running]
                                : [VergeColor.accent, VergeColor.accent.opacity(0.15), VergeColor.accent],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: VergeLayout.powerButtonSize + 12, height: VergeLayout.powerButtonSize + 12)

                Circle()
                    .fill(VergeColor.cardFill)
                    .frame(width: VergeLayout.powerButtonSize, height: VergeLayout.powerButtonSize)
                    .shadow(color: VergeColor.shadow, radius: 20, y: 8)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: isRunning
                                ? [VergeColor.running.opacity(0.15), VergeColor.cardFill]
                                : [VergeColor.accentSoft, VergeColor.cardFill],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: VergeLayout.powerButtonSize - 8, height: VergeLayout.powerButtonSize - 8)

                if isBusy {
                    ProgressView().controlSize(.regular)
                } else {
                    Image(systemName: isRunning ? "stop.fill" : "power")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(isRunning ? VergeColor.danger : VergeColor.accent)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .onAppear { updatePulse() }
        .onChange(of: isRunning) { _, _ in updatePulse() }
    }

    private func updatePulse() {
        pulse = false
        guard isRunning else { return }
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

struct VergeStatCard: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(vergeCardBackground)
    }
}

struct VergeChartCard: View {
    let traffic: TrafficSnapshot
    let samples: [TrafficSample]
    let totals: TrafficTotals
    let isRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("实时流量")
                    .font(.headline)
                Spacer()
                if isRunning {
                    HStack(spacing: 16) {
                        trafficLabel("上传", traffic.uploadFormatted, VergeColor.upload, "arrow.up")
                        trafficLabel("下载", traffic.downloadFormatted, VergeColor.download, "arrow.down")
                    }
                }
            }

            if isRunning, samples.count > 2 {
                TrafficChartView(samples: samples, height: 100)
                    .padding(.vertical, 4)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(VergeColor.surface)
                    .frame(height: 100)
                    .overlay {
                        Text("启动代理后显示流量曲线")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
            }

            HStack {
                Text("累计下载 \(totals.downloadFormatted)")
                Spacer()
                Text("累计上传 \(totals.uploadFormatted)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(vergeCardBackground)
    }

    private func trafficLabel(_ title: String, _ value: String, _ color: Color, _ symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            VStack(alignment: .trailing, spacing: 0) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.system(.body, design: .monospaced, weight: .semibold))
            }
        }
    }
}

var vergeCardBackground: some View {
    RoundedRectangle(cornerRadius: VergeLayout.cardRadius, style: .continuous)
        .fill(VergeColor.cardFill)
        .shadow(color: VergeColor.shadow, radius: 10, y: 4)
        .overlay {
            RoundedRectangle(cornerRadius: VergeLayout.cardRadius, style: .continuous)
                .strokeBorder(VergeColor.border, lineWidth: 0.5)
        }
}

var vergeHeroBackground: some View {
    RoundedRectangle(cornerRadius: VergeLayout.cardRadius + 4, style: .continuous)
        .fill(VergeColor.cardFill)
        .overlay {
            RoundedRectangle(cornerRadius: VergeLayout.cardRadius + 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [VergeColor.accentSoft.opacity(0.65), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .shadow(color: VergeColor.shadow, radius: 16, y: 6)
        .overlay {
            RoundedRectangle(cornerRadius: VergeLayout.cardRadius + 4, style: .continuous)
                .strokeBorder(VergeColor.border, lineWidth: 0.5)
        }
}

// MARK: - Proxy

struct VergeProxyNodeCard: View {
    let node: ProxyNode
    let isTesting: Bool
    let onSelect: () -> Void
    let onTest: () -> Void

    @State private var hovered = false

    private var tags: [String] {
        NodeNameParser.transportTags(for: node)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(node.name)
                        .font(VergeTypography.bodyMedium)
                        .foregroundStyle(node.isAlive ? .primary : .secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    if node.isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(VergeColor.accent)
                    }
                }

                HStack(spacing: 6) {
                    if let flag = NodeNameParser.countryFlag(from: node.name) {
                        Text(flag).font(.body)
                    }
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(VergeTypography.small)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(VergeColor.surface))
                    }
                    Spacer(minLength: 0)
                }

                HStack {
                    if isTesting {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.mini)
                            Text("测速中")
                                .font(VergeTypography.small)
                                .foregroundStyle(.secondary)
                        }
                    } else if let delay = node.delay {
                        Text("\(delay) ms")
                            .font(VergeTypography.mono)
                            .foregroundStyle(VergeColor.latency(delay))
                    } else {
                        Button("测速", action: onTest)
                            .font(VergeTypography.smallMedium)
                            .foregroundStyle(VergeColor.accent)
                            .buttonStyle(.plain)
                    }
                    Spacer()
                    if !node.isAlive {
                        Text("离线")
                            .font(VergeTypography.small)
                            .foregroundStyle(VergeColor.danger.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(node.isSelected ? VergeColor.accentSoft : (hovered ? VergeColor.surfaceElevated : VergeColor.cardFill))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                node.isSelected ? VergeColor.accent : VergeColor.border,
                                lineWidth: node.isSelected ? 1.5 : 0.5
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("选用", action: onSelect)
            Button("测速", action: onTest)
        }
        .onHover { hovered = $0 }
    }
}

// MARK: - Shared page chrome

struct VergePageToolbar<Trailing: View>: View {
    let subtitle: String?
    @ViewBuilder var trailing: Trailing

    init(subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, VergeLayout.contentPadding)
        .padding(.vertical, 12)
        .background(VergeColor.cardFill.opacity(0.85))
        .overlay(alignment: .bottom) {
            Rectangle().fill(VergeColor.border).frame(height: 1)
        }
    }
}

extension VergePageToolbar where Trailing == EmptyView {
    init(subtitle: String? = nil) {
        self.subtitle = subtitle
        self.trailing = EmptyView()
    }
}

struct VergeSearchField: View {
    let placeholder: String
    @Binding var text: String
    var maxWidth: CGFloat = 280

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(VergeTypography.body)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: maxWidth)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(VergeColor.cardFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(VergeColor.border, lineWidth: 0.5)
                }
        }
    }
}

struct VergeFilterBar: View {
    @Binding var query: String
    @Binding var options: FilterOptions
    var placeholder: String = "过滤条件"

    var body: some View {
        HStack(spacing: 8) {
            VergeSearchField(placeholder: placeholder, text: $query, maxWidth: .infinity)
            filterToggle("Aa", isOn: $options.caseSensitive, help: "区分大小写")
            filterToggle("ab", isOn: $options.wholeWord, help: "全词匹配")
            filterToggle(".*", isOn: $options.useRegex, help: "正则")
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: VergeLayout.cardRadius, style: .continuous)
                .fill(VergeColor.cardFill)
                .overlay {
                    RoundedRectangle(cornerRadius: VergeLayout.cardRadius, style: .continuous)
                        .strokeBorder(VergeColor.border, lineWidth: 0.5)
                }
        }
        .padding(.horizontal, VergeLayout.contentPadding)
        .padding(.bottom, 10)
    }

    private func filterToggle(_ label: String, isOn: Binding<Bool>, help: String) -> some View {
        Toggle(label, isOn: isOn)
            .toggleStyle(.button)
            .help(help)
            .font(VergeTypography.smallMedium)
            .tint(VergeColor.accent)
    }
}

struct VergeSegmentTabs<T: Hashable>: View {
    @Binding var selection: T
    let items: [(T, String)]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.0) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selection = item.0 }
                } label: {
                    Text(item.1)
                        .font(selection == item.0 ? VergeTypography.captionMedium : VergeTypography.caption)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background {
                            Capsule().fill(selection == item.0 ? VergeColor.accent : VergeColor.cardFill)
                        }
                        .overlay {
                            Capsule().strokeBorder(
                                selection == item.0 ? Color.clear : VergeColor.border,
                                lineWidth: 0.5
                            )
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == item.0 ? Color.white : Color.secondary)
            }
        }
    }
}

struct VergeSettingsSection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VergeColor.accent)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(VergeColor.accentSoft))
                Text(title)
                    .font(VergeTypography.sectionTitle)
            }
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(vergeCardBackground)
        }
    }
}

struct VergeSettingsRow<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title)
                .font(VergeTypography.body)
            Spacer()
            trailing
        }
    }
}

struct VergeSettingsChevronRow: View {
    let title: String
    var info: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                HStack(spacing: 4) {
                    Text(title).font(VergeTypography.body)
                    if info {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct VergeImportField: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat? = nil
    var onPaste: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(VergeTypography.body)
            if let onPaste {
                Button(action: onPaste) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("粘贴")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(width: width)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(VergeColor.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(VergeColor.border, lineWidth: 1)
                }
        }
    }
}

struct VergeStartupBanner: View {
    let banner: StartupBanner
    var isBusy = false
    let onAction: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: bannerIcon)
                .font(.title3)
                .foregroundStyle(VergeColor.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(banner.title)
                    .font(VergeTypography.bodyMedium)
                Text(banner.message)
                    .font(VergeTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isBusy {
                ProgressView()
                    .controlSize(.small)
                Text("下载中…")
                    .font(VergeTypography.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("处理") { onAction() }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .tint(VergeColor.accent)
            }
            Button { onDismiss() } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .disabled(isBusy)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(VergeColor.accentSoft)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(VergeColor.accent.opacity(0.35), lineWidth: 1)
                }
        }
    }

    private var bannerIcon: String {
        switch banner.kind {
        case .geoData: "globe.americas"
        case .coreUpdate: "arrow.down.circle"
        case .coreMissing: "cpu"
        }
    }
}

struct VergeIPDualCard: View {
    let direct: IPInfo?
    let proxy: IPInfo?
    let isLoading: Bool
    let isRunning: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("IP 信息", systemImage: "network")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(isLoading)
            }

            if isLoading {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("检测中…").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else if isRunning {
                HStack(alignment: .top, spacing: 12) {
                    ipPanel(title: "本机 IP", info: direct, accent: .secondary)
                    ipPanel(title: "出口 IP", info: proxy, accent: VergeColor.accent)
                }
            } else {
                ipPanel(title: "本机 IP", info: direct ?? proxy, accent: VergeColor.accent)
            }
        }
        .padding(20)
        .background(vergeCardBackground)
    }

    private func ipPanel(title: String, info: IPInfo?, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accent)

            if let info {
                HStack(spacing: 8) {
                    if let code = info.countryCode, let flag = NodeNameParser.countryFlag(from: code) {
                        Text(flag).font(.title2)
                    }
                    Text(info.ip)
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button {
                        copyText(info.ip)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("复制 IP")
                }

                if !info.locationLabel.isEmpty {
                    Text(info.locationLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Text("\(info.latencyMs) ms")
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(VergeColor.latency(info.latencyMs))
                    if let isp = info.isp, !isp.isEmpty {
                        Text(isp)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            } else {
                Text("—")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(VergeColor.surfaceElevated)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(VergeColor.border, lineWidth: 1)
                }
        }
    }

    private func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct VergeIPCard: View {
    let info: IPInfo?
    let isLoading: Bool
    let isRunning: Bool
    let onRefresh: () -> Void

    var body: some View {
        VergeIPDualCard(
            direct: isRunning ? nil : info,
            proxy: isRunning ? info : nil,
            isLoading: isLoading,
            isRunning: isRunning,
            onRefresh: onRefresh
        )
    }
}
