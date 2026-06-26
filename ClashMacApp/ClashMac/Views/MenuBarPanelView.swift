import SwiftUI

struct MenuBarPanelView: View {
    @Bindable var store: AppStore

    private var isBusy: Bool {
        if case .starting = store.coreState { return true }
        if case .stopping = store.coreState { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            panelHeader
            VergeModePills(store: store)

            HStack(spacing: 8) {
                compactToggle("TUN", $store.tunEnabled) { v in Task { await store.setTunEnabled(v) } }
                compactToggle("系统代理", $store.systemProxyEnabled) { v in Task { await store.setSystemProxyEnabled(v) } }
            }

            if store.coreState.isRunning {
                HStack(spacing: 14) {
                    Label(store.traffic.downloadFormatted, systemImage: "arrow.down.circle.fill")
                        .foregroundStyle(VergeColor.download)
                    Label(store.traffic.uploadFormatted, systemImage: "arrow.up.circle.fill")
                        .foregroundStyle(VergeColor.upload)
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))

                if let info = store.proxyIPInfo ?? store.directIPInfo {
                    HStack(spacing: 6) {
                        if let code = info.countryCode, let flag = NodeNameParser.countryFlag(from: code) {
                            Text(flag).font(.caption)
                        }
                        Text(info.ip)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        Text("\(info.latencyMs) ms")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(VergeColor.latency(info.latencyMs))
                    }
                }
            }

            ProxyListView(store: store)

            HStack {
                Button {
                    MainWindowController.open()
                } label: {
                    Label("打开主窗口", systemImage: "macwindow")
                }
                .buttonStyle(.borderedProminent)
                .tint(VergeColor.accent)
                .controlSize(.small)

                Spacer()

                Button {
                    MainWindowController.open(section: .settings)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)

                Button {
                    AppQuit.request()
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("退出 Clash Mac")
            }

            Button("退出 Clash Mac") {
                AppQuit.request()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .frame(width: 328)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(VergeColor.cardFill)
                .shadow(color: VergeColor.shadow, radius: 20, y: 8)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(VergeColor.border, lineWidth: 0.5)
                }
        }
    }

    private var panelHeader: some View {
        HStack(spacing: 12) {
            VergePowerButton(isRunning: store.coreState.isRunning, isBusy: isBusy) {
                Task { await store.togglePower() }
            }
            .scaleEffect(0.48)
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text("Clash Mac")
                    .font(.system(size: 14, weight: .bold))
                Text(store.coreState.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let node = store.currentSelectedNode {
                    Text(node)
                        .font(.caption2)
                        .foregroundStyle(VergeColor.accent)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
    }

    private func compactToggle(_ title: String, _ binding: Binding<Bool>, onChange: @escaping (Bool) -> Void) -> some View {
        Toggle(title, isOn: binding)
            .font(.caption)
            .toggleStyle(.switch)
            .controlSize(.mini)
            .onChange(of: binding.wrappedValue) { _, v in onChange(v) }
    }
}

#Preview {
    MenuBarPanelView(store: {
        let s = AppStore()
        s.coreState = .running
        s.groups = [ProxyGroup(name: "Proxy", nodes: [
            ProxyNode(name: "新加坡", delay: 42, isSelected: true),
            ProxyNode(name: "香港", delay: 68)
        ])]
        s.activeGroupName = "Proxy"
        s.traffic = TrafficSnapshot(uploadBytesPerSec: 128_000, downloadBytesPerSec: 1_024_000)
        return s
    }())
    .padding(32)
    .background(VergeColor.canvas)
}
