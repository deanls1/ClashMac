import AppKit
import SwiftUI

struct SettingsDetailView: View {
    @Bindable var store: AppStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VergePageHeader(DashboardSection.settings.pageTitle)

                VStack(spacing: 16) {
                    VergeSettingsSection(title: "系统设置", symbol: "gearshape") {
                        tunRow
                        toggleRow("系统代理", $store.systemProxyEnabled) { v in
                            Task { await store.setSystemProxyEnabled(v) } }
                        Group {
                            toggleRow("系统代理守护", $store.proxyGuardEnabled) { store.setProxyGuardEnabled($0) }
                        }
                        .disabled(store.tunEnabled)
                        .opacity(store.tunEnabled ? 0.45 : 1)
                        toggleRow("开机自启", $store.launchAtLogin) { store.setLaunchAtLogin($0) }
                        toggleRow("全局快捷键", $store.hotkeysEnabled) { store.setHotkeysEnabled($0) }
                        if store.hotkeysEnabled {
                            toggleRow("全局热键（需辅助功能）", $store.globalHotkey) { store.setGlobalHotkey($0) }
                            VergeSettingsRow(title: "快捷键") {
                                Text("⌘⇧P 启动/停止")
                                    .font(VergeTypography.mono)
                                    .foregroundStyle(.secondary)
                            }
                        }
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
                            .frame(width: 110)
                            .onChange(of: store.logLevel) { _, level in store.setLogLevel(level) }
                        }
                        VergeSettingsRow(title: "端口设置") {
                            TextField("", value: $store.mixedPortInput, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 96)
                        }
                        toggleRow("HTTP 外部控制", $store.enableExternalController) { _ in
                            store.persistPreferences()
                        }
                        if store.enableExternalController {
                            VergeSettingsRow(title: "控制端口") {
                                TextField("", value: $store.controllerPortInput, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 96)
                                    .onChange(of: store.controllerPortInput) { _, _ in
                                        store.persistPreferences()
                                    }
                            }
                        }
                        coreKernelSection
                        geoDataSection
                    }

                    VergeSettingsSection(title: "外观", symbol: "slider.horizontal.3") {
                        VergeSettingsRow(title: "主题模式") {
                            Picker("", selection: $store.appearance) {
                                ForEach(AppAppearance.allCases) { mode in
                                    Text(mode.label).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 280)
                            .onChange(of: store.appearance) { _, _ in store.persistPreferences() }
                        }
                        VergeSettingsRow(title: "托盘图标") {
                            Picker("", selection: Binding(
                                get: { store.menuBarIconStyle },
                                set: { store.setMenuBarIconStyle($0) }
                            )) {
                                ForEach(MenuBarIconStyle.allCases) { style in
                                    Text(style.label).tag(style)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                        }
                    }

                    VergeSettingsSection(title: "高级", symbol: "wrench.and.screwdriver") {
                        VergeSettingsChevronRow(title: "配置目录", info: true) {
                            NSWorkspace.shared.open(RuntimeConfigBuilder.appSupportDirectory())
                        }
                        VergeSettingsChevronRow(title: "内核目录") {
                            NSWorkspace.shared.open(CoreUpdateService.coreDirectory())
                        }
                        VergeSettingsChevronRow(title: "GeoData 目录") {
                            NSWorkspace.shared.open(GeoDataUpdateService.geoDirectory())
                        }
                        VergeSettingsChevronRow(title: "导出诊断信息") {
                            let url = store.exportDiagnostic()
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                        VergeSettingsRow(title: "Clash Mac 版本") {
                            Text(AppInfo.versionLabel)
                                .font(VergeTypography.mono)
                                .foregroundStyle(.secondary)
                        }
                        VergeSettingsChevronRow(title: "退出") { store.requestQuit() }
                    }

                    VergeSettingsSection(title: "Helper & CLI", symbol: "terminal") {
                        VergeSettingsRow(title: "Helper") {
                            HStack(spacing: 8) {
                                Text(store.helperStatus)
                                    .font(VergeTypography.caption)
                                    .foregroundStyle(.secondary)
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
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)

                if let message = store.updateStatusMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(message)
                            .font(VergeTypography.caption)
                            .foregroundStyle(store.isUpdatingCore || store.isUpdatingGeoData ? VergeColor.accent : .secondary)
                        if store.isUpdatingCore {
                            ProgressView(value: max(store.coreUpdateProgress, 0.02))
                                .progressViewStyle(.linear)
                        } else if store.isUpdatingGeoData {
                            ProgressView(value: max(store.geoUpdateProgress, 0.02))
                                .progressViewStyle(.linear)
                        }
                    }
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
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

    private var geoDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VergeSettingsRow(title: "本地状态") {
                Text(store.geoDataComplete ? "已就绪" : "缺少 \(store.geoMissingFiles.count) 个文件")
                    .font(VergeTypography.mono)
                    .foregroundStyle(store.geoDataComplete ? VergeColor.running : .orange)
            }
            if let local = store.geoLocalRelease {
                VergeSettingsRow(title: "当前版本") {
                    Text(local)
                        .font(VergeTypography.mono)
                        .foregroundStyle(.secondary)
                }
            }
            if let latest = store.geoDataRelease {
                VergeSettingsRow(title: "最新版本") {
                    Text(latest)
                        .font(VergeTypography.mono)
                        .foregroundStyle(.secondary)
                }
            }
            if !store.geoMissingFiles.isEmpty {
                Text("缺失：\(store.geoMissingFiles.joined(separator: "、"))")
                    .font(VergeTypography.small)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Button {
                    Task { await store.checkGeoData() }
                } label: {
                    if store.isCheckingGeoData {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("检查状态")
                    }
                }
                .disabled(store.isCheckingGeoData || store.isUpdatingGeoData)

                Button {
                    Task { await store.updateGeoData() }
                } label: {
                    if store.isUpdatingGeoData {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(store.geoDataComplete ? "重新下载" : "下载 GeoData")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(VergeColor.accent)
                .disabled(store.isUpdatingGeoData || store.isCheckingGeoData)
            }
            .controlSize(.regular)
        }
    }

    private var coreKernelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VergeSettingsRow(title: "当前版本") {
                Text(store.coreVersionLabel)
                    .font(VergeTypography.mono)
                    .foregroundStyle(.secondary)
            }
            if let latest = store.latestCoreVersion {
                VergeSettingsRow(title: "最新版本") {
                    HStack(spacing: 6) {
                        Text("v\(latest)")
                            .font(VergeTypography.mono)
                            .foregroundStyle(.secondary)
                        if store.coreUpdateAvailable {
                            Text("有更新")
                                .font(VergeTypography.smallMedium)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.orange.opacity(0.14)))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            HStack(spacing: 10) {
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
            .controlSize(.regular)

            if !store.corePath.isEmpty && store.corePath != "—" {
                Text(store.corePath)
                    .font(VergeTypography.small)
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
