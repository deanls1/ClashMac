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
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                VergeCardIcon(symbol: icon, color: iconColor)
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Spacer()
                trailing
            }
            content
        }
        .padding(20)
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

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VergePageHeader(DashboardSection.home.pageTitle) {
                    VergeHeaderIconButton(symbol: "paintbrush", help: "主题") {
                        store.selectedSection = .settings
                    }
                    VergeHeaderIconButton(symbol: "questionmark.circle", help: "帮助") { }
                    VergeHeaderIconButton(symbol: "gearshape", help: "设置") {
                        store.selectedSection = .settings
                    }
                }

                if !store.startupBanners.isEmpty {
                    ForEach(store.startupBanners, id: \.kind) { banner in
                        VergeStartupBanner(
                            banner: banner,
                            onAction: { Task { await store.actOnStartupBanner(banner) } },
                            onDismiss: { store.dismissStartupBanner(banner.kind) }
                        )
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    profileCard
                    currentNodeCard
                }

                HStack(alignment: .top, spacing: 16) {
                    networkCard
                    proxyModeCard
                }

                trafficCard

                HStack(alignment: .top, spacing: 16) {
                    websiteTestCard
                    clashInfoCard
                }

                systemInfoCard
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
                    .font(.caption)
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
                            .font(.subheadline.weight(.semibold))
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
                .font(.caption)
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
                            .font(.caption)
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
                        .font(.subheadline)
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
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
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

    private var proxyModeCard: some View {
        VergeHomeCard(icon: "arrow.triangle.branch", iconColor: VergeColor.accent, title: "代理模式") {
            VStack(alignment: .leading, spacing: 12) {
                VergeModePills(store: store)
                Text(modeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(VergeColor.surface)
                    }
            }
        }
    }

    private var modeDescription: String {
        switch store.mode {
        case .rule: "按照规则文件分流，国内直连、国外走代理"
        case .global: "所有流量走代理"
        case .direct: "所有流量直连"
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
                                    .font(.caption)
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
                    VergeMiniStat(title: "内核占用", value: "—", color: .secondary, symbol: "memorychip")
                }
            }
        }
    }

    private var websiteTestCard: some View {
        VergeHomeCard(icon: "antenna.radiowaves.left.and.right", iconColor: VergeColor.accent, title: "网站测试") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                VergeWebsiteTestTile(name: "Apple", symbol: "applelogo", tint: .primary) {
                    Task { await store.refreshIPInfo() }
                }
                VergeWebsiteTestTile(name: "GitHub", symbol: "chevron.left.forwardslash.chevron.right", tint: .primary) {
                    Task { await store.refreshIPInfo() }
                }
                VergeWebsiteTestTile(name: "Google", symbol: "g.circle.fill", tint: VergeColor.download) {
                    Task { await store.refreshIPInfo() }
                }
                VergeWebsiteTestTile(name: "YouTube", symbol: "play.rectangle.fill", tint: VergeColor.danger) {
                    Task { await store.refreshIPInfo() }
                }
            }
        }
    }

    private var clashInfoCard: some View {
        VergeHomeCard(icon: "doc.text", iconColor: VergeColor.upload, title: "Clash 信息") {
            infoTable([
                ("内核版本", store.version),
                ("系统代理地址", "127.0.0.1:\(store.mixedPort)"),
                ("混合代理端口", "\(store.mixedPort)"),
                ("规则数量", "\(store.rules.count)"),
            ])
        }
    }

    private var systemInfoCard: some View {
        VergeHomeCard(icon: "info.circle", iconColor: VergeColor.danger, title: "系统信息") {
            VStack(spacing: 0) {
                infoRow("操作系统", ProcessInfo.processInfo.operatingSystemVersionString)
                Divider().opacity(0.25).padding(.leading, 4)
                HStack {
                    Text("开机自启").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    VergeStatusBadge(
                        text: store.launchAtLogin ? "已启用" : "未启用",
                        color: store.launchAtLogin ? VergeColor.running : .secondary
                    )
                }
                .padding(.vertical, 10)
                Divider().opacity(0.25).padding(.leading, 4)
                infoRow("运行模式", store.tunEnabled ? "TUN 模式" : "系统代理")
                Divider().opacity(0.25).padding(.leading, 4)
                infoRow("Clash Mac", store.version)
            }
        }
    }

    private func infoTable(_ rows: [(String, String)]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                infoRow(row.0, row.1)
                if index < rows.count - 1 {
                    Divider().opacity(0.25).padding(.leading, 4)
                }
            }
        }
    }

    private func infoRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.weight(.medium).monospacedDigit())
        }
        .padding(.vertical, 10)
    }

    private func syncSelection() {
        selectedGroupName = activeGroup?.name ?? ""
        selectedNodeName = activeGroup?.nodes.first(where: \.isSelected)?.name
            ?? activeGroup?.nodes.first?.name ?? ""
    }
}
