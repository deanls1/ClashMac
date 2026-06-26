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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VergeCardIcon(symbol: icon, color: iconColor)
                Text(title)
                    .font(VergeTypography.cardTitle)
                Spacer()
                trailing
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(vergeCardBackground)
    }
}

struct VergeHomeView: View {
    @Bindable var store: AppStore
    @State private var selectedGroupName: String = ""
    @State private var selectedNodeName: String = ""

    private var activeGroup: ProxyGroup? {
        store.groups.first { $0.name == selectedGroupName }
            ?? store.groups.first { $0.name == store.activeGroupName }
            ?? store.groups.first
    }

    private var isBusy: Bool {
        if case .starting = store.coreState { return true }
        if case .stopping = store.coreState { return true }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VergePageHeader(DashboardSection.home.pageTitle) {
                    VergeHeaderIconButton(symbol: "gearshape", help: "设置") {
                        store.selectedSection = .settings
                    }
                }

                heroSection

                HStack(alignment: .top, spacing: 14) {
                    profileCard.frame(maxWidth: .infinity)
                    currentNodeCard.frame(maxWidth: .infinity)
                }

                websiteTestCard

                HStack(alignment: .top, spacing: 14) {
                    networkCard.frame(maxWidth: .infinity)
                    VergeIPDualCard(
                        direct: store.directIPInfo,
                        proxy: store.proxyIPInfo,
                        isLoading: store.isFetchingIP,
                        isRunning: store.coreState.isRunning,
                        onRefresh: { Task { await store.refreshIPInfo() } }
                    )
                    .frame(maxWidth: .infinity)
                }

                HStack(alignment: .top, spacing: 14) {
                    clashInfoCard.frame(maxWidth: .infinity)
                    trafficCard.frame(maxWidth: .infinity)
                }
            }
            .padding(VergeLayout.contentPadding)
        }
        .background(VergeColor.canvas)
        .task { await store.refreshIPInfo() }
        .onAppear { syncSelection() }
        .onChange(of: store.groups.count) { _, _ in syncSelection() }
        .onChange(of: store.coreState.isRunning) { _, _ in
            Task { await store.refreshIPInfo() }
        }
    }

    private var heroSection: some View {
        HStack(alignment: .center, spacing: 28) {
            VergePowerButton(isRunning: store.coreState.isRunning, isBusy: isBusy) {
                Task { await store.togglePower() }
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.coreState.isRunning ? "代理运行中" : "代理已停止")
                        .font(VergeTypography.sectionTitle)
                    if case .error(let message) = store.coreState {
                        Text(message)
                            .font(VergeTypography.caption)
                            .foregroundStyle(VergeColor.danger)
                            .lineLimit(2)
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
        .padding(22)
        .background(vergeHeroBackground)
    }

    private var statusSubtitle: String {
        if store.coreState.isRunning {
            return store.tunEnabled ? "TUN 模式 · 端口 \(store.mixedPort)" : "系统代理 · 端口 \(store.mixedPort)"
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
                    HStack(spacing: 8) {
                        if let flag = NodeNameParser.countryFlag(from: node) {
                            Text(flag).font(.title3)
                        }
                        Text(node)
                            .font(VergeTypography.bodyMedium)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(VergeColor.accentSoft.opacity(0.5)))
                }
                if !store.groups.isEmpty {
                    pickerRow("代理组", selection: $selectedGroupName) {
                        ForEach(store.groups) { g in Text(g.name).tag(g.name) }
                    }
                    if let group = activeGroup {
                        pickerRow("节点", selection: $selectedNodeName) {
                            ForEach(group.nodes) { n in Text(n.name).tag(n.name) }
                        }
                        .onChange(of: selectedNodeName) { _, name in
                            if let node = group.nodes.first(where: { $0.name == name }) {
                                Task { await store.selectNode(group: group, node: node) }
                            }
                        }
                    }
                }
            }
        }
    }

    private func pickerRow<C: View>(_ label: String, selection: Binding<String>, @ViewBuilder content: () -> C) -> some View {
        HStack {
            Text(label)
                .font(VergeTypography.caption)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            Picker("", selection: selection, content: content)
                .labelsHidden()
        }
    }

    private var networkCard: some View {
        VergeHomeCard(icon: "server.rack", iconColor: VergeColor.accent, title: "网络设置") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    networkModeButton("系统代理", store.systemProxyEnabled && !store.tunEnabled) {
                        Task {
                            store.tunEnabled = false
                            await store.setTunEnabled(false)
                            await store.setSystemProxyEnabled(true)
                        }
                    }
                    networkModeButton("虚拟网卡模式", store.tunEnabled) {
                        Task { await store.setTunEnabled(true) }
                    }
                }
                if store.tunEnabled {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(VergeColor.accent)
                        Text("TUN 模式已启用，将接管系统流量")
                            .font(VergeTypography.caption)
                            .foregroundStyle(VergeColor.accent)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(VergeColor.accentSoft.opacity(0.35))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(VergeColor.accent.opacity(0.25), lineWidth: 0.5)
                            }
                    }
                }
                HStack {
                    Image(systemName: store.coreState.isRunning ? "play.circle.fill" : "pause.circle")
                        .foregroundStyle(VergeColor.running)
                    Text(store.tunEnabled ? "虚拟网卡模式" : "系统代理")
                        .font(VergeTypography.bodyMedium)
                    Button { store.isTUNConfigPresented = true } label: {
                        Image(systemName: "gearshape")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!store.tunEnabled)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { store.tunEnabled },
                        set: { v in Task { await store.setTunEnabled(v) } }
                    ))
                    .labelsHidden()
                    .tint(VergeColor.accent)
                }
            }
        }
    }

    private func networkModeButton(_ title: String, _ active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(VergeTypography.captionMedium)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(active ? VergeColor.accent : VergeColor.cardFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(active ? Color.clear : VergeColor.border, lineWidth: 0.5)
                        }
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(active ? Color.white : Color.secondary)
    }

    private var websiteTestCard: some View {
        VergeHomeCard(icon: "network", iconColor: VergeColor.download, title: "网站测速") {
            HStack(spacing: 12) {
                ForEach(store.websiteTests) { item in
                    websiteTestTile(item)
                }
                Spacer(minLength: 0)
                Button {
                    Task { await store.testAllWebsites() }
                } label: {
                    if store.isTestingWebsites {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("全部")
                            .font(VergeTypography.captionMedium)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.isTestingWebsites)
            }
        }
    }

    private func websiteTestTile(_ item: WebsiteTestItem) -> some View {
        VStack(spacing: 6) {
            Image(systemName: item.symbol)
                .font(.title3)
                .foregroundStyle(VergeColor.accent)
            Text(item.name)
                .font(VergeTypography.captionMedium)
            if item.isTesting {
                ProgressView().controlSize(.mini)
            } else if let delay = item.delayMs {
                Button("\(delay) ms") {
                    Task { await store.testWebsiteLatency(id: item.id) }
                }
                .font(VergeTypography.small.monospacedDigit())
                .buttonStyle(.plain)
                .foregroundStyle(VergeColor.latency(delay))
            } else {
                Button("测试") {
                    Task { await store.testWebsiteLatency(id: item.id) }
                }
                .font(VergeTypography.smallMedium)
                .buttonStyle(.plain)
                .foregroundStyle(VergeColor.accent)
            }
        }
        .frame(minWidth: 72)
    }

    private var clashInfoCard: some View {
        VergeHomeCard(icon: "cpu", iconColor: VergeColor.accent, title: "Clash 信息") {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    infoTile(title: "内核", value: store.coreVersionLabel, symbol: "shippingbox")
                    infoTile(title: "混合端口", value: store.coreState.isRunning ? "\(store.mixedPort)" : "—", symbol: "number")
                    infoTile(title: "规则", value: store.coreState.isRunning ? "\(store.rules.count)" : "—", symbol: "list.bullet.rectangle")
                    infoTile(title: "运行时长", value: store.coreUptimeLabel, symbol: "clock")
                }
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
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(VergeColor.surface)
        }
    }

    private var trafficCard: some View {
        VergeHomeCard(icon: "gauge.with.dots.needle.67percent", iconColor: VergeColor.upload, title: "流量统计") {
            VStack(spacing: 16) {
                Group {
                    if store.coreState.isRunning, store.trafficHistory.count > 2 {
                        TrafficChartView(samples: store.trafficHistory, height: 128)
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(VergeColor.surface)
                            .frame(height: 128)
                            .overlay {
                                Text("启动后显示流量曲线")
                                    .font(VergeTypography.caption)
                                    .foregroundStyle(.tertiary)
                            }
                    }
                }
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(VergeColor.cardFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(VergeColor.border, lineWidth: 0.5)
                        }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
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

    private func syncSelection() {
        selectedGroupName = activeGroup?.name ?? ""
        selectedNodeName = activeGroup?.nodes.first(where: \.isSelected)?.name
            ?? activeGroup?.nodes.first?.name ?? ""
    }
}
