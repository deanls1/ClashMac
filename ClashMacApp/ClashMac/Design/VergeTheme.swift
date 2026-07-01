import AppKit
import SwiftUI

// 设计 token（VergeLayout / VergeColor）已抽到 VergeTokens.swift；本文件仅保留可复用 View 组件。

// MARK: - Shell

/// 隔离每秒变化的流量/内存读取，避免侧边栏导航列表随流量 1Hz 重绘（侧边栏在所有页面常驻）。
private struct SidebarTrafficFooterContainer: View {
    let store: AppStore

    var body: some View {
        VergeSidebarTrafficFooter(
            traffic: store.traffic,
            samples: store.trafficHistory,
            isRunning: store.isProxyEnabled,
            memoryLabel: store.coreMemoryLabel
        )
    }
}

struct VergeSidebar: View {
    @Bindable var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            brandHeader
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(DashboardSection.allCases) { section in
                        VergeNavRow(
                            section: section,
                            badge: section.badgeCount(from: store),
                            isSelected: store.selectedSection == section
                        ) {
                            store.selectedSection = section
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            SidebarTrafficFooterContainer(store: store)
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
            Image("AppLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Clash Mac")
                    .font(VergeTypography.sectionTitle)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
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
            HStack(spacing: 10) {
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
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
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
                    Image(systemName: store.isProxyEnabled ? "stop.fill" : "play.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(store.isProxyEnabled ? "停止" : "启动")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .tint(store.isProxyEnabled ? VergeColor.danger : VergeColor.accent)
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
        store.isPowerTransitioning
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
    var isStarting: Bool = false
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
        .disabled(isBusy && !isStarting)
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
            HStack(spacing: 8) {
                if node.isSelected {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(VergeColor.accent)
                        .frame(width: 3, height: 26)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(node.name)
                        .font(VergeTypography.captionMedium)
                        .foregroundStyle(node.isAlive ? .primary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if !tags.isEmpty {
                        Text(tags.prefix(2).joined(separator: " · "))
                            .font(VergeTypography.small)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                if isTesting {
                    ProgressView()
                        .controlSize(.mini)
                } else if let delay = node.delay {
                    Text("\(delay)ms")
                        .font(VergeTypography.smallMedium.monospacedDigit())
                        .foregroundStyle(VergeColor.latency(delay))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(VergeColor.latency(delay).opacity(0.12)))
                } else if !node.isAlive {
                    Text("离线")
                        .font(VergeTypography.smallMedium)
                        .foregroundStyle(VergeColor.danger.opacity(0.8))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(VergeColor.danger.opacity(0.08)))
                        }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(node.isSelected ? VergeColor.accentSoft : (hovered ? VergeColor.surfaceElevated : VergeColor.cardFill))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        node.isSelected ? VergeColor.accent : VergeColor.border,
                        lineWidth: node.isSelected ? 1.5 : 0.5
                    )
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
        .frame(maxWidth: VergeLayout.pageMaxWidth)
        .frame(maxWidth: .infinity)
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

struct VergeSettingsSection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: VergeLayout.settingsRowSpacing) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VergeColor.accent)
                    .frame(width: 18, height: 18)
                Text(title)
                    .font(VergeTypography.sectionTitle)
            }
            .padding(.bottom, 8)

            content
        }
        .padding(VergeLayout.settingsCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(vergeCardBackground)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct VergeSettingsRow<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(title)
                .font(VergeTypography.body)
                .foregroundStyle(.primary)
                .frame(width: VergeLayout.settingsLabelWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            trailing
        }
        .frame(minHeight: VergeLayout.settingsRowMinHeight)
    }
}

/// 带齿轮槽位的开关行：无齿轮时也保留占位，保证所有 Toggle 右缘对齐。
struct VergeSettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var configEnabled: Bool = true
    var configAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(title)
                .font(VergeTypography.body)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: VergeLayout.settingsLabelWidth, alignment: .leading)

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                if let configAction {
                    Button(action: configAction) {
                        Image(systemName: "gearshape")
                            .font(.body)
                            .foregroundStyle(configEnabled ? .secondary : .tertiary)
                            .frame(width: VergeLayout.settingsGearSlotWidth, height: VergeLayout.settingsRowMinHeight)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!configEnabled)
                } else {
                    Color.clear
                        .frame(width: VergeLayout.settingsGearSlotWidth, height: 1)
                }
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
        }
        .frame(minHeight: VergeLayout.settingsRowMinHeight)
    }
}

/// 较宽控件行：标签固定宽度，控件占满剩余空间。
struct VergeSettingsWideRow<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(title)
                .font(VergeTypography.body)
                .frame(width: VergeLayout.settingsLabelWidth, alignment: .leading)
            Spacer(minLength: 12)
            content
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(minHeight: VergeLayout.settingsRowMinHeight)
    }
}

struct VergeSettingsActionRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Color.clear
                .frame(width: VergeLayout.settingsLabelWidth, height: 1)
            Spacer(minLength: 12)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: VergeLayout.settingsRowMinHeight)
        .padding(.top, 6)
    }
}

struct VergeSettingsNote: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Color.clear
                .frame(width: VergeLayout.settingsLabelWidth, height: 1)
            Spacer(minLength: 12)
            Text(text)
                .font(VergeTypography.small)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}

/// 自动换行的横向布局：子项超出可用宽度时换到下一行，避免按钮被压缩截断。
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var currentWidth: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            let needed = (rows[rows.count - 1].isEmpty ? 0 : spacing) + size.width
            if currentWidth + needed > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([size])
                currentWidth = size.width
            } else {
                rows[rows.count - 1].append(size)
                currentWidth += needed
            }
        }
        let height = rows.reduce(CGFloat(0)) { acc, row in
            acc + (row.map(\.height).max() ?? 0)
        } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        let widest = rows.map { row in
            row.map(\.width).reduce(0, +) + CGFloat(max(0, row.count - 1)) * spacing
        }.max() ?? 0
        return CGSize(width: min(widest, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        var isFirstInRow = true
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            let needed = (isFirstInRow ? 0 : spacing) + size.width
            if x + needed - bounds.minX > maxWidth, !isFirstInRow {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
                isFirstInRow = true
            }
            let placeX = isFirstInRow ? x : x + spacing
            view.place(at: CGPoint(x: placeX, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x = placeX + size.width
            rowHeight = max(rowHeight, size.height)
            isFirstInRow = false
        }
    }
}

struct VergeSettingsActionBar: View {
    let actions: [Action]

    struct Action: Identifiable {
        let id = UUID()
        let title: String
        var prominent = false
        var disabled = false
        var loading = false
        let handler: () -> Void
    }

    var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(actions) { action in
                Group {
                    if action.prominent {
                        Button(action: action.handler) {
                            actionLabel(action)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(action: action.handler) {
                            actionLabel(action)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .tint(action.prominent ? VergeColor.accent : nil)
                .controlSize(.small)
                .fixedSize()
                .disabled(action.disabled || action.loading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func actionLabel(_ action: Action) -> some View {
        if action.loading {
            ProgressView().controlSize(.small)
        } else {
            Text(action.title)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

struct VergeSettingsCompactField: View {
    @Binding var text: String
    var placeholder: String = ""
    var width: CGFloat = 108

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(VergeTypography.mono)
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: width)
            .background { vergeFieldBackground }
    }
}

struct VergeSettingsPathRow: View {
    let path: String

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Color.clear
                .frame(width: VergeLayout.settingsLabelWidth, height: 1)
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(path)
                    .font(VergeTypography.small.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("复制路径")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(VergeColor.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(VergeColor.border, lineWidth: 0.5)
                    }
            }
        }
        .padding(.top, 4)
    }
}

struct VergePathChip: View {
    let path: String

    var body: some View {
        VergeSettingsPathRow(path: path)
    }
}

struct VergeLogRow: View {
    let entry: LogEntry

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f
    }()

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(Self.timestampFormatter.string(from: entry.timestamp))
                .font(VergeTypography.small.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 86, alignment: .leading)
            Text(entry.level.label.uppercased())
                .font(VergeTypography.smallMedium)
                .foregroundStyle(levelColor)
                .frame(width: 54, alignment: .leading)
            Text(entry.message)
                .font(VergeTypography.mono)
                .textSelection(.enabled)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private var levelColor: Color {
        switch entry.level {
        case .info: VergeColor.accent
        case .warning: VergeColor.upload
        case .error: VergeColor.danger
        case .debug: Color.purple
        }
    }
}

struct VergeSettingsChevronRow: View {
    let title: String
    var info: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 0) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(VergeTypography.body)
                    if info {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: VergeLayout.settingsLabelWidth, alignment: .leading)
                Spacer(minLength: 12)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: VergeLayout.settingsRowMinHeight)
            .contentShape(Rectangle())
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
                Button(actionLabel) { onAction() }
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
        case .helperApproval: "lock.shield"
        }
    }

    private var actionLabel: String {
        switch banner.kind {
        case .helperApproval: "打开设置"
        default: "处理"
        }
    }
}
