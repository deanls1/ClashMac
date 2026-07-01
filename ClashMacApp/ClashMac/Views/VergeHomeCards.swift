import SwiftUI

// MARK: - Verge 首页卡片（对齐截图布局）

struct VergeHomeCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    var trailing: AnyView?
    @ViewBuilder var content: Content

    init(
        icon: String,
        iconColor: Color,
        title: String,
        trailing: (any View)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.trailing = trailing.map { AnyView($0) }
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VergeCardIcon(symbol: icon, color: iconColor)
                Text(title)
                    .font(VergeTypography.cardTitle)
                    .lineLimit(1)
                Spacer(minLength: 8)
                trailing
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(vergeCardBackground)
    }
}

enum NetworkPanel {
    case systemProxy
    case tun
}

struct VergeHomeView: View {
    @Bindable var store: AppStore
    @State private var selectedGroupName: String = ""
    @State private var selectedNodeName: String = ""
    @State private var networkTab: NetworkPanel = .systemProxy
    @State private var didInitNetworkTab = false
    @State private var showUninstallHelperConfirm = false

    private let homeColumns = [
        GridItem(.flexible(), spacing: VergeLayout.homeGridSpacing),
        GridItem(.flexible(), spacing: VergeLayout.homeGridSpacing),
    ]

    private var activeGroup: ProxyGroup? {
        store.groups.first { $0.name == selectedGroupName }
            ?? store.groups.first { $0.name == store.activeGroupName }
            ?? store.groups.first
    }

    private var isBusy: Bool {
        store.isPowerTransitioning
    }

    private var isStarting: Bool {
        if case .starting = store.coreState { return true }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: VergeLayout.homeGridSpacing) {
                VergePageHeader(DashboardSection.home.pageTitle) {
                    VergeHeaderIconButton(symbol: "gearshape", help: "设置") {
                        store.selectedSection = .settings
                    }
                }

                startupBanners

                heroSection

                LazyVGrid(
                    columns: homeColumns,
                    alignment: .leading,
                    spacing: VergeLayout.homeGridSpacing
                ) {
                    profileCard
                    currentNodeCard
                    networkCard
                    ClashInfoCardView(store: store)
                }

                TrafficStatsCardView(store: store)
            }
            .padding(VergeLayout.contentPadding)
            .frame(maxWidth: VergeLayout.homeMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(VergeColor.canvas)
        .onAppear {
            store.syncSettingsWithRuntime()
            syncSelection()
            Task { await store.refreshDashboardData() }
        }
        .onChange(of: store.coreState) { _, state in
            store.syncSettingsWithRuntime()
            if state.isRunning {
                Task { await store.refreshDashboardData() }
            }
        }
        .onChange(of: store.groups.count) { _, _ in syncSelection() }
        .onChange(of: store.currentSelectedNode) { _, _ in syncSelection() }
    }

    /// 解析当前应展示的代理组，保证 Picker selection 始终对应有效 tag。
    private var selectionGroup: ProxyGroup? {
        if store.groups.contains(where: { $0.name == selectedGroupName }) {
            return store.groups.first { $0.name == selectedGroupName }
        }
        return store.groups.first { $0.name == store.activeGroupName }
            ?? store.groups.first { $0.name == "Proxy" }
            ?? store.groups.first
    }

    private var groupSelection: Binding<String> {
        Binding(
            get: { selectionGroup?.name ?? "" },
            set: { selectedGroupName = $0 }
        )
    }

    private var nodeSelection: Binding<String> {
        Binding(
            get: {
                guard let group = selectionGroup, !group.nodes.isEmpty else { return "" }
                if group.nodes.contains(where: { $0.name == selectedNodeName }) {
                    return selectedNodeName
                }
                return group.nodes.first(where: \.isSelected)?.name ?? group.nodes.first!.name
            },
            set: { selectedNodeName = $0 }
        )
    }

    @ViewBuilder
    private var startupBanners: some View {
        if !store.startupBanners.isEmpty {
            VStack(spacing: 10) {
                ForEach(store.startupBanners, id: \.kind) { banner in
                    VergeStartupBanner(
                        banner: banner,
                        isBusy: startupBannerBusy(banner),
                        onAction: { Task { await store.actOnStartupBanner(banner) } },
                        onDismiss: { store.dismissStartupBanner(banner.kind) }
                    )
                }
            }
        }
    }

    private func startupBannerBusy(_ banner: StartupBanner) -> Bool {
        switch banner.kind {
        case .geoData: store.isGeoBannerBusy
        case .coreUpdate, .coreMissing: store.isCoreBannerBusy
        case .helperApproval: false
        }
    }

    private var heroSection: some View {
        HStack(alignment: .center, spacing: 20) {
            VergePowerButton(isRunning: store.isProxyEnabled, isBusy: isBusy, isStarting: isStarting) {
                Task { await store.togglePower() }
            }

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.coreState.statusTitle)
                        .font(VergeTypography.sectionTitle)
                    if let detail = store.coreState.errorDetail {
                        Text(detail)
                            .font(VergeTypography.caption)
                            .foregroundStyle(VergeColor.danger)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(statusSubtitle)
                            .font(VergeTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                VergeModePills(store: store)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(vergeHeroBackground)
    }

    private var statusSubtitle: String {
        if case .starting = store.coreState {
            return "正在连接 Mihomo 内核…"
        }
        if store.coreState.isRunning {
            if store.tunModeToggleValue { return "TUN 模式 · 端口 \(store.mixedPort)" }
            if store.systemProxyToggleValue { return "系统代理已生效 · 端口 \(store.mixedPort)" }
            return "代理运行中 · 未启用系统代理"
        }
        if store.version == "—" {
            return "请先在设置中下载 Mihomo 内核"
        }
        return "内核 \(store.coreVersionLabel) · 点击左侧按钮启动"
    }

    private var profileCard: some View {
        VergeHomeCard(
            icon: "icloud.and.arrow.down",
            iconColor: VergeColor.download,
            title: store.activeProfile?.name ?? "未选择配置",
            trailing: HStack(spacing: 8) {
                VergeStatusBadge(text: "订阅", color: VergeColor.accent)
                Button { store.selectedSection = .subscription } label: {
                    Image(systemName: "list.bullet")
                        .foregroundStyle(VergeColor.accent)
                }
                .buttonStyle(.borderless)
            }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                if let url = store.activeProfile?.subscriptionURL {
                    Text("来自: \(URL(string: url)?.host ?? url)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("更新时间: \(store.activeProfile?.updatedAt.formatted(date: .abbreviated, time: .shortened) ?? "—")")
                    .font(VergeTypography.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var currentNodeCard: some View {
        VergeHomeCard(
            icon: "antenna.radiowaves.left.and.right",
            iconColor: VergeColor.accent,
            title: "当前节点",
            trailing: Button("代理 >") { store.selectedSection = .proxy }
                .font(.caption.weight(.medium))
                .foregroundStyle(VergeColor.accent)
                .buttonStyle(.plain)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if let node = store.currentSelectedNode {
                    Text(node)
                        .font(VergeTypography.bodyMedium)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: VergeLayout.innerCardRadius).fill(VergeColor.accentSoft.opacity(0.5)))
                }
                if !store.groups.isEmpty, selectionGroup != nil {
                    pickerRow("代理组", selection: groupSelection) {
                        ForEach(store.groups) { g in Text(g.name).tag(g.name) }
                    }
                    if let group = selectionGroup, !group.nodes.isEmpty {
                        pickerRow("节点", selection: nodeSelection) {
                            ForEach(group.nodes) { n in Text(n.name).tag(n.name) }
                        }
                        .onChange(of: selectedNodeName) { _, name in
                            guard group.nodes.contains(where: { $0.name == name }),
                                  let node = group.nodes.first(where: { $0.name == name }) else { return }
                            Task { await store.selectNode(group: group, node: node) }
                        }
                    }
                }
            }
        }
    }

    private func pickerRow<C: View>(_ label: String, selection: Binding<String>, @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(VergeTypography.caption)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            Picker("", selection: selection, content: content)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var networkCard: some View {
        VergeHomeCard(icon: "server.rack", iconColor: VergeColor.accent, title: "网络设置") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    networkModeChip(
                        title: "系统代理",
                        symbol: "display",
                        selected: networkTab == .systemProxy,
                        running: isSystemProxyModeActive
                    ) { networkTab = .systemProxy }
                    .frame(maxWidth: .infinity)
                    networkModeChip(
                        title: "虚拟网卡模式",
                        symbol: "network.badge.shield.half.filled",
                        selected: networkTab == .tun,
                        running: isTunModeSelected
                    ) { networkTab = .tun }
                    .frame(maxWidth: .infinity)
                }

                networkHintBox

                networkControlRow
            }
        }
        .onAppear(perform: initNetworkTabIfNeeded)
        .confirmationDialog(
            "卸载 Helper？",
            isPresented: $showUninstallHelperConfirm,
            titleVisibility: .visible
        ) {
            Button("卸载 Helper", role: .destructive) { store.uninstallHelper() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("卸载后将无法使用虚拟网卡（TUN）模式，需重新安装并在系统设置中批准。")
        }
    }

    private func initNetworkTabIfNeeded() {
        guard !didInitNetworkTab else { return }
        didInitNetworkTab = true
        networkTab = store.tunModeToggleValue ? .tun : .systemProxy
    }

    // MARK: 网络卡片子视图

    @ViewBuilder
    private var networkHintBox: some View {
        HStack(spacing: 6) {
            Text(networkHintText)
                .font(VergeTypography.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Image(systemName: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: VergeLayout.innerCardRadius, style: .continuous)
                .strokeBorder(VergeColor.accent.opacity(0.35), lineWidth: VergeStroke.emphasis)
        }
    }

    private var networkControlRow: some View {
        HStack(spacing: 10) {
            Image(systemName: controlActive ? "play.circle.fill" : "pause.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(controlActive ? VergeColor.running : Color.secondary)
            Text(networkTab == .tun ? "虚拟网卡模式" : "系统代理")
                .font(VergeTypography.bodyMedium)

            networkGearMenu

            if networkTab == .tun {
                Button {
                    showUninstallHelperConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(VergeColor.upload)
                .help("卸载 Helper")
            }

            Spacer(minLength: 0)

            Toggle("", isOn: networkToggleBinding)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(VergeColor.accent)
                .disabled(networkSwitchDisabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: VergeLayout.innerCardRadius, style: .continuous)
                .fill(VergeColor.surface)
        }
    }

    @ViewBuilder
    private var networkGearMenu: some View {
        Menu {
            if networkTab == .tun {
                Button("虚拟网卡设置…") { store.isTUNConfigPresented = true }
                Button("重装 Helper") { store.installHelper() }
            } else {
                Button(store.proxyGuardEnabled ? "关闭代理守卫" : "开启代理守卫") {
                    store.setProxyGuardEnabled(!store.proxyGuardEnabled)
                }
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 13))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(.secondary)
    }

    private var controlActive: Bool {
        networkTab == .tun ? isTunModeSelected : isSystemProxyModeActive
    }

    /// 下方开关的真实切换逻辑（上方标签只负责选择展示哪个模式）。
    private var networkToggleBinding: Binding<Bool> {
        Binding(
            get: {
                networkTab == .tun ? store.tunModeToggleValue : store.systemProxyToggleValue
            },
            set: { isOn in
                let panel = networkTab
                Task {
                    if panel == .tun {
                        if isOn {
                            await store.setTunEnabled(true)
                        } else {
                            await store.setTunEnabled(false)
                            await store.setSystemProxyEnabled(true)
                        }
                    } else {
                        if isOn {
                            if store.isTunRuntimeActive {
                                await store.setTunEnabled(false)
                            }
                            await store.setSystemProxyEnabled(true)
                        } else {
                            await store.setSystemProxyEnabled(false)
                        }
                    }
                }
            }
        )
    }

    private var networkSwitchDisabled: Bool {
        if case .starting = store.coreState { return true }
        if case .stopping = store.coreState { return true }
        return false
    }

    private var isTunModeSelected: Bool {
        store.coreState.isRunning && store.tunModeToggleValue
    }

    private var isSystemProxyModeActive: Bool {
        store.coreState.isRunning && store.systemProxyToggleValue
    }

    private var networkHintText: String {
        if case .starting = store.coreState { return "正在启动内核…" }
        if case .stopping = store.coreState { return "正在停止内核…" }
        if networkTab == .tun {
            return store.tunModeToggleValue
                ? "TUN 模式已启用，应用将通过虚拟网卡访问网络"
                : "TUN 模式已关闭，需要 Helper 支持，开启后接管全局流量"
        } else {
            return store.systemProxyToggleValue
                ? "系统代理已生效 · 端口 \(store.mixedPort)"
                : "系统代理已关闭，建议大多数用户打开此选项"
        }
    }

    private func networkModeChip(
        title: String,
        symbol: String,
        selected: Bool,
        running: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                Text(title)
                    .font(VergeTypography.captionMedium)
                Spacer(minLength: 0)
                Circle()
                    .fill(running ? VergeColor.running : Color.clear)
                    .frame(width: 7, height: 7)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: VergeLayout.innerCardRadius, style: .continuous)
                    .fill(selected ? VergeColor.accent : VergeColor.cardFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: VergeLayout.innerCardRadius, style: .continuous)
                            .strokeBorder(selected ? Color.clear : VergeColor.border, lineWidth: VergeStroke.hairline)
                    }
            }
            .foregroundStyle(selected ? Color.white : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    private func syncSelection() {
        guard let group = selectionGroup else { return }
        selectedGroupName = group.name
        selectedNodeName = group.nodes.first(where: \.isSelected)?.name
            ?? group.nodes.first?.name
            ?? ""
    }
}

/// 独立子视图：仅此视图依赖每秒变化的连接数/内存/运行时长，避免整张首页 1Hz 重绘。
private struct ClashInfoCardView: View {
    let store: AppStore

    var body: some View {
        VergeHomeCard(icon: "cpu", iconColor: VergeColor.accent, title: "Clash 信息") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                infoTile(title: "内核", value: store.coreVersionLabel, symbol: "shippingbox")
                infoTile(title: "混合端口", value: store.coreState.isRunning ? "\(store.mixedPort)" : "—", symbol: "number")
                infoTile(title: "规则", value: store.coreState.isRunning ? "\(store.rules.count)" : "—", symbol: "list.bullet.rectangle")
                infoTile(title: "运行时长", value: store.coreUptimeLabel, symbol: "clock")
                infoTile(
                    title: "内存",
                    value: store.coreState.isRunning ? store.coreMemoryLabel : "—",
                    symbol: "memorychip"
                )
                infoTile(
                    title: "连接",
                    value: store.coreState.isRunning ? "\(store.connections.count)" : "—",
                    symbol: "arrow.left.arrow.right"
                )
            }
        }
    }

    private func infoTile(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(VergeTypography.small)
                .foregroundStyle(.secondary)
            Text(value)
                .font(VergeTypography.bodyMedium.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: VergeLayout.innerCardRadius, style: .continuous)
                .fill(VergeColor.surface)
        }
    }
}

/// 独立子视图：流量曲线与速率/累计值每秒更新，隔离后仅此卡片重绘。
private struct TrafficStatsCardView: View {
    let store: AppStore

    var body: some View {
        VergeHomeCard(icon: "gauge.with.dots.needle.67percent", iconColor: VergeColor.upload, title: "流量统计") {
            VStack(spacing: 12) {
                Group {
                    if store.coreState.isRunning, store.trafficHistory.count > 2 {
                        TrafficChartView(samples: store.trafficHistory, height: 148)
                    } else {
                        RoundedRectangle(cornerRadius: VergeLayout.innerCardRadius, style: .continuous)
                            .fill(VergeColor.surface)
                            .frame(height: 148)
                            .overlay {
                                Text("启动后显示流量曲线")
                                    .font(VergeTypography.caption)
                                    .foregroundStyle(.tertiary)
                            }
                    }
                }
                .padding(8)
                .background { vergeInnerCardBackground }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                    spacing: 8
                ) {
                    VergeMiniStat(title: "上传速度", value: store.traffic.uploadFormatted, color: VergeColor.upload, symbol: "arrow.up")
                    VergeMiniStat(title: "下载速度", value: store.traffic.downloadFormatted, color: VergeColor.download, symbol: "arrow.down")
                    VergeMiniStat(title: "活跃连接", value: "\(store.connections.count)", color: VergeColor.running, symbol: "link")
                    VergeMiniStat(title: "上传量", value: store.trafficTotals.uploadFormatted, color: VergeColor.upload, symbol: "icloud.and.arrow.up")
                    VergeMiniStat(title: "下载量", value: store.trafficTotals.downloadFormatted, color: VergeColor.download, symbol: "icloud.and.arrow.down")
                    VergeMiniStat(title: "规则数量", value: "\(store.rules.count)", color: .secondary, symbol: "list.bullet")
                }
            }
        }
    }
}
