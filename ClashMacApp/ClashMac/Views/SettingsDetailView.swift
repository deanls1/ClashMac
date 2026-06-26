import AppKit
import SwiftUI

struct SettingsDetailView: View {
    @Bindable var store: AppStore

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VergePageHeader(DashboardSection.settings.pageTitle)

                HStack(alignment: .top, spacing: 16) {
                    leftColumn
                    rightColumn
                }
                .frame(maxWidth: 960)
                .frame(maxWidth: .infinity)

                if let message = store.updateStatusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(vergeCardBackground)
                }
            }
            .padding(VergeLayout.contentPadding)
        }
        .background(VergeColor.canvas)
        .sheet(isPresented: $store.isDNSOverwritePresented) {
            DNSOverwriteSheet(store: store)
        }
        .sheet(isPresented: $store.isTUNConfigPresented) {
            TUNConfigSheet(store: store)
        }
    }

    private var leftColumn: some View {
        VStack(spacing: 16) {
            VergeSettingsSection(title: "系统设置", symbol: "gearshape") {
                tunRow
                toggleRow("系统代理", $store.systemProxyEnabled) { v in Task { await store.setSystemProxyEnabled(v) } }
                toggleRow("开机自启", $store.launchAtLogin) { store.setLaunchAtLogin($0) }
            }

            VergeSettingsSection(title: "Clash 设置", symbol: "network") {
                dnsOverwriteRow
                toggleRow("IPv6", $store.ipv6Enabled) { _ in store.persistPreferences() }
                VergeSettingsRow(title: "日志等级") {
                    Picker("", selection: $store.logLevel) {
                        ForEach(LogLevel.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 100)
                    .onChange(of: store.logLevel) { _, level in store.setLogLevel(level) }
                }
                VergeSettingsRow(title: "端口设置") {
                    TextField("", value: $store.mixedPortInput, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 88)
                }
                toggleRow("HTTP 外部控制", $store.enableExternalController) { _ in
                    store.persistPreferences()
                }
                coreKernelSection
                VergeSettingsChevronRow(title: "更新 GeoData") {
                    Task { await store.updateGeoData() }
                }
            }

            VergeSettingsSection(title: "外观", symbol: "slider.horizontal.3") {
                VergeSettingsRow(title: "主题模式") {
                    Picker("", selection: $store.appearance) {
                        ForEach(AppAppearance.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .onChange(of: store.appearance) { _, _ in store.persistPreferences() }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var rightColumn: some View {
        VStack(spacing: 16) {
            VergeSettingsSection(title: "高级", symbol: "wrench.and.screwdriver") {
                VergeSettingsChevronRow(title: "备份设置", info: true) { store.createBackup() }
                VergeSettingsChevronRow(title: "配置目录", info: true) {
                    NSWorkspace.shared.open(RuntimeConfigBuilder.appSupportDirectory())
                }
                VergeSettingsChevronRow(title: "内核目录") {
                    NSWorkspace.shared.open(CoreUpdateService.coreDirectory())
                }
                VergeSettingsChevronRow(title: "退出") { store.requestQuit() }

                Divider().opacity(0.3)

                Button {
                    let url = store.exportDiagnostic()
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    HStack {
                        Label("导出诊断信息", systemImage: "doc.on.doc")
                        Spacer()
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain)

                HStack {
                    Label("Clash Mac 版本", systemImage: "doc.on.doc")
                    Spacer()
                    Text(store.version).font(.caption.monospaced())
                }
                .font(.subheadline)
            }

            VergeSettingsSection(title: "Helper & CLI", symbol: "terminal") {
                VergeSettingsRow(title: "Helper") {
                    HStack(spacing: 8) {
                        Text(store.helperStatus).font(.caption)
                        if !HelperInstaller.isInstalled() {
                            Button("安装") { store.installHelper() }.controlSize(.small)
                        }
                    }
                }
                Button("安装 clashmac 命令") { store.installCLI() }
                    .controlSize(.small)
                Button("应用并重启内核") { Task { await store.applyRuntimeSettings() } }
                    .buttonStyle(.borderedProminent)
                    .tint(VergeColor.accent)
                    .disabled(isBusy)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var coreKernelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VergeSettingsRow(title: "当前版本") {
                Text(store.version)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            if let latest = store.latestCoreVersion {
                VergeSettingsRow(title: "最新版本") {
                    HStack(spacing: 6) {
                        Text("v\(latest)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        if store.coreUpdateAvailable {
                            Text("有更新")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange.opacity(0.15)))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                Button {
                    Task { await store.checkCoreUpdate() }
                } label: {
                    if store.isCheckingCore {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("检查更新")
                    }
                }
                .disabled(store.isCheckingCore || store.isUpdatingCore)

                Button {
                    Task { await store.updateCore() }
                } label: {
                    if store.isUpdatingCore {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(store.coreUpdateAvailable ? "下载更新" : "下载/重装")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(VergeColor.accent)
                .disabled(store.isUpdatingCore || store.isCheckingCore)
            }
            .controlSize(.small)

            if !store.corePath.isEmpty && store.corePath != "—" {
                Text(store.corePath)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var tunRow: some View {
        VergeSettingsRow(title: "虚拟网卡模式") {
            HStack(spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { store.tunEnabled },
                    set: { v in Task { await store.setTunEnabled(v) } }
                ))
                .labelsHidden()
                Button { store.isTUNConfigPresented = true } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var dnsOverwriteRow: some View {
        VergeSettingsRow(title: "DNS 覆写") {
            HStack(spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { store.dnsOverwriteEnabled },
                    set: { store.setDNSOverwriteEnabled($0) }
                ))
                .labelsHidden()
                Button { store.isDNSOverwritePresented = true } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .disabled(!store.dnsOverwriteEnabled)
            }
        }
    }

    private var isBusy: Bool {
        if case .starting = store.coreState { return true }
        if case .stopping = store.coreState { return true }
        return false
    }

    private func toggleRow(_ title: String, _ binding: Binding<Bool>, onChange: @escaping (Bool) -> Void) -> some View {
        VergeSettingsRow(title: title) {
            Toggle("", isOn: binding)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .onChange(of: binding.wrappedValue) { _, v in onChange(v) }
        }
    }
}

#Preview {
    SettingsDetailView(store: {
        let s = AppStore()
        s.loadPreviewForDashboard()
        return s
    }())
}
