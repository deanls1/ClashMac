import AppKit
import SwiftUI

struct SettingsDetailView: View {
    @Bindable var store: AppStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VergePageHeader(DashboardSection.settings.pageTitle)

                settingsColumns

                if let message = store.updateStatusMessage {
                    statusMessageCard(message)
                }
                if let err = store.runtimeDataError {
                    statusMessageCard(err)
                }
            }
            .padding(VergeLayout.contentPadding)
            .frame(maxWidth: VergeLayout.settingsMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(VergeColor.canvas)
        .onAppear { store.syncSettingsWithRuntime() }
        .onChange(of: store.coreState) { _, _ in store.syncSettingsWithRuntime() }
    }

    private var settingsColumns: some View {
        HStack(alignment: .top, spacing: VergeLayout.settingsGridSpacing) {
            VStack(spacing: VergeLayout.settingsGridSpacing) {
                systemSettingsSection
                clashSettingsSection
                VergeSettingsSection(title: "内核", symbol: "shippingbox") {
                    coreKernelSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)

            VStack(spacing: VergeLayout.settingsGridSpacing) {
                appearanceSettingsSection
                advancedSettingsSection
                VergeSettingsSection(title: "GeoData", symbol: "globe.americas") {
                    geoDataSection
                }
                helperSection
                appLogSection
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func statusMessageCard(_ message: String) -> some View {
        let isError = message.contains("失败") || message.contains("错误") || message.contains("无法")
        let isProgress = store.isUpdatingCore || store.isUpdatingGeoData

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: isError ? "exclamationmark.circle.fill" : "info.circle.fill")
                .font(.body)
                .foregroundStyle(isError ? VergeColor.danger : VergeColor.accent)
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(VergeTypography.caption)
                    .foregroundStyle(isError ? VergeColor.danger : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isProgress {
                    ProgressView(value: max(store.isUpdatingCore ? store.coreUpdateProgress : store.geoUpdateProgress, 0.02))
                        .progressViewStyle(.linear)
                }
                if isError {
                    Button("查看应用日志") { store.openAppLogs() }
                        .controlSize(.small)
                }
            }
        }
        .padding(VergeLayout.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: VergeLayout.cardRadius, style: .continuous)
                .fill(isError ? VergeColor.danger.opacity(0.06) : VergeColor.accentSoft.opacity(0.45))
                .overlay {
                    RoundedRectangle(cornerRadius: VergeLayout.cardRadius, style: .continuous)
                        .strokeBorder(isError ? VergeColor.danger.opacity(0.2) : VergeColor.border, lineWidth: VergeStroke.hairline)
                }
        }
    }

    private var systemSettingsSection: some View {
        VergeSettingsSection(title: "系统设置", symbol: "gearshape") {
            tunRow
            toggleRow("系统代理", systemProxyBinding)
                .disabled(!store.coreState.isRunning || store.isPowerTransitioning)
            Group {
                toggleRow("系统代理守护", proxyGuardBinding)
            }
            .disabled(store.tunModeToggleValue || !store.coreState.isRunning)
            .opacity(store.tunModeToggleValue || !store.coreState.isRunning ? 0.45 : 1)
            toggleRow("开机自启", launchAtLoginBinding)
            toggleRow("启动时自动连接", resumeLastProxyStateBinding)
            toggleRow("轻量模式", lightweightModeBinding)
            toggleRow("全局快捷键", hotkeysBinding)
            if store.hotkeysEnabled {
                toggleRow("全局热键", globalHotkeyBinding)
                VergeSettingsRow(title: "快捷键") {
                    Text("⌘⇧P 启动/停止")
                        .font(VergeTypography.mono)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var clashSettingsSection: some View {
        VergeSettingsSection(title: "Clash 设置", symbol: "network") {
            dnsOverwriteRow
            toggleRow("IPv6", ipv6Binding)
            VergeSettingsRow(title: "日志等级") {
                Picker("", selection: $store.logLevel) {
                    ForEach(LogLevel.allCases) { level in
                        Text(level.label).tag(level)
                    }
                }
                .labelsHidden()
                .frame(width: 108)
                .onChange(of: store.logLevel) { _, level in store.setLogLevel(level) }
            }
            VergeSettingsRow(title: "端口设置") {
                portField(value: $store.mixedPortInput) {
                    store.persistPreferences()
                }
            }
            VergeSettingsNote(
                text: "默认 \(ClashMacPorts.defaultMixedPort)，与 Clash Verge Rev（7897）错开"
            )
            toggleRow("HTTP 外部控制", externalControllerBinding)
            if store.enableExternalController {
                VergeSettingsRow(title: "控制端口") {
                    portField(value: $store.controllerPortInput) {
                        store.persistPreferences()
                    }
                }
            }
        }
    }

    private var appearanceSettingsSection: some View {
        VergeSettingsSection(title: "基础设置", symbol: "slider.horizontal.3") {
            VergeSettingsWideRow(title: "主题模式") {
                Picker("", selection: $store.appearance) {
                    ForEach(AppAppearance.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: store.appearance) { _, _ in store.persistPreferences() }
            }
            VergeSettingsWideRow(title: "托盘图标") {
                MenuBarIconSetting(store: store)
            }
        }
    }

    private var advancedSettingsSection: some View {
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
    }

    private var helperSection: some View {
        VergeSettingsSection(title: "Helper & CLI", symbol: "terminal") {
            VergeSettingsRow(title: "Helper") {
                VergeStatusBadge(
                    text: helperShortStatus,
                    tone: HelperInstaller.isInstalled() ? .success : .warning
                )
            }
            VergeSettingsNote(text: store.helperStatus)
            VergeSettingsActionBar(actions: helperActions)
        }
    }

    private var helperShortStatus: String {
        if HelperInstaller.isInstalled() { return "已安装" }
        switch HelperInstaller.serviceStatus() {
        case .requiresApproval: return "待批准"
        case .notRegistered, .notFound: return "未注册"
        default: return "未安装"
        }
    }

    private var helperActions: [VergeSettingsActionBar.Action] {
        var actions: [VergeSettingsActionBar.Action] = []
        actions.append(.init(
            title: HelperInstaller.isInstalled() ? "重装 Helper" : "安装 Helper",
            prominent: true,
            disabled: isBusy || !HelperInstaller.isBundled(),
            handler: { store.installHelper() }
        ))
        actions.append(.init(title: "安装 CLI", handler: { store.installCLI() }))
        actions.append(.init(
            title: "应用并重启",
            prominent: HelperInstaller.isInstalled(),
            disabled: isBusy,
            handler: { Task { await store.applyRuntimeSettings() } }
        ))
        return actions
    }

    private var appLogSection: some View {
        VergeSettingsSection(title: "调试", symbol: "ladybug") {
            VergeSettingsRow(title: "应用日志") {
                HStack(spacing: 10) {
                    VergeStatusBadge(
                        text: "\(store.appLogEntries.count) 条",
                        tone: store.appLogEntries.contains(where: { $0.level == .error }) ? .danger : .neutral
                    )
                    Button("查看") { store.openAppLogs() }
                        .controlSize(.small)
                    Button("清除") { store.clearAppLogs() }
                        .controlSize(.small)
                }
            }
            if let last = store.appLogEntries.last {
                VergeSettingsNote(text: "最近：\(last.message)")
            }
        }
    }

    private var geoDataSection: some View {
        Group {
            VergeSettingsRow(title: "本地状态") {
                VergeStatusBadge(
                    text: store.geoDataComplete ? "已就绪" : "缺少 \(store.geoMissingFiles.count) 个",
                    tone: store.geoDataComplete ? .success : .warning
                )
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
                VergeSettingsNote(text: "缺失：\(store.geoMissingFiles.joined(separator: "、"))")
            }
            VergeSettingsActionBar(actions: [
                .init(
                    title: "检查状态",
                    disabled: store.isCheckingGeoData || store.isUpdatingGeoData,
                    loading: store.isCheckingGeoData,
                    handler: { Task { await store.checkGeoData() } }
                ),
                .init(
                    title: store.geoDataComplete ? "重新下载" : "下载 GeoData",
                    prominent: true,
                    disabled: store.isUpdatingGeoData || store.isCheckingGeoData,
                    loading: store.isUpdatingGeoData,
                    handler: { Task { await store.updateGeoData() } }
                ),
            ])
        }
    }

    @ViewBuilder
    private var coreKernelSection: some View {
        VergeSettingsRow(title: "当前版本") {
            Text(store.coreVersionLabel)
                .font(VergeTypography.mono)
                .foregroundStyle(.secondary)
        }
        if let latest = store.latestCoreVersion {
            VergeSettingsRow(title: "最新版本") {
                HStack(spacing: 8) {
                    Text("v\(latest)")
                        .font(VergeTypography.mono)
                        .foregroundStyle(.secondary)
                    if store.coreUpdateAvailable {
                        VergeStatusBadge(text: "有更新", tone: .warning)
                    }
                }
            }
        }
        VergeSettingsActionBar(actions: [
            .init(
                title: "检查更新",
                disabled: store.isCheckingCore || store.isUpdatingCore,
                loading: store.isCheckingCore,
                handler: { Task { await store.checkCoreUpdate() } }
            ),
            .init(
                title: store.coreUpdateAvailable ? "下载更新" : "下载/重装",
                prominent: true,
                disabled: store.isUpdatingCore || store.isCheckingCore,
                loading: store.isUpdatingCore,
                handler: { Task { await store.updateCore() } }
            ),
        ])
        if !store.corePath.isEmpty && store.corePath != "—" {
            VergePathChip(path: store.corePath)
        }
    }

    private var tunRow: some View {
        VergeSettingsToggleRow(
            title: "虚拟网卡模式",
            isOn: Binding(
                get: { store.tunModeToggleValue },
                set: { v in Task { await store.setTunEnabled(v) } }
            ),
            configAction: { store.isTUNConfigPresented = true }
        )
        .disabled(!store.coreState.isRunning || store.isPowerTransitioning)
    }

    private var dnsOverwriteRow: some View {
        VergeSettingsToggleRow(
            title: "DNS 覆写",
            isOn: Binding(
                get: { store.dnsOverwriteEnabled },
                set: { store.setDNSOverwriteEnabled($0) }
            ),
            configEnabled: store.dnsOverwriteEnabled,
            configAction: { store.isDNSOverwritePresented = true }
        )
    }

    private var isBusy: Bool {
        store.isPowerTransitioning
    }

    private var systemProxyBinding: Binding<Bool> {
        Binding(
            get: { store.systemProxyToggleValue },
            set: { value in Task { await store.setSystemProxyEnabled(value) } }
        )
    }

    private var proxyGuardBinding: Binding<Bool> {
        Binding(
            get: { store.proxyGuardEnabled },
            set: { store.setProxyGuardEnabled($0) }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { store.launchAtLogin },
            set: { store.setLaunchAtLogin($0) }
        )
    }

    private var hotkeysBinding: Binding<Bool> {
        Binding(
            get: { store.hotkeysEnabled },
            set: { store.setHotkeysEnabled($0) }
        )
    }

    private var lightweightModeBinding: Binding<Bool> {
        Binding(
            get: { store.lightweightModeEnabled },
            set: { store.setLightweightModeEnabled($0) }
        )
    }

    private var resumeLastProxyStateBinding: Binding<Bool> {
        Binding(
            get: { store.resumeLastProxyState },
            set: {
                store.resumeLastProxyState = $0
                AppPreferences.resumeLastProxyState = $0
            }
        )
    }

    private var globalHotkeyBinding: Binding<Bool> {
        Binding(
            get: { store.globalHotkey },
            set: { store.setGlobalHotkey($0) }
        )
    }

    private var ipv6Binding: Binding<Bool> {
        Binding(
            get: { store.ipv6Enabled },
            set: {
                store.ipv6Enabled = $0
                store.persistPreferences()
            }
        )
    }

    private var externalControllerBinding: Binding<Bool> {
        Binding(
            get: { store.enableExternalController },
            set: {
                store.enableExternalController = $0
                store.persistPreferences()
            }
        )
    }

    private func toggleRow(_ title: String, _ binding: Binding<Bool>) -> some View {
        VergeSettingsToggleRow(title: title, isOn: binding)
    }

    private func portField(value: Binding<Int>, onChange: @escaping () -> Void) -> some View {
        TextField("", value: value, format: .number)
            .textFieldStyle(.plain)
            .font(VergeTypography.mono)
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: 108)
            .background { vergeFieldBackground }
            .onChange(of: value.wrappedValue) { _, _ in onChange() }
    }
}

/// 设置页托盘图标预览
private struct MenuBarIconSetting: View {
    @Bindable var store: AppStore

    var body: some View {
        HStack(spacing: 10) {
            MenuBarIconPreview(customPath: store.customMenuBarIconPath)
            Button("默认") { store.clearCustomMenuBarIcon() }
                .buttonStyle(.bordered)
                .tint(store.customMenuBarIconPath == nil ? VergeColor.accent : nil)
                .controlSize(.small)
            Button("选择图片…") { store.pickCustomMenuBarIcon() }
                .controlSize(.small)
        }
    }
}

private struct MenuBarIconPreview: View {
    let customPath: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(VergeColor.surface)
                .frame(width: 36, height: 26)
            Group {
                if let image = MenuBarIconStore.loadImage(from: customPath)
                    ?? MenuBarIconStore.defaultAppIcon() {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                } else {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(VergeColor.border, lineWidth: 0.5)
        )
    }
}

#Preview {
    SettingsDetailView(store: {
        let s = AppStore()
        s.loadPreviewForDashboard()
        return s
    }())
}
