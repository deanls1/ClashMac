import SwiftUI

struct StatusHeaderView: View {
    @Bindable var store: AppStore

    var body: some View {
        HStack(spacing: 12) {
            StatusDot(isActive: store.coreState.isRunning)

            VStack(alignment: .leading, spacing: 2) {
                Text("Clash Mac")
                    .font(AppFont.panelTitle)
                Text(store.coreState.statusText)
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Clash Mac，\(store.coreState.statusText)")
    }
}

struct PowerControlView: View {
    @Bindable var store: AppStore

    private var isBusy: Bool {
        if case .starting = store.coreState { return true }
        if case .stopping = store.coreState { return true }
        return false
    }

    var body: some View {
        PrimaryActionButton(
            store.coreState.isRunning ? "停止代理" : "启动代理",
            symbol: store.coreState.isRunning ? "stop.fill" : "play.fill",
            role: store.coreState.isRunning ? .destructive : nil
        ) {
            Task { await store.togglePower() }
        }
        .disabled(isBusy)
    }
}

struct ModePickerView: View {
    @Bindable var store: AppStore

    var body: some View {
        Picker("出站模式", selection: $store.mode) {
            ForEach(RunMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .help("规则：按配置分流；全局：全部走代理；直连：全部直连")
        .onChange(of: store.mode) { _, newValue in
            Task { await store.setMode(newValue) }
        }
    }
}

struct TunToggleView: View {
    @Bindable var store: AppStore

    var body: some View {
        Toggle(isOn: $store.tunEnabled) {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text("增强模式 (TUN)")
                        .font(AppFont.body)
                    Text("全局接管 TCP/UDP 流量")
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
            }
        }
        .toggleStyle(.switch)
        .help("开启后通过 utun 虚拟网卡接管系统流量，需安装 Helper")
        .onChange(of: store.tunEnabled) { _, enabled in
            Task { await store.setTunEnabled(enabled) }
        }
    }
}

struct SystemProxyToggleView: View {
    @Bindable var store: AppStore

    var body: some View {
        Toggle(isOn: $store.systemProxyEnabled) {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text("系统代理")
                        .font(AppFont.body)
                    Text("HTTP / SOCKS → 127.0.0.1:\(store.mixedPort)")
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "globe")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
            }
        }
        .toggleStyle(.switch)
        .disabled(store.tunEnabled)
        .onChange(of: store.systemProxyEnabled) { _, enabled in
            Task { await store.setSystemProxyEnabled(enabled) }
        }
    }
}

struct ProxyGuardToggleView: View {
    @Bindable var store: AppStore

    var body: some View {
        Toggle(isOn: $store.proxyGuardEnabled) {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text("系统代理守护")
                        .font(AppFont.body)
                    Text("被其他应用改写时自动恢复")
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "shield.lefthalf.filled")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
            }
        }
        .toggleStyle(.switch)
        .disabled(!store.systemProxyEnabled || store.tunEnabled)
        .onChange(of: store.proxyGuardEnabled) { _, enabled in
            store.setProxyGuardEnabled(enabled)
        }
    }
}

struct TrafficStripView: View {
    let traffic: TrafficSnapshot

    var body: some View {
        HStack(spacing: 20) {
            trafficItem(symbol: "arrow.up", label: "上传", value: traffic.uploadFormatted, tint: .blue)
            trafficItem(symbol: "arrow.down", label: "下载", value: traffic.downloadFormatted, tint: .green)
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary.opacity(0.35))
        }
    }

    private func trafficItem(symbol: String, label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(AppFont.statValue)
            }
        }
    }
}

struct ProxyGroupPicker: View {
    @Bindable var store: AppStore

    var body: some View {
        if store.groups.count > 1 {
            Picker("策略组", selection: Binding(
                get: { store.activeGroupName ?? store.groups.first?.name ?? "" },
                set: { store.activeGroupName = $0 }
            )) {
                ForEach(store.groups) { group in
                    Text(group.name).tag(group.name)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }
}

struct ProxyListView: View {
    @Bindable var store: AppStore

    private var activeGroup: ProxyGroup? {
        guard let name = store.activeGroupName else { return store.groups.first }
        return store.groups.first { $0.name == name } ?? store.groups.first
    }

    var body: some View {
        SectionCard(title: "节点", symbol: "server.rack") {
            VStack(spacing: 0) {
                ProxyGroupPicker(store: store)

                if let group = activeGroup {
                    proxyRows(for: group)
                } else {
                    emptyState
                }
            }
        }
    }

    @ViewBuilder
    private func proxyRows(for group: ProxyGroup) -> some View {
        VStack(spacing: 2) {
            ForEach(group.nodes) { node in
                ProxyRowView(node: node) {
                    Task { await store.selectNode(group: group, node: node) }
                }
            }
        }
        .padding(.top, 4)

        Button {
            Task { await store.testDelays(for: group) }
        } label: {
            Label("测速全部", systemImage: "speedometer")
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .padding(.top, 6)
        .disabled(!store.coreState.isRunning)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("暂无节点", systemImage: "tray")
        } description: {
            Text("导入配置并启动代理后显示")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

struct ProxyRowView: View {
    let node: ProxyNode
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: node.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(node.isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
                    .symbolRenderingMode(.hierarchical)

                Text(node.name)
                    .font(AppFont.body)
                    .lineLimit(1)
                    .foregroundStyle(node.isAlive ? .primary : .secondary)

                Spacer(minLength: 8)

                LatencyBadge(milliseconds: node.delay)
            }
            .padding(.horizontal, 8)
            .frame(height: AppLayout.rowHeight)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct PanelFooterView: View {
    @Bindable var store: AppStore

    var body: some View {
        HStack {
            Button {
                MainWindowController.open()
            } label: {
                Label("控制台", systemImage: "macwindow")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)

            Button {
                MainWindowController.open(section: .settings)
            } label: {
                Label("设置", systemImage: "gearshape")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)

            Spacer()

            Text(store.version)
                .font(AppFont.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
