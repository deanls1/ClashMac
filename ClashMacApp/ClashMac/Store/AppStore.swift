import AppKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppStore {
    // Core
    var coreState: CoreState = .stopped
    var mode: RunMode = .rule
    var tunEnabled: Bool = false
    var systemProxyEnabled: Bool = true
    private(set) var isSystemProxyActive: Bool = false
    var proxyGuardEnabled: Bool = true
    var corePath: String = "—"
    var helperStatus: String = "未安装"

    // Profiles
    var profiles: [Profile] = []
    var activeProfile: Profile?

    // Proxy
    var groups: [ProxyGroup] = []
    private(set) var proxyDataRevision = 0
    var traffic: TrafficSnapshot = .zero
    var version: String = "—"
    var activeGroupName: String?

    // Connections / Rules / Logs / Unlock
    var connections: [ConnectionItem] = []
    var closedConnections: [ConnectionItem] = []
    var connectionTab: ConnectionTab = .active
    var connectionFilter = ""
    var connectionFilterOptions = FilterOptions()
    var rules: [RuleItem] = []
    var rulesFilter = ""
    var rulesFilterOptions = FilterOptions()
    /// 规则列表虚拟化：过滤后的规则在 `rules` 中的下标，供 NSTableView 按需渲染。
    private(set) var displayedRuleIndices: [Int] = []
    private(set) var rulesMatchCount = 0
    private(set) var isRulesFilterPending = false
    /// 规则数据版本号，用于虚拟列表在静默刷新后更新可见行。
    private(set) var rulesDataRevision = 0
    /// 上次成功刷新规则的时间，用于切入规则页时节流全量拉取（不参与 UI 观察）。
    @ObservationIgnored private var lastRulesRefreshAt: Date?
    var isLoadingRules = false
    var logEntries: [LogEntry] = []
    var appLogEntries: [LogEntry] = []
    var logsSource: LogsSource = .core
    var logLevel: LogLevel = .info
    var logsFilter = ""
    var logsFilterOptions = FilterOptions()
    var logsDisplayFilter: LogsDisplayFilter = .all
    var logsPaused = false
    var unlockTargets: [UnlockTarget] = []
    var rulesYAML: String = ""
    var trafficHistory: [TrafficSample] = []
    var trafficTotals = TrafficTotals()

    // Add rule
    var isAddRulePresented = false
    var newRuleType: RuleAddType = .domainSuffix
    var newRulePayload = ""
    var newRuleProxy = "Proxy"

    // Unlock custom
    var customUnlockName = ""
    var customUnlockURL = ""

    // System prefs
    var launchAtLogin = false
    var hotkeysEnabled = true
    var globalHotkey = false
    /// 轻量模式：关闭主窗口后仅保留内核与菜单栏，释放界面并暂停全部实时刷新，最大限度降低占用（对齐 Verge Lite）。
    var lightweightModeEnabled = false
    /// 启动时自动恢复上次代理运行状态。
    var resumeLastProxyState = true
    var customMenuBarIconPath: String?
    /// 递增以强制 MenuBarExtra 重建托盘图标（SwiftUI 不会自动刷新 label）。
    var menuBarIconRevision = 0

    // Runtime settings
    var mixedPortInput = ClashMacPorts.defaultMixedPort
    var controllerPortInput = ClashMacPorts.defaultControllerPort
    var enableExternalController = false
    var dnsServersText = "223.5.5.5, 8.8.8.8"
    var ipv6Enabled = false
    var dnsOverwriteEnabled = true
    var dnsConfig = DNSConfig.vergeDefault
    var tunConfig = TUNConfig.vergeDefault

    // Update status
    var isUpdatingCore = false
    var isCheckingCore = false
    var latestCoreVersion: String?
    var coreUpdateAvailable = false
    var coreUpdateProgress: Double = 0
    var geoUpdateProgress: Double = 0
    var isCheckingGeoData = false
    var geoDataRelease: String?
    var geoLocalRelease: String?
    var geoMissingFiles: [String] = []
    var isUpdatingGeoData = false
    var updateStatusMessage: String?
    var isRefreshingSubscriptions = false
    var testingNodeIDs: Set<String> = []
    var isTestingAllGroups = false
    var appearance: AppAppearance = .system
    var startupBanners: [StartupBanner] = []
    var dismissedBannerKinds: Set<StartupBanner.Kind> = []
    var isProfileReorderMode = false
    var websiteTests: [WebsiteTestItem] = WebsiteTestItem.defaults
    var isTestingWebsites = false
    var isDNSOverwritePresented = false
    var isTUNConfigPresented = false
    var isProxyProvidersPresented = false
    var proxyProviders: [ProxyProvider] = []
    var updatingProviderNames: Set<String> = []
    var runtimeDataError: String?

    // UI
    var selectedSection: DashboardSection = .home
    /// 仪表板窗口是否可见；窗口关闭（仅菜单栏）时暂停流量流与轮询以降低占用。
    private(set) var isDashboardVisible = false
    var isSettingsPresented = false
    var isRulesEditorPresented = false
    var isProfileEditorPresented = false
    var profileEditorYAML = ""
    var profileEditorTitle = ""
    var profileEditorSection: ProfileYAMLSection = .full
    var profileEditorTarget: Profile?
    var isRefreshing = false
    var subscriptionURLInput: String = ""
    var subscriptionNameInput: String = "新订阅"

    private var runtime = RuntimeConfig.default
    private let helper = TunnelHelperClient()
    private let proxyGuard = ProxyGuard()
    private let logStreamer = MihomoLogStreamer()
    private let trafficStreamer = MihomoTrafficStreamer()
    private let memoryStreamer = MihomoMemoryStreamer()
    private var refreshTask: Task<Void, Never>?
    private var connectionsTask: Task<Void, Never>?
    private var rulesFilterTask: Task<Void, Never>?
    private var rulesPrefetchTask: Task<Void, Never>?
    private var startupCompletionTask: Task<Void, Never>?
    private var startTask: Task<Void, Never>?
    private var usingHelper = false
    private var connectionByteSnapshot: [String: (upload: Int, download: Int)] = [:]
    private var pendingLogEntries: [LogEntry] = []
    private var logFlushTask: Task<Void, Never>?

    var api: MihomoAPIClient { MihomoAPIClient(runtime: runtime) }
    var mixedPort: Int { runtime.mixedPort }

    var isProxyEnabled: Bool { coreState.isRunning }

    /// 内核是否正在以 TUN（Helper）方式运行。
    var isTunRuntimeActive: Bool { coreState.isRunning && usingHelper }

    /// 托盘菜单顶部状态行。
    var trayStatusLine: String {
        switch coreState {
        case .stopped: return "代理已停止"
        case .starting: return "启动中…"
        case .stopping: return "停止中…"
        case .error: return "启动失败"
        case .running:
            // 保持精简，避免托盘菜单被状态行撑宽：仅「运行中 · 路由方式 · 出站模式」。
            let routing: String
            if isTunRuntimeActive {
                routing = "TUN"
            } else if isSystemProxyActive {
                routing = "系统代理"
            } else {
                routing = "直连"
            }
            return "运行中 · \(routing) · \(mode.label)"
        }
    }

    var isPowerTransitioning: Bool {
        if case .starting = coreState { return true }
        if case .stopping = coreState { return true }
        return false
    }

    /// TUN 开关显示值：仅运行中且 TUN 实际生效时为 true。
    var tunModeToggleValue: Bool {
        coreState.isRunning && isTunRuntimeActive
    }

    /// 系统代理开关显示值：仅运行中且系统代理实际生效时为 true（TUN 运行时必为 false）。
    var systemProxyToggleValue: Bool {
        coreState.isRunning && !isTunRuntimeActive && isSystemProxyActive
    }

    var currentSelectedNode: String? {
        groups.flatMap(\.nodes).first(where: \.isSelected)?.name
    }

    var coreVersionLabel: String {
        CoreUpdateService.displayVersion(from: version == "—" ? nil : version)
    }

    var coreStartedAt: Date?
    var coreMemoryLabel = "—"

    var coreUptimeLabel: String {
        guard coreState.isRunning, let coreStartedAt else { return "—" }
        let seconds = max(0, Int(Date().timeIntervalSince(coreStartedAt)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 { return "\(hours) 小时 \(minutes) 分" }
        if minutes > 0 { return "\(minutes) 分 \(secs) 秒" }
        return "\(secs) 秒"
    }

    var isCoreBannerBusy: Bool {
        isUpdatingCore || isCheckingCore
    }

    var isGeoBannerBusy: Bool {
        isUpdatingGeoData || isCheckingGeoData
    }

    var geoDataComplete: Bool {
        geoMissingFiles.isEmpty && GeoDataUpdateService.fileStatus().allSatisfy(\.exists)
    }

    init() {
        AppSupportMigrator.migrateIfNeeded()
        AppPreferences.migrateDefaultPortsIfNeeded()
        helperStatus = HelperInstaller.installStatusText()
        unlockTargets = UnlockTargetStore.load()
        launchAtLogin = LaunchAtLoginService.isEnabled
        AppPreferences.apply(to: self)
        syncSettingsWithRuntime()
        runtime = AppPreferences.makeRuntimeConfig(mode: mode)
        AppLifecycleDelegate.store = self
        AppLoggerBridge.shared.handler = { [weak self] level, message in
            self?.appendAppLog(level: level, message: message)
        }
        appendAppLog(level: .info, message: "Clash Mac 启动 · \(AppInfo.versionLabel)")
        appendAppLog(level: .info, message: "Helper: \(helperStatus)")
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            loadPreviewData()
        } else {
            Task { await bootstrapProfiles() }
            registerHotkeys()
        }
    }

    func prepareForQuit() async {
        HotkeyService.shared.removeMonitor()
        startTask?.cancel()
        startupCompletionTask?.cancel()
        startupCompletionTask = nil
        rulesPrefetchTask?.cancel()
        rulesFilterTask?.cancel()
        stopAllLiveUpdates()
        proxyGuard.stop()

        let shouldStopHelper = usingHelper
        let helperClient = helper
        Task.detached(priority: .utility) {
            SystemProxyController.disableActiveServiceProxy()
            if shouldStopHelper {
                helperClient.stopTunnelSynchronously(timeout: 1)
            }
            CoreProcessController.shared.stop(waitForExit: false)
            MihomoProcessRegistry.clearManagedPID()
            MihomoProcessRegistry.terminateManagedInstancesSync()
        }
        usingHelper = false
        coreState = .stopped
    }

    func requestQuit() {
        AppQuit.request()
    }

    var searchedConnections: [ConnectionItem] {
        filterConnections(connections)
    }

    var searchedClosedConnections: [ConnectionItem] {
        filterConnections(closedConnections)
    }

    var filteredRules: [RuleItem] {
        displayedRuleIndices.compactMap { idx in
            guard rules.indices.contains(idx) else { return nil }
            return rules[idx]
        }
    }

    var filteredLogs: [LogEntry] {
        logEntries.filter { entry in
            logsDisplayFilter.matches(entry.level)
                && logsFilterOptions.matches(entry.message, query: logsFilter)
        }
    }

    var filteredAppLogs: [LogEntry] {
        appLogEntries.filter { entry in
            logsDisplayFilter.matches(entry.level)
                && logsFilterOptions.matches(entry.message, query: logsFilter)
        }
    }

    func appendAppLog(level: LogLevel, message: String) {
        appLogEntries.append(LogEntry(level: level, message: message))
        if appLogEntries.count > 800 {
            appLogEntries.removeFirst(appLogEntries.count - 800)
        }
    }

    func clearAppLogs() { appLogEntries.removeAll() }

    func openAppLogs() {
        logsSource = .app
        selectedSection = .logs
    }

    private func filterConnections(_ list: [ConnectionItem]) -> [ConnectionItem] {
        list.filter { item in
            let blob = "\(item.host) \(item.process) \(item.rule) \(item.chain)"
            return connectionFilterOptions.matches(blob, query: connectionFilter)
        }
    }

    func registerHotkeys() {
        guard hotkeysEnabled else {
            HotkeyService.shared.removeMonitor()
            return
        }
        HotkeyService.shared.registerTogglePower(global: globalHotkey) { [weak self] in
            Task { await self?.togglePower() }
        }
    }

    /// 将设置页开关与系统/运行时实际状态对齐（不覆盖 UserDefaults 中的用户意图）。
    func syncSettingsWithRuntime() {
        launchAtLogin = LaunchAtLoginService.isEnabled
        applyProxyStateToSettings()

        if hotkeysEnabled {
            let wantsGlobal = AppPreferences.globalHotkey
            globalHotkey = wantsGlobal && HotkeyService.shared.isGlobalMonitorActive
        }

        // networksetup 子进程较慢，放到后台执行，避免阻塞主线程造成卡顿。
        refreshSystemProxyActiveInBackground()
        MenuBarManager.shared.refreshIconAndTooltip()
    }

    private func applyProxyStateToSettings() {
        // 开关始终反映用户偏好；实际生效状态见 isSystemProxyActive / isTunRuntimeActive。
        tunEnabled = AppPreferences.tunEnabled
        systemProxyEnabled = AppPreferences.systemProxyEnabled
        if coreState.isRunning, !usingHelper, AppPreferences.proxyGuardEnabled, AppPreferences.systemProxyEnabled {
            proxyGuardEnabled = proxyGuard.isRunning
        } else {
            proxyGuardEnabled = AppPreferences.proxyGuardEnabled && coreState.isRunning && !usingHelper
        }
    }

    private func restoreNetworkPreferencesFromStorage() {
        systemProxyEnabled = AppPreferences.systemProxyEnabled
        proxyGuardEnabled = AppPreferences.proxyGuardEnabled
        tunEnabled = AppPreferences.tunEnabled
    }

    private func refreshSystemProxyActiveInBackground() {
        let port = runtime.mixedPort
        Task { [weak self] in
            let active = await Task.detached(priority: .utility) {
                SystemProxyController.isProxyActive(host: "127.0.0.1", port: port)
            }.value
            guard let self else { return }
            guard self.isSystemProxyActive != active else { return }
            self.isSystemProxyActive = active
            self.applyProxyStateToSettings()
            MenuBarManager.shared.refreshIconAndTooltip()
        }
    }

    func applyRuntimeSettings() async {
        AppPreferences.persist(from: self)
        runtime = AppPreferences.makeRuntimeConfig(mode: mode)
        registerHotkeys()
        if coreState.isRunning {
            await stop()
            await start()
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginService.setEnabled(enabled)
            launchAtLogin = LaunchAtLoginService.isEnabled
        } catch {
            coreState = .error(error.localizedDescription)
        }
    }

    func persistPreferences() {
        AppPreferences.persist(from: self)
    }

    func setHotkeysEnabled(_ enabled: Bool) {
        hotkeysEnabled = enabled
        AppPreferences.hotkeysEnabled = enabled
        registerHotkeys()
        syncSettingsWithRuntime()
    }

    func setGlobalHotkey(_ enabled: Bool) {
        AppPreferences.globalHotkey = enabled
        registerHotkeys()
        syncSettingsWithRuntime()
    }

    func importCustomMenuBarIcon(from url: URL) {
        do {
            let saved = try MenuBarIconStore.importIcon(from: url)
            customMenuBarIconPath = saved.path
            AppPreferences.customMenuBarIconPath = saved.path
            bumpMenuBarIconRevision()
        } catch {
            coreState = .error("托盘图标导入失败：\(error.localizedDescription)")
        }
    }

    func clearCustomMenuBarIcon() {
        customMenuBarIconPath = nil
        AppPreferences.customMenuBarIconPath = nil
        MenuBarIconStore.removeSavedIcon()
        bumpMenuBarIconRevision()
    }

    func pickCustomMenuBarIcon() {
        let panel = NSOpenPanel()
        panel.title = "选择托盘图标"
        panel.prompt = "选择"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = MenuBarIconStore.openPanelAllowedTypes
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importCustomMenuBarIcon(from: url)
    }

    private func bumpMenuBarIconRevision() {
        menuBarIconRevision &+= 1
        MenuBarManager.shared.refresh()
    }

    func removeUnlockTarget(_ target: UnlockTarget) {
        let builtIn = Set(UnlockService.defaultTargets.map(\.id))
        guard !builtIn.contains(target.id) else { return }
        unlockTargets.removeAll { $0.id == target.id }
        try? UnlockTargetStore.save(unlockTargets)
    }

    func isCustomUnlockTarget(_ target: UnlockTarget) -> Bool {
        !UnlockService.defaultTargets.contains { $0.id == target.id }
    }

    func saveDNSConfig(_ config: DNSConfig) {
        dnsConfig = config
        try? DNSConfigStore.save(config)
        runtime = AppPreferences.makeRuntimeConfig(mode: mode)
        if coreState.isRunning {
            Task { await applyRuntimeSettings() }
        }
    }

    func setDNSOverwriteEnabled(_ enabled: Bool) {
        dnsOverwriteEnabled = enabled
        AppPreferences.dnsOverwriteEnabled = enabled
        runtime = AppPreferences.makeRuntimeConfig(mode: mode)
        if coreState.isRunning {
            Task { await applyRuntimeSettings() }
        }
    }

    func saveTUNConfig(_ config: TUNConfig) {
        tunConfig = config
        try? TUNConfigStore.save(config)
        runtime = AppPreferences.makeRuntimeConfig(mode: mode)
        if coreState.isRunning {
            Task { await applyRuntimeSettings() }
        }
    }

    func exportDiagnostic() -> URL {
        DiagnosticExporter.export(store: self)
    }

    // MARK: - Profiles

    func bootstrapProfiles() async {
        profiles = (try? ProfileStore.loadProfiles()) ?? []
        activeProfile = ProfileStore.activeProfile(from: profiles)
        if AppPreferences.tunEnabled, HelperInstaller.isInstalled() {
            try? HelperTrustStore.recordCurrentUser()
        }
        if let coreURL = CoreLocator.discoverCoreURL() {
            corePath = coreURL.path
            if let localVersion = CoreLocator.coreVersion(at: coreURL) {
                version = localVersion
            }
        }
        await runStartupChecks()
        await autoStartIfNeeded()
    }

    /// 启动时按上次状态自动拉起代理：开启「恢复上次状态」且上次会话处于运行态、且已具备内核时执行。
    private func autoStartIfNeeded() async {
        guard resumeLastProxyState,
              AppPreferences.coreWasRunning,
              case .stopped = coreState,
              CoreLocator.discoverCoreURL() != nil else { return }
        appendAppLog(level: .info, message: "启动时自动恢复上次代理状态…")
        await start()
    }

    func runStartupChecks() async {
        if let coreURL = CoreLocator.discoverCoreURL() {
            corePath = coreURL.path
            if let localVersion = CoreLocator.coreVersion(at: coreURL) {
                version = localVersion
            }
        }
        geoMissingFiles = GeoDataUpdateService.fileStatus().filter { !$0.exists }.map(\.name)

        var banners: [StartupBanner] = []
        if CoreLocator.discoverCoreURL() == nil {
            banners.append(StartupBanner(
                kind: .coreMissing,
                title: "未安装 Mihomo 内核",
                message: "请下载内核后才能启动代理"
            ))
        } else {
            await checkCoreUpdate()
            if coreUpdateAvailable, let latest = latestCoreVersion {
                banners.append(StartupBanner(
                    kind: .coreUpdate,
                    title: "内核可更新",
                    message: "最新版本 v\(latest)（当前 \(coreVersionLabel)）"
                ))
            }
        }
        if !geoMissingFiles.isEmpty {
            banners.append(StartupBanner(
                kind: .geoData,
                title: "缺少 GeoData",
                message: "缺失文件：\(geoMissingFiles.joined(separator: "、"))"
            ))
        }
        if AppPreferences.tunEnabled, HelperInstaller.isBundled(),
           HelperInstaller.serviceStatus() == .requiresApproval {
            banners.append(StartupBanner(
                kind: .helperApproval,
                title: "Helper 待批准",
                message: "TUN 模式需要在系统设置 → 通用 → 登录项 中批准 ClashMac Helper"
            ))
        }
        startupBanners = banners.filter { !dismissedBannerKinds.contains($0.kind) }
    }

    func dismissStartupBanner(_ kind: StartupBanner.Kind) {
        dismissedBannerKinds.insert(kind)
        startupBanners.removeAll { $0.kind == kind }
    }

    func actOnStartupBanner(_ banner: StartupBanner) async {
        switch banner.kind {
        case .geoData:
            await updateGeoData()
            await runStartupChecks()
        case .coreUpdate, .coreMissing:
            await updateCore()
            await runStartupChecks()
        case .helperApproval:
            if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func refreshDashboardData() async {
        syncSettingsWithRuntime()
        guard coreState.isRunning else { return }
        await refreshAll()
    }

    func renameProfile(_ profile: Profile, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = profiles
        guard let index = list.firstIndex(where: { $0.id == profile.id }) else { return }
        list[index].name = trimmed
        profiles = list
        if activeProfile?.id == profile.id {
            activeProfile = list[index]
        }
        try? ProfileStore.saveProfiles(list)
    }

    func moveProfile(from source: IndexSet, to destination: Int) {
        var list = profiles
        list.move(fromOffsets: source, toOffset: destination)
        profiles = list
        try? ProfileStore.reorderProfiles(list)
    }

    func copyProxyEnvironment() {
        guard coreState.isRunning else { return }
        ProxyEnvironmentClipboard.copyMixedPort(mixedPort)
    }

    func activateProfile(_ profile: Profile) async {
        var list = profiles
        ProfileStore.activateProfile(id: profile.id, in: &list)
        try? ProfileStore.saveProfiles(list)
        profiles = list
        activeProfile = profile
        if coreState.isRunning {
            await stop()
            await start()
        }
    }

    func importSubscription() async {
        guard !subscriptionURLInput.isEmpty else { return }
        do {
            let yaml = try await SubscriptionFetcher.download(from: subscriptionURLInput)
            let name = subscriptionNameInput.isEmpty ? "订阅 \(profiles.count + 1)" : subscriptionNameInput
            let profile = try ProfileStore.addSubscriptionProfile(
                name: name, url: subscriptionURLInput, yamlContent: yaml
            )
            subscriptionURLInput = ""
            await bootstrapProfiles()
            activeProfile = profile
        } catch {
            coreState = .error(error.localizedDescription)
        }
    }

    func refreshActiveSubscription() async {
        guard let profile = activeProfile, profile.subscriptionURL != nil else { return }
        await refreshSubscription(profile)
    }

    func refreshAllSubscriptions() async {
        guard !isRefreshingSubscriptions else { return }
        isRefreshingSubscriptions = true
        defer { isRefreshingSubscriptions = false }
        for profile in profiles where profile.subscriptionURL != nil {
            await refreshSubscription(profile)
        }
        await bootstrapProfiles()
    }

    func refreshSubscription(_ profile: Profile, viaProxy: Bool = false) async {
        guard let url = profile.subscriptionURL else { return }
        do {
            let proxyPort = viaProxy && coreState.isRunning ? mixedPort : nil
            let yaml = try await SubscriptionFetcher.download(from: url, viaProxyPort: proxyPort)
            try ProfileStore.updateProfileFile(profile, content: yaml)
            var list = profiles
            if let idx = list.firstIndex(where: { $0.id == profile.id }) {
                list[idx].updatedAt = .now
                try ProfileStore.saveProfiles(list)
                profiles = list
            }
            if coreState.isRunning, profile.id == activeProfile?.id {
                let profileYAML = try ProfileStore.readProfileYAML(profile)
                _ = try RuntimeConfigBuilder.writeRuntimeConfig(profileYAML: profileYAML, runtime: runtime)
                try await api.reloadConfig()
                await refreshRuntimeDataWithRetry()
            }
        } catch {
            coreState = .error(error.localizedDescription)
        }
    }

    func refreshSubscriptionViaProxy(_ profile: Profile) async {
        await refreshSubscription(profile, viaProxy: true)
    }

    func openProfileEditor(_ profile: Profile, section: ProfileYAMLSection) {
        profileEditorTarget = profile
        profileEditorSection = section
        profileEditorTitle = section.editorTitle
        profileEditorYAML = (try? ProfileYAMLSectionEditor.load(section: section, from: profile)) ?? ""
        isProfileEditorPresented = true
    }

    func saveProfileEditor() async {
        guard let profile = profileEditorTarget else { return }
        do {
            try ProfileYAMLSectionEditor.save(
                section: profileEditorSection,
                yaml: profileEditorYAML,
                to: profile
            )
            isProfileEditorPresented = false
            if coreState.isRunning, profile.id == activeProfile?.id {
                let profileYAML = try ProfileStore.readProfileYAML(profile)
                _ = try RuntimeConfigBuilder.writeRuntimeConfig(profileYAML: profileYAML, runtime: runtime)
                try await api.reloadConfig()
                await refreshRuntimeDataWithRetry()
            }
        } catch {
            coreState = .error(error.localizedDescription)
        }
    }

    func openProfileInFinder(_ profile: Profile) {
        NSWorkspace.shared.activateFileViewerSelecting([profile.fileURL])
    }

    func importLocalProfile(name: String, from url: URL) async {
        do {
            let yaml = try String(contentsOf: url, encoding: .utf8)
            let profileName = name.isEmpty ? url.deletingPathExtension().lastPathComponent : name
            _ = try ProfileStore.addLocalProfile(name: profileName, yamlContent: yaml)
            await bootstrapProfiles()
            if let latest = profiles.last { activeProfile = latest }
        } catch {
            coreState = .error(error.localizedDescription)
        }
    }

    func deleteProfile(_ profile: Profile) async {
        do {
            let wasActive = profile.id == activeProfile?.id
            try ProfileStore.deleteProfile(id: profile.id)
            await bootstrapProfiles()
            activeProfile = ProfileStore.activeProfile(from: profiles)
            if wasActive, coreState.isRunning {
                await stop()
                if profiles.isEmpty == false { await start() }
            }
        } catch {
            coreState = .error(error.localizedDescription)
        }
    }

    func installCLI() {
        do {
            try CLIInstallService.writeEnvironment(runtime: runtime)
            let path = try CLIInstallService.install()
            updateStatusMessage = "CLI 已安装：\(path.path)"
        } catch {
            coreState = .error(error.localizedDescription)
        }
    }

    func uninstallHelper() {
        do {
            try HelperInstaller.uninstall()
            helperStatus = HelperInstaller.installStatusText()
            updateStatusMessage = "Helper 已卸载 · \(helperStatus)"
            appendAppLog(level: .info, message: updateStatusMessage ?? "Helper 已卸载")
        } catch {
            helperStatus = HelperInstaller.installStatusText()
            let message = "Helper 卸载失败：\(error.localizedDescription)"
            updateStatusMessage = message
            appendAppLog(level: .error, message: message)
        }
    }

    func installHelper() {
        do {
            // 始终走强制重注册，确保替换 app/内核后 launchd 刷新代码要求（LWCR）。
            try HelperInstaller.forceReinstall()
            helperStatus = HelperInstaller.installStatusText()
            updateStatusMessage = "Helper 安装请求已提交 · \(helperStatus)"
            appendAppLog(level: .info, message: updateStatusMessage ?? "Helper 安装请求已提交")
        } catch {
            helperStatus = HelperInstaller.installStatusText()
            let message = HelperInstaller.installFailureMessage(for: error)
            updateStatusMessage = message
            appendAppLog(level: .error, message: message)
        }
    }

    // MARK: - Lifecycle

    func togglePower() async {
        if case .starting = coreState {
            await cancelStart()
            return
        }
        guard !isPowerTransitioning else { return }
        coreState.isRunning ? await stop() : await start()
    }

    func cancelStart() async {
        startTask?.cancel()
        startupCompletionTask?.cancel()
        startupCompletionTask = nil
        await cleanupFailedLaunch()
        coreState = .stopped
        appendAppLog(level: .info, message: "已取消启动")
    }

    func start() async {
        switch coreState {
        case .stopped, .error:
            break
        default:
            return
        }

        startTask?.cancel()
        startTask = Task { @MainActor [weak self] in
            await self?.performStart()
        }
    }

    private func performStart() async {
        coreState = .starting
        startupCompletionTask?.cancel()
        startupCompletionTask = nil
        helperStatus = HelperInstaller.installStatusText()
        appendAppLog(level: .info, message: "开始启动代理 · TUN=\(tunEnabled) · 端口=\(mixedPortInput)")

        do {
            try Task.checkCancellation()
            MihomoProcessRegistry.clearManagedPID()
            appendAppLog(level: .debug, message: "启动阶段：清理遗留 Mihomo")
            await MihomoProcessRegistry.terminateManagedInstances()
            appendAppLog(level: .debug, message: "启动阶段：遗留进程清理完成")

            let profileYAML: String
            if let profile = activeProfile ?? profiles.first {
                profileYAML = try ProfileStore.readProfileYAML(profile)
            } else {
                profileYAML = try loadOrCreateDefaultProfile()
            }
            appendAppLog(level: .debug, message: "启动阶段：配置读取完成")

            AppPreferences.persist(from: self)
            restoreNetworkPreferencesFromStorage()
            runtime = AppPreferences.makeRuntimeConfig(mode: mode, logLevel: logLevel.rawValue)
            appendAppLog(level: .debug, message: "启动阶段：运行时配置已生成 · mixed=\(runtime.mixedPort) controller=\(runtime.controllerPort)")

            let mixedPort = runtime.mixedPort
            let mixedConflict = await Task.detached(priority: .utility) {
                PortAvailabilityChecker.conflictMessage(for: mixedPort)
            }.value
            if let conflict = mixedConflict {
                throw CoreProcessError.launchFailed(conflict)
            }
            if runtime.enableExternalController {
                let controllerPort = runtime.controllerPort
                let controllerConflict = await Task.detached(priority: .utility) {
                    PortAvailabilityChecker.conflictMessage(for: controllerPort)
                }.value
                if let conflict = controllerConflict {
                    throw CoreProcessError.launchFailed(conflict)
                }
            }
            appendAppLog(level: .debug, message: "启动阶段：端口检查通过")

            let wantsTun = tunEnabled
            var tunFallbackMessage: String?
            do {
                appendAppLog(level: .debug, message: "启动阶段：准备启动内核 · TUN=\(wantsTun)")
                try await launchCore(profileYAML: profileYAML, useTun: wantsTun)
            } catch {
                guard wantsTun, shouldFallbackFromTun(error) else { throw error }
                appendAppLog(level: .warning, message: "TUN 启动失败，降级系统代理：\(error.localizedDescription)")
                await cleanupFailedLaunch(disableSystemProxy: false)
                if !systemProxyEnabled {
                    // 兼容旧版本曾在选择 TUN 时关闭系统代理偏好的情况；TUN 不可用时应仍可启动普通系统代理。
                    AppPreferences.systemProxyEnabled = true
                    systemProxyEnabled = true
                    appendAppLog(level: .info, message: "已启用系统代理作为 TUN 降级方案")
                }
                runtime = AppPreferences.makeRuntimeConfig(mode: mode, tunEnabled: false, logLevel: logLevel.rawValue)
                tunFallbackMessage = tunFallbackNotice(for: error)
                try Task.checkCancellation()
                appendAppLog(level: .debug, message: "启动阶段：准备启动内核 · TUN=false")
                try await launchCore(profileYAML: profileYAML, useTun: false)
            }

            try Task.checkCancellation()
            appendAppLog(level: .debug, message: "启动阶段：等待控制接口")
            try await waitForCore(timeout: 12)

            coreState = .running
            coreStartedAt = .now
            AppPreferences.coreWasRunning = true
            syncSettingsWithRuntime()
            bumpMenuBarIconRevision()
            if let tunFallbackMessage {
                updateStatusMessage = tunFallbackMessage
            }
            resumeLiveUpdates()
            appendAppLog(level: .info, message: "代理已运行 · \(usingHelper ? "TUN/Helper" : "系统代理")")

            let runtimeSnapshot = runtime
            let wantsSystemProxy = systemProxyEnabled && !usingHelper
            let wantsProxyGuard = proxyGuardEnabled && systemProxyEnabled && !usingHelper
            let corePathSnapshot = corePath
            startupCompletionTask = Task { @MainActor [weak self] in
                guard let self, !Task.isCancelled, self.coreState.isRunning else { return }
                let coreURL = URL(fileURLWithPath: corePathSnapshot)
                if let localVersion = CoreLocator.coreVersion(at: coreURL) {
                    self.version = localVersion
                } else {
                    self.version = (try? await self.api.version()) ?? "—"
                }
                guard !Task.isCancelled, self.coreState.isRunning else { return }

                if wantsSystemProxy {
                    let mixedPort = runtimeSnapshot.mixedPort
                    let proxyResult = await Task.detached(priority: .userInitiated) {
                        Result {
                            try SystemProxyController.setSystemProxy(host: "127.0.0.1", port: mixedPort, enabled: true)
                            return SystemProxyController.isProxyActive(host: "127.0.0.1", port: mixedPort)
                        }
                    }.value
                    guard !Task.isCancelled, self.coreState.isRunning else { return }
                    switch proxyResult {
                    case .success(let active):
                        self.isSystemProxyActive = active
                        if !active {
                            self.appendAppLog(level: .warning, message: "系统代理写入后未检测到生效，请打开「系统设置 → 网络 → 详情 → 代理」确认")
                        } else {
                            self.appendAppLog(level: .info, message: "系统代理已生效 · 127.0.0.1:\(mixedPort)")
                        }
                    case .failure(let error):
                        self.isSystemProxyActive = false
                        self.appendAppLog(level: .warning, message: "系统代理设置失败：\(error.localizedDescription)")
                    }
                }
                if wantsProxyGuard, !Task.isCancelled, self.coreState.isRunning {
                    self.proxyGuard.start(host: "127.0.0.1", port: runtimeSnapshot.mixedPort)
                }

                guard !Task.isCancelled, self.coreState.isRunning else { return }
                try? CLIInstallService.writeEnvironment(runtime: runtimeSnapshot)
                await self.refreshRuntimeDataWithRetry()
                guard !Task.isCancelled, self.coreState.isRunning else { return }
                await self.applyStoredSelections()
                guard !Task.isCancelled, self.coreState.isRunning else { return }
                self.appendAppLog(level: .info, message: "启动完成 · \(self.version)")
            }
        } catch is CancellationError {
            startupCompletionTask?.cancel()
            startupCompletionTask = nil
            await cleanupFailedLaunch()
            coreState = .stopped
            appendAppLog(level: .info, message: "启动已取消")
        } catch {
            startupCompletionTask?.cancel()
            startupCompletionTask = nil
            usingHelper = false
            let stillRunning = CoreProcessController.shared.isRunning
            await cleanupFailedLaunch()
            syncSettingsWithRuntime()
            let message = StartupErrorFormatter.message(
                for: error,
                mixedPort: mixedPortInput,
                coreStillRunning: stillRunning
            )
            appendAppLog(level: .error, message: "启动失败：\(message)")
            coreState = .error(message)
        }
        startTask = nil
    }

    private func launchCore(profileYAML: String, useTun: Bool) async throws {
        let coreURL: URL
        if useTun {
            guard let privileged = CoreLocator.discoverPrivilegedCoreURL() else {
                throw CoreProcessError.coreNotFound
            }
            coreURL = privileged
        } else {
            guard let discovered = CoreLocator.discoverCoreURL() else {
                throw CoreProcessError.coreNotFound
            }
            coreURL = discovered
        }
        corePath = coreURL.path

        runtime = AppPreferences.makeRuntimeConfig(mode: mode, tunEnabled: useTun, logLevel: logLevel.rawValue)
        MihomoIPCPath.removeStaleSocketIfNeeded()
        if useTun {
            WorkDirectorySanitizer.prepareForPrivilegedCore(in: RuntimeConfigBuilder.workDirectory())
        } else {
            WorkDirectorySanitizer.prepareForUserCore(in: RuntimeConfigBuilder.workDirectory())
        }
        let configURL = try RuntimeConfigBuilder.writeRuntimeConfig(profileYAML: profileYAML, runtime: runtime)
        let validateCoreURL = coreURL
        let validateWorkDir = RuntimeConfigBuilder.workDirectory()
        do {
            try await Task.detached(priority: .userInitiated) {
                try CoreConfigValidator.validateIfNeeded(
                    configURL: configURL,
                    coreURL: validateCoreURL,
                    workDirectory: validateWorkDir
                )
            }.value
        } catch CoreConfigValidator.ValidationError.timedOut {
            // 校验超时（多为远程 provider 联网拉取）不阻断启动，交由内核实际启动时的健康检查兜底。
            appendAppLog(level: .warning, message: "配置校验超时，跳过预校验直接启动内核")
        }

        if useTun {
            appendAppLog(level: .debug, message: "TUN 阶段[1/6]：检查 Helper 是否打包 · bundled=\(HelperInstaller.isBundled())")
            if !HelperInstaller.isBundled() {
                throw TunnelHelperError.helperUnavailable
            }
            appendAppLog(level: .debug, message: "TUN 阶段[2/6]：Helper 注册状态 · \(HelperInstaller.statusDescription())")
            if HelperInstaller.serviceStatus() == .notRegistered {
                helperStatus = HelperInstaller.installStatusText()
                throw TunnelHelperError.startFailed("Helper 未安装，请先在设置中点击「安装 Helper」并批准系统提示")
            }
            guard HelperInstaller.isReadyForTun() else {
                throw TunnelHelperError.startFailed("Helper 尚未获得系统批准（请在系统设置 → 通用 → 登录项中允许）")
            }

            appendAppLog(level: .debug, message: "TUN 阶段[3/6]：探测 Helper XPC 可达性…")
            var reachable = await helper.isReachable()
            appendAppLog(level: .debug, message: "TUN 阶段[3/6]：XPC 可达性 = \(reachable)")
            if !reachable {
                // launchd 可能缓存了旧签名的 LWCR（替换 app 后常见），强制注销+重注册刷新代码要求。
                appendAppLog(level: .warning, message: "TUN 阶段[4/6]：XPC 不可达，强制重注册 Helper 以刷新代码要求…")
                do {
                    try HelperInstaller.forceReinstall()
                    helperStatus = HelperInstaller.installStatusText()
                    appendAppLog(level: .debug, message: "TUN 阶段[4/6]：重注册完成 · 状态=\(HelperInstaller.statusDescription())")
                } catch {
                    appendAppLog(level: .warning, message: "TUN 阶段[4/6]：重注册失败 · \(error.localizedDescription)")
                }
                try await Task.sleep(for: .milliseconds(1200))
                reachable = await helper.isReachable()
                appendAppLog(level: .debug, message: "TUN 阶段[5/6]：重注册后 XPC 可达性 = \(reachable)")
            }
            guard reachable else {
                throw TunnelHelperError.startFailed("Helper 已安装但 XPC 不可达（launchd spawn 失败）。请在系统设置 → 通用 → 登录项中关闭再开启 ClashMac Helper，或在设置中点击「重装 Helper」")
            }

            appendAppLog(level: .debug, message: "TUN 阶段[6/6]：通过 Helper 启动内核…")
            do {
                try await helper.startTunnel(
                    corePath: coreURL.path,
                    configPath: configURL.path,
                    workDirectory: RuntimeConfigBuilder.workDirectory().path,
                    secret: runtime.secret
                )
            } catch let error as TunnelHelperError where Self.isStaleHelperRejection(error) {
                // 已注册的 Helper 可能是旧二进制（SMAppService 不随 app 重建自动刷新代码），
                // 旧校验逻辑会拒绝当前合法路径。识别为路径校验类拒绝时强制重装 Helper 再重试一次。
                appendAppLog(level: .warning, message: "TUN：Helper 路径校验拒绝（疑似旧版本），强制重装后重试 · \(error.localizedDescription)")
                try HelperInstaller.forceReinstall()
                helperStatus = HelperInstaller.installStatusText()
                try await Task.sleep(for: .milliseconds(1200))
                try await helper.startTunnel(
                    corePath: coreURL.path,
                    configPath: configURL.path,
                    workDirectory: RuntimeConfigBuilder.workDirectory().path,
                    secret: runtime.secret
                )
            }
            usingHelper = true
            appendAppLog(level: .info, message: "Helper 已启动 Mihomo · PID 待同步")
            let status = await helper.tunnelStatus()
            appendAppLog(level: .debug, message: "Helper 内核状态 · running=\(status.running) pid=\(status.pid)")
            MihomoProcessRegistry.registerManagedPID(status.running ? status.pid : nil)
        } else {
            try CoreProcessController.shared.start(
                coreURL: coreURL,
                configURL: configURL,
                workDirectory: RuntimeConfigBuilder.workDirectory(),
                runtime: runtime
            )
            usingHelper = false
            MihomoProcessRegistry.registerManagedPID(CoreProcessController.shared.pid)
            appendAppLog(level: .info, message: "用户态 Mihomo 已启动 · \(coreURL.lastPathComponent)")
        }
    }

    /// 判断 Helper 启动失败是否源于「路径白名单校验」——这类拒绝通常意味着注册的是旧版 Helper 二进制，
    /// 重装即可修复（区别于配置/密钥等需用户处理的真实错误）。
    private nonisolated static func isStaleHelperRejection(_ error: TunnelHelperError) -> Bool {
        guard case let .startFailed(message) = error else { return false }
        let markers = ["不在允许范围内", "路径解析失败"]
        return markers.contains { message.contains($0) }
    }

    private func cleanupFailedLaunch(disableSystemProxy: Bool = true) async {
        let wasUsingHelper = usingHelper
        usingHelper = false
        CoreProcessController.shared.stop()
        MihomoProcessRegistry.clearManagedPID()
        await MihomoProcessRegistry.terminateManagedInstances()
        if wasUsingHelper {
            try? await helper.stopTunnel()
        }
        if disableSystemProxy {
            let port = runtime.mixedPort
            try? await Task.detached(priority: .utility) {
                try? SystemProxyController.setSystemProxy(host: "127.0.0.1", port: port, enabled: false)
            }.value
            isSystemProxyActive = false
        }
        proxyGuard.stop()
    }

    private func shouldFallbackFromTun(_ error: Error) -> Bool {
        if case TunnelHelperError.helperUnavailable = error { return true }
        if case TunnelHelperError.startFailed(let msg) = error {
            if msg.localizedCaseInsensitiveContains("helper") { return true }
            if msg.contains("尚未获得系统批准") || msg.contains("GID") { return true }
            if msg.localizedCaseInsensitiveContains("operation not permitted") { return true }
            return true
        }
        if error is HelperInstallError { return true }
        let ns = error as NSError
        if ns.domain == NSPOSIXErrorDomain && ns.code == Int(POSIXError.Code.EPERM.rawValue) {
            return true
        }
        return error.localizedDescription.localizedCaseInsensitiveContains("operation not permitted")
    }

    private func tunFallbackNotice(for error: Error) -> String {
        if HelperInstaller.serviceStatus() == .requiresApproval {
            return "Helper 待批准，已改用系统代理模式。请在系统设置 → 登录项 中批准 ClashMac Helper 后重启 TUN。"
        }
        if error.localizedDescription.localizedCaseInsensitiveContains("operation not permitted") {
            return "TUN 权限不足，已改用系统代理模式。可将应用安装到「应用程序」或在设置中安装 Helper。"
        }
        return "TUN 模式不可用，已改用系统代理模式。"
    }

    func stop() async {
        guard coreState.isRunning else { return }
        // 用户主动停止 → 记录为「未运行」，下次启动不自动恢复。
        AppPreferences.coreWasRunning = false
        coreState = .stopping
        startupCompletionTask?.cancel()
        startupCompletionTask = nil
        appendAppLog(level: .info, message: "正在停止代理…")
        rulesPrefetchTask?.cancel()
        rulesFilterTask?.cancel()
        stopAllLiveUpdates()
        proxyGuard.stop()

        if usingHelper {
            try? await helper.stopTunnel()
        } else {
            CoreProcessController.shared.stop()
        }
        MihomoProcessRegistry.clearManagedPID()
        await MihomoProcessRegistry.terminateManagedInstances()
        usingHelper = false

        let stopPort = runtime.mixedPort
        try? await Task.detached(priority: .utility) {
            try? SystemProxyController.setSystemProxy(host: "127.0.0.1", port: stopPort, enabled: false)
        }.value
        isSystemProxyActive = false
        syncSettingsWithRuntime()
        connections = []
        closedConnections = []
        connectionByteSnapshot = [:]
        groups = []
        rules = []
        displayedRuleIndices = []
        rulesMatchCount = 0
        rulesDataRevision = 0
        proxyProviders = []
        traffic = .zero
        coreStartedAt = nil
        coreMemoryLabel = "—"
        coreState = .stopped
        bumpMenuBarIconRevision()
        appendAppLog(level: .info, message: "代理已停止")
    }

    func setMode(_ newMode: RunMode) async {
        mode = newMode
        guard coreState.isRunning else { return }
        do { try await api.setMode(newMode) } catch { coreState = .error(error.localizedDescription) }
    }

    func setTunEnabled(_ enabled: Bool) async {
        AppPreferences.tunEnabled = enabled
        tunEnabled = enabled
        if coreState.isRunning {
            await stop()
            await start()
        } else {
            syncSettingsWithRuntime()
        }
    }

    func setSystemProxyEnabled(_ enabled: Bool) async {
        // 与 TUN 互斥：TUN 运行中开启系统代理 → 关闭 TUN 并以系统代理方式重启。
        if enabled, isTunRuntimeActive {
            AppPreferences.tunEnabled = false
            tunEnabled = false
            AppPreferences.systemProxyEnabled = true
            systemProxyEnabled = true
            await stop()
            await start()
            return
        }
        AppPreferences.systemProxyEnabled = enabled
        systemProxyEnabled = enabled
        guard coreState.isRunning, !isTunRuntimeActive else {
            syncSettingsWithRuntime()
            return
        }
        do {
            let mixedPort = runtime.mixedPort
            let result = await Task.detached(priority: .userInitiated) {
                Result {
                    try SystemProxyController.setSystemProxy(host: "127.0.0.1", port: mixedPort, enabled: enabled)
                    return SystemProxyController.isProxyActive(host: "127.0.0.1", port: mixedPort)
                }
            }.value
            switch result {
            case .success(let active):
                isSystemProxyActive = active
            case .failure(let error):
                isSystemProxyActive = false
                updateStatusMessage = "系统代理切换失败：\(error.localizedDescription)"
                appendAppLog(level: .error, message: updateStatusMessage ?? "系统代理切换失败")
            }
        }
        if AppPreferences.proxyGuardEnabled && enabled && isSystemProxyActive {
            proxyGuard.start(host: "127.0.0.1", port: runtime.mixedPort)
        } else {
            proxyGuard.stop()
        }
        syncSettingsWithRuntime()
    }

    func setProxyGuardEnabled(_ enabled: Bool) {
        AppPreferences.proxyGuardEnabled = enabled
        guard coreState.isRunning, AppPreferences.systemProxyEnabled, !isTunRuntimeActive else {
            proxyGuardEnabled = enabled
            proxyGuard.stop()
            syncSettingsWithRuntime()
            return
        }
        enabled ? proxyGuard.start(host: "127.0.0.1", port: runtime.mixedPort) : proxyGuard.stop()
        syncSettingsWithRuntime()
    }

    func selectNode(group: ProxyGroup, node: ProxyNode) async {
        guard coreState.isRunning else { return }
        do {
            try await api.selectProxy(group: group.name, node: node.name)
            // 选择落盘到本地文件，作为持久来源；内核重启后回放，不依赖内核 cache.db。
            SelectionStore.set(group: group.name, node: node.name)
            await refreshGroups()
        } catch { coreState = .error(error.localizedDescription) }
    }

    func selectFastest(in group: ProxyGroup) async {
        guard coreState.isRunning else { return }
        let testURL = URL(string: "http://www.gstatic.com/generate_204")!
        var best: (name: String, delay: Int)?
        for node in group.nodes {
            if let delay = try? await api.measureDelay(proxy: node.name, testURL: testURL) {
                if best == nil || delay < best!.delay { best = (node.name, delay) }
            }
        }
        if let best {
            try? await api.selectProxy(group: group.name, node: best.name)
            SelectionStore.set(group: group.name, node: best.name)
            await refreshGroups()
        }
    }

    /// 内核启动后回放本地保存的节点选择：仅对 Selector 组、且目标节点存在、且当前选择不一致时下发，
    /// 保证「上次选择」始终生效，独立于内核二进制缓存。
    func applyStoredSelections() async {
        guard coreState.isRunning else { return }
        let stored = SelectionStore.all()
        guard !stored.isEmpty else { return }
        var didChange = false
        for group in groups where group.groupType == "Selector" {
            guard let want = stored[group.name],
                  group.selectedNode != want,
                  group.nodes.contains(where: { $0.name == want }) else { continue }
            do {
                try await api.selectProxy(group: group.name, node: want)
                didChange = true
            } catch {
                appendAppLog(level: .debug, message: "恢复节点选择失败 [\(group.name) → \(want)]：\(error.localizedDescription)")
            }
        }
        if didChange { await refreshGroups() }
    }

    func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await refreshRuntimeDataWithRetry(maxAttempts: 1, prefetchRules: false)
        await refreshProxyProviders()
        await refreshConnections()
        await refreshMeta()
    }

    // 默认不预拉规则：规则表可达数万条，仅在首次进入「规则」页时按需加载，避免用户从不查看规则时白白占用内存。
    func refreshRuntimeDataWithRetry(maxAttempts: Int = 5, prefetchRules: Bool = false) async {
        guard coreState.isRunning else { return }
        if prefetchRules { beginRulesPrefetch() }
        for attempt in 0..<maxAttempts {
            await refreshGroups()
            if !groups.isEmpty || attempt == maxAttempts - 1 {
                break
            }
            try? await Task.sleep(for: .milliseconds(800))
        }
    }

    /// 启动后后台预拉规则（对齐 Verge 全局 React Query 预取，不阻塞 UI）。
    func beginRulesPrefetch() {
        guard coreState.isRunning else { return }
        rulesPrefetchTask?.cancel()
        rulesPrefetchTask = Task {
            await refreshRules(silent: true)
        }
    }

    func refreshGroupsIfNeeded() async {
        guard coreState.isRunning, groups.isEmpty else { return }
        await refreshGroups()
    }

    /// 打开托盘菜单前同步代理状态，供菜单开关显示最新值。
    func prepareTrayMenuPresentation() {
        applyProxyStateToSettings()
        if coreState.isRunning, !isTunRuntimeActive {
            let port = runtime.mixedPort
            isSystemProxyActive = SystemProxyController.isProxyActive(host: "127.0.0.1", port: port)
        }
    }

    /// 打开托盘菜单前刷新连接数、策略组与系统代理状态，避免与主界面数据不一致。
    func refreshTrayMenuData() async {
        guard coreState.isRunning else { return }
        if !isTunRuntimeActive {
            let port = runtime.mixedPort
            isSystemProxyActive = await Task.detached(priority: .userInitiated) {
                SystemProxyController.isProxyActive(host: "127.0.0.1", port: port)
            }.value
        }
        await refreshConnections()
        await refreshGroups()
    }

    func refreshRulesIfNeeded() async {
        guard coreState.isRunning, rules.isEmpty else { return }
        await refreshRules(silent: rules.isEmpty)
    }

    func refreshRulesOnRulesPageAppear() async {
        guard coreState.isRunning else { return }
        // 规则列表极少变化（仅切换订阅/编辑后变）：已有数据且最近 30s 刷过则跳过全量拉取，
        // 避免每次切到规则页都重新 fetch+解析上万条造成的 CPU 峰值。
        if !rules.isEmpty, let last = lastRulesRefreshAt, Date().timeIntervalSince(last) < 30 {
            if displayedRuleIndices.isEmpty { scheduleRulesFilterRebuild() }
            return
        }
        await refreshRules(silent: true)
    }

    func scheduleRulesFilterRebuild() {
        rulesFilterTask?.cancel()
        guard !rules.isEmpty else {
            displayedRuleIndices = []
            rulesMatchCount = 0
            isRulesFilterPending = false
            return
        }
        isRulesFilterPending = true
        let snapshot = rules
        let query = rulesFilter
        let options = rulesFilterOptions
        rulesFilterTask = Task {
            // 防抖：合并快速连续输入，避免每次按键都发起一次全量过滤。
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            let indices: [Int]
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                indices = []
            } else {
                indices = await Task.detached(priority: .userInitiated) {
                    snapshot.enumerated().compactMap { idx, rule in
                        options.matches("\(rule.summary) \(rule.proxy)", query: query) ? idx : nil
                    }
                }.value
            }
            guard !Task.isCancelled else { return }
            displayedRuleIndices = indices
            rulesMatchCount = indices.isEmpty && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? snapshot.count
                : indices.count
            isRulesFilterPending = false
        }
    }

    func testAllGroups() async {
        guard coreState.isRunning, !isTestingAllGroups else { return }
        isTestingAllGroups = true
        defer { isTestingAllGroups = false }
        for group in groups {
            await testDelays(for: group)
        }
    }

    func testDelays(for group: ProxyGroup) async {
        guard coreState.isRunning else { return }
        let testURL = URL(string: "http://www.gstatic.com/generate_204")!
        guard let groupIndex = groups.firstIndex(where: { $0.name == group.name }) else { return }

        let nodeNames = groups[groupIndex].nodes.map(\.name)
        guard !nodeNames.isEmpty else { return }

        // 受控并发测速：同时最多 maxConcurrent 个连接，避免 fd 暴涨/压垮内核；
        // 结果收集完后一次性回写 groups，把 O(N) 次 @Observable 失效收敛为 1 次，消除重绘风暴。
        let results = await Self.measureDelaysConcurrently(
            nodeNames: nodeNames,
            testURL: testURL,
            api: api
        )

        guard let writeIndex = groups.firstIndex(where: { $0.name == group.name }) else { return }
        var updated = groups
        for (nodeIndex, delay) in results where nodeIndex < updated[writeIndex].nodes.count {
            updated[writeIndex].nodes[nodeIndex].delay = delay
            updated[writeIndex].nodes[nodeIndex].isAlive = delay != nil
        }
        groups = updated
    }

    /// 以受控并发对一组节点测速，返回 [(下标, 延迟ms?)]；延迟为 nil 表示不可用。
    private nonisolated static func measureDelaysConcurrently(
        nodeNames: [String],
        testURL: URL,
        api: MihomoAPIClient,
        maxConcurrent: Int = 16
    ) async -> [(Int, Int?)] {
        await withTaskGroup(of: (Int, Int?).self) { group in
            var nextIndex = 0
            var inFlight = 0
            while nextIndex < nodeNames.count && inFlight < maxConcurrent {
                let index = nextIndex
                let name = nodeNames[index]
                group.addTask { (index, try? await api.measureDelay(proxy: name, testURL: testURL)) }
                nextIndex += 1
                inFlight += 1
            }

            var collected: [(Int, Int?)] = []
            collected.reserveCapacity(nodeNames.count)
            for await result in group {
                collected.append(result)
                if nextIndex < nodeNames.count {
                    let index = nextIndex
                    let name = nodeNames[index]
                    group.addTask { (index, try? await api.measureDelay(proxy: name, testURL: testURL)) }
                    nextIndex += 1
                }
            }
            return collected
        }
    }

    func testNodeDelay(group: ProxyGroup, node: ProxyNode) async {
        guard coreState.isRunning,
              let groupIndex = groups.firstIndex(where: { $0.name == group.name }),
              let nodeIndex = groups[groupIndex].nodes.firstIndex(where: { $0.id == node.id }) else { return }
        testingNodeIDs.insert(node.id)
        defer { testingNodeIDs.remove(node.id) }
        let testURL = URL(string: "http://www.gstatic.com/generate_204")!
        await measureNode(at: groupIndex, nodeIndex: nodeIndex, testURL: testURL)
    }

    private func measureNode(at groupIndex: Int, nodeIndex: Int, testURL: URL) async {
        let node = groups[groupIndex].nodes[nodeIndex]
        if let delay = try? await api.measureDelay(proxy: node.name, testURL: testURL) {
            groups[groupIndex].nodes[nodeIndex].delay = delay
            groups[groupIndex].nodes[nodeIndex].isAlive = true
        } else {
            groups[groupIndex].nodes[nodeIndex].delay = nil
            groups[groupIndex].nodes[nodeIndex].isAlive = false
        }
    }

    // MARK: - Connections

    func refreshConnections() async {
        guard coreState.isRunning else { return }
        let fetched: [ConnectionItem]
        do {
            fetched = try await api.fetchConnections()
        } catch {
            appendAppLog(level: .debug, message: "连接列表刷新失败：\(error.localizedDescription)")
            return
        }
        let newIDs = Set(fetched.map(\.id))
        let previousIDs = Set(connections.map(\.id))

        for old in connections where !newIDs.contains(old.id) {
            var closed = old
            closed.closedAt = .now
            closedConnections.insert(closed, at: 0)
        }
        if closedConnections.count > 200 {
            closedConnections = Array(closedConnections.prefix(200))
        }

        connections = fetched.map { item in
            var enriched = item
            if let prev = connectionByteSnapshot[item.id] {
                enriched.uploadSpeed = max(0, item.upload - prev.upload) / 2
                enriched.downloadSpeed = max(0, item.download - prev.download) / 2
            }
            connectionByteSnapshot[item.id] = (item.upload, item.download)
            return enriched
        }

        for id in previousIDs.subtracting(newIDs) {
            connectionByteSnapshot.removeValue(forKey: id)
        }
    }

    func closeConnection(_ item: ConnectionItem) async {
        try? await api.closeConnection(id: item.id)
        await refreshConnections()
    }

    func closeAllConnections() async {
        try? await api.closeAllConnections()
        await refreshConnections()
    }

    // MARK: - Rules

    func refreshRules(silent: Bool = false) async {
        guard coreState.isRunning else { return }
        let showLoading = !silent && rules.isEmpty
        if showLoading { isLoadingRules = true }
        defer { if showLoading { isLoadingRules = false } }
        do {
            let runtimeSnapshot = runtime
            let fetched = try await Task.detached(priority: .userInitiated) {
                let client = MihomoAPIClient(runtime: runtimeSnapshot)
                return try await client.fetchRules()
            }.value
            lastRulesRefreshAt = Date()
            if !fetched.isEmpty {
                let firstLoad = rules.isEmpty
                rules = fetched
                rulesMatchCount = fetched.count
                rulesDataRevision &+= 1
                runtimeDataError = nil
                if !silent || firstLoad {
                    appendAppLog(level: .debug, message: "已加载规则 \(fetched.count) 条")
                }
            }
            scheduleRulesFilterRebuild()
        } catch {
            if !silent || rules.isEmpty {
                runtimeDataError = "规则加载失败：\(error.localizedDescription)"
                updateStatusMessage = runtimeDataError
                appendAppLog(level: .error, message: runtimeDataError ?? "规则加载失败")
            }
        }
    }

    func toggleRule(_ rule: RuleItem) async {
        guard coreState.isRunning else { return }
        do {
            let enabled = !rule.isEnabled
            try await api.setRuleEnabled(index: rule.index, enabled: enabled)
            if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
                rules[idx].isEnabled = enabled
                rulesDataRevision &+= 1
            }
            Task { await refreshRules(silent: true) }
        } catch { coreState = .error(error.localizedDescription) }
    }

    func loadRulesEditor() {
        if let profile = activeProfile {
            rulesYAML = (try? ProfileRulesEditor.loadRulesYAML(from: profile)) ?? "rules:\n  - MATCH,Proxy\n"
        } else {
            rulesYAML = "rules:\n  - MATCH,Proxy\n"
        }
        isRulesEditorPresented = true
    }

    func saveRulesAndReload() async {
        do {
            guard let profile = activeProfile else { return }
            try ProfileRulesEditor.saveRulesYAML(rulesYAML, to: profile)
            isRulesEditorPresented = false
            if coreState.isRunning {
                let profileYAML = try ProfileStore.readProfileYAML(profile)
                _ = try RuntimeConfigBuilder.writeRuntimeConfig(profileYAML: profileYAML, runtime: runtime)
                try await api.reloadConfig()
                await refreshRules()
            }
        } catch { coreState = .error(error.localizedDescription) }
    }

    func addVisualRule() async {
        guard let profile = activeProfile else { return }
        do {
            try ProfileRulesEditor.appendRule(
                to: profile,
                type: newRuleType,
                payload: newRulePayload.trimmingCharacters(in: .whitespaces),
                proxy: newRuleProxy
            )
            isAddRulePresented = false
            newRulePayload = ""
            if coreState.isRunning {
                let yaml = try ProfileStore.readProfileYAML(profile)
                _ = try RuntimeConfigBuilder.writeRuntimeConfig(profileYAML: yaml, runtime: runtime)
                try await api.reloadConfig()
            }
            await refreshRules()
        } catch {
            coreState = .error(error.localizedDescription)
        }
    }

    // MARK: - Logs

    func setLogLevel(_ level: LogLevel) {
        logLevel = level
        guard coreState.isRunning else {
            syncLogStreamForVisibleSection()
            return
        }
        Task {
            try? await api.setLogLevel(level)
            syncLogStreamForVisibleSection()
        }
    }

    func clearLogs() {
        pendingLogEntries.removeAll()
        logEntries.removeAll()
    }

    func syncLiveDataForSection(_ section: DashboardSection) {
        switch section {
        case .connections:
            Task { await refreshConnections() }
        case .logs:
            syncLogStreamForVisibleSection()
        default:
            break
        }
    }

    func syncLogStreamForVisibleSection() {
        guard coreState.isRunning, isDashboardVisible, selectedSection == .logs, logsSource == .core else {
            logStreamer.stop()
            return
        }
        startLogStreamIfNeeded()
    }

    private func startLogStreamIfNeeded() {
        logStreamer.stop()
        logStreamer.start(runtime: runtime, level: logLevel) { [weak self] entry in
            Task { @MainActor in self?.enqueueLog(entry) }
        } onFailure: { [weak self] message in
            Task { @MainActor in self?.appendAppLog(level: .warning, message: message) }
        }
    }

    private func enqueueLog(_ entry: LogEntry) {
        guard !logsPaused else { return }
        pendingLogEntries.append(entry)
        if pendingLogEntries.count > 200 {
            pendingLogEntries.removeFirst(pendingLogEntries.count - 200)
        }
        scheduleLogFlush()
    }

    private func scheduleLogFlush() {
        guard logFlushTask == nil else { return }
        logFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self else { return }
            self.flushPendingLogs()
            self.logFlushTask = nil
        }
    }

    private func flushPendingLogs() {
        guard !pendingLogEntries.isEmpty else { return }
        logEntries.append(contentsOf: pendingLogEntries)
        pendingLogEntries.removeAll(keepingCapacity: true)
        if logEntries.count > 300 {
            logEntries.removeFirst(logEntries.count - 300)
        }
    }

    private func startTrafficStreamIfNeeded() {
        trafficStreamer.stop()
        trafficStreamer.start(runtime: runtime) { [weak self] up, down in
            Task { @MainActor in self?.applyTrafficSample(upload: up, download: down) }
        }
    }

    private func startMemoryStreamIfNeeded() {
        memoryStreamer.stop()
        memoryStreamer.start(runtime: runtime) { [weak self] inuse in
            Task { @MainActor in self?.applyMemorySample(bytes: inuse) }
        }
    }

    private func applyMemorySample(bytes: Int) {
        let label = bytes > 0 ? Self.formatMemory(bytes: bytes) : "—"
        if coreMemoryLabel != label { coreMemoryLabel = label }
    }

    private static func formatMemory(bytes: Int) -> String {
        let mb = Double(bytes) / 1024 / 1024
        if mb >= 1024 { return String(format: "%.2f GB", mb / 1024) }
        return String(format: "%.1f MB", mb)
    }

    private func applyTrafficSample(upload: Int, download: Int) {
        traffic = TrafficSnapshot(uploadBytesPerSec: upload, downloadBytesPerSec: download)
        trafficHistory.append(TrafficSample(upload: upload, download: download))
        if trafficHistory.count > 60 {
            trafficHistory.removeFirst(trafficHistory.count - 60)
        }
        trafficTotals.uploadBytes += Int64(upload)
        trafficTotals.downloadBytes += Int64(download)
    }

    // MARK: - Live updates gating

    /// 窗口可见性变化时调用。窗口关闭后托盘/菜单已不再展示连接数或流量，
    /// 因此后台任何实时刷新都无意义 → 一律停掉全部实时流，仅保留内核，最大限度降低 CPU/内存。
    func setDashboardVisible(_ visible: Bool) {
        guard isDashboardVisible != visible else { return }
        isDashboardVisible = visible
        guard coreState.isRunning else { return }
        if visible {
            resumeLiveUpdates()
        } else {
            stopAllLiveUpdates()
        }
    }

    /// 立即进入轻量模式：开启偏好、关闭主窗口（释放界面），停掉全部实时刷新。
    func enterLightweightMode() {
        lightweightModeEnabled = true
        AppPreferences.lightweightModeEnabled = true
        MainWindowController.closeDashboard()
        if coreState.isRunning {
            stopAllLiveUpdates()
        }
    }

    func setLightweightModeEnabled(_ enabled: Bool) {
        // 现在窗口关闭即停掉全部实时刷新，轻量模式与默认后台行为一致；此开关仅保留用于「进入轻量模式」快捷入口的语义。
        lightweightModeEnabled = enabled
        AppPreferences.lightweightModeEnabled = enabled
    }

    private func resumeLiveUpdates() {
        guard coreState.isRunning else { return }
        beginBackgroundLiveUpdates()
        guard isDashboardVisible else { return }
        beginPeriodicRefresh()
        startMemoryStreamIfNeeded()
        syncLogStreamForVisibleSection()
    }

    private func beginBackgroundLiveUpdates() {
        beginConnectionsPolling()
        startTrafficStreamIfNeeded()
    }

    private func pauseDashboardLiveUpdates() {
        refreshTask?.cancel(); refreshTask = nil
        logStreamer.stop()
        memoryStreamer.stop()
        logFlushTask?.cancel(); logFlushTask = nil
        flushPendingLogs()
    }

    private func stopAllLiveUpdates() {
        pauseDashboardLiveUpdates()
        connectionsTask?.cancel(); connectionsTask = nil
        trafficStreamer.stop()
    }

    // MARK: - Private

    private func beginPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, coreState.isRunning, isDashboardVisible else { break }
                if selectedSection == .proxy {
                    await refreshGroups()
                }
            }
        }
    }

    private func beginConnectionsPolling() {
        connectionsTask?.cancel()
        connectionsTask = Task {
            while !Task.isCancelled {
                guard !Task.isCancelled, coreState.isRunning else { break }
                // 仅在实际停留在「连接」页时才刷新，避免其他页面下每 5s 改写 connections 触发全局重绘。
                // 切到连接页时 syncLiveDataForSection / onAppear 会立即拉一次，无需后台常驻拉取。
                if isDashboardVisible, selectedSection == .connections {
                    await refreshConnections()
                    try? await Task.sleep(for: .seconds(2))
                } else {
                    try? await Task.sleep(for: .seconds(3))
                }
            }
        }
    }

    func refreshGroups() async {
        guard coreState.isRunning else { return }
        do {
            let fetched = try await api.fetchProxyGroups()
            let oldCount = groups.count
            if fetched != groups {
                groups = fetched
                proxyDataRevision &+= 1
            }
            runtimeDataError = fetched.isEmpty ? "未解析到策略组，请确认配置已加载" : nil
            if !fetched.isEmpty, fetched.count != oldCount {
                appendAppLog(level: .debug, message: "已加载策略组 \(fetched.count) 个")
            } else if let runtimeDataError {
                appendAppLog(level: .warning, message: runtimeDataError)
            }
            if activeGroupName == nil {
                activeGroupName = groups.first(where: { $0.name == "Proxy" })?.name ?? groups.first?.name
            }
            if !fetched.isEmpty {
                SelectionStore.prune(keeping: Set(fetched.map(\.name)))
            }
        } catch {
            runtimeDataError = "代理组加载失败：\(error.localizedDescription)"
            updateStatusMessage = runtimeDataError
            appendAppLog(level: .error, message: runtimeDataError ?? "代理组加载失败")
        }
    }

    private func refreshMeta() async {
        guard coreState.isRunning else { return }
        version = (try? await api.version()) ?? version
        if let remoteMode = try? await api.fetchMode() { mode = remoteMode }
    }

    private func waitForCore(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try Task.checkCancellation()
            if await api.isReachable(timeout: 1.5) { return }
            try await Task.sleep(for: .milliseconds(300))
        }
        throw MihomoAPIError.notRunning
    }

    private func loadOrCreateDefaultProfile() throws -> String {
        let url = RuntimeConfigBuilder.profileConfigURL()
        if FileManager.default.fileExists(atPath: url.path) {
            return try String(contentsOf: url, encoding: .utf8)
        }
        let sample = """
        proxies:
          - name: DIRECT
            type: direct
        proxy-groups:
          - name: Proxy
            type: select
            proxies: [DIRECT]
        rules:
          - MATCH,Proxy
        """
        try RuntimeConfigBuilder.ensureDirectories()
        try sample.write(to: url, atomically: true, encoding: .utf8)
        return sample
    }

    private func loadPreviewData() {
        coreState = .running
        mode = .rule
        version = "v1.19.0"
        corePath = "/Applications/Clash Mac.app/Contents/Resources/Core/mihomo"
        helperStatus = "已安装"
        profiles = [
            Profile(
                name: "vpn-wpg.yaml",
                fileName: "vpn-wpg.yaml",
                subscriptionURL: "https://cloud.deanls.top/sub",
                updatedAt: .now.addingTimeInterval(-90 * 86400),
                expiresAt: Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 25)),
                isActive: true
            ),
            Profile(
                name: "mihomo",
                fileName: "mihomo.yaml",
                subscriptionURL: "https://example.com/sub2",
                updatedAt: .now.addingTimeInterval(-86400),
                expiresAt: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 30))
            ),
        ]
        activeProfile = profiles.first
        groups = [
            ProxyGroup(
                name: "手动切换",
                nodes: [
                    ProxyNode(name: "新加坡", delay: 42, isSelected: true, protocolType: "vless"),
                    ProxyNode(name: "香港", delay: 68, protocolType: "vless"),
                    ProxyNode(name: "美国", delay: 186, protocolType: "trojan"),
                    ProxyNode(name: "DIRECT", protocolType: "direct"),
                ],
                groupType: "Selector"
            ),
            ProxyGroup(
                name: "Google",
                nodes: [
                    ProxyNode(name: "新加坡", delay: 55, isSelected: true, protocolType: "vless"),
                    ProxyNode(name: "香港", delay: 72, protocolType: "vless"),
                ],
                groupType: "URLTest"
            ),
        ]
        activeGroupName = "手动切换"
        traffic = TrafficSnapshot(uploadBytesPerSec: 128_000, downloadBytesPerSec: 1_024_000)
        trafficHistory = (0..<20).map { _ in TrafficSample(upload: Int.random(in: 1000...50000), download: Int.random(in: 10000...500000)) }
        trafficTotals = TrafficTotals(uploadBytes: 5_000_000, downloadBytes: 1_170_000_000)
        unlockTargets = UnlockService.defaultTargets
        connections = [
            ConnectionItem(id: "1", host: "a.nel.cloudflare.com:443", process: "Cursor", rule: "DomainSuffix", chain: "国内网站 / DIRECT", upload: 12_400, download: 89_000, uploadSpeed: 592, downloadSpeed: 294, startedAt: .now),
            ConnectionItem(id: "2", host: "api2.cursor.sh:443", process: "Cursor", rule: "DomainSuffix", chain: "Cursor / 新加坡", upload: 8_200, download: 120_000, uploadSpeed: 1200, downloadSpeed: 8500, startedAt: .now),
            ConnectionItem(id: "3", host: "github.com:443", process: "Safari", rule: "Match", chain: "Google / 香港", upload: 400, download: 12_000, uploadSpeed: 0, downloadSpeed: 56000, startedAt: .now),
        ]
        closedConnections = [
            ConnectionItem(id: "2", host: "github.com:443", process: "Safari", rule: "DOMAIN", chain: "DIRECT", upload: 400, download: 1200, startedAt: .now.addingTimeInterval(-120), closedAt: .now)
        ]
        rules = [
            RuleItem(index: 0, type: "Domain", payload: "tagcdnsub.work", proxy: "DIRECT", isEnabled: true, hitCount: 0),
            RuleItem(index: 1, type: "DomainSuffix", payload: "oracle.com", proxy: "DIRECT", isEnabled: true, hitCount: 2),
            RuleItem(index: 2, type: "DomainSuffix", payload: "cursor.sh", proxy: "Cursor", isEnabled: true, hitCount: 48),
            RuleItem(index: 3, type: "DomainSuffix", payload: "google.com", proxy: "Google", isEnabled: true, hitCount: 128),
            RuleItem(index: 4, type: "DomainSuffix", payload: "codeium.com", proxy: "Codeium", isEnabled: true, hitCount: 12),
        ]
        displayedRuleIndices = Array(rules.indices)
        rulesMatchCount = rules.count
        unlockTargets[0].status = .unlocked("HTTP 200")
        unlockTargets[0].regionCode = "SG"
        unlockTargets[0].lastTestedAt = .now.addingTimeInterval(-3600)
        if unlockTargets.count > 1 {
            unlockTargets[1].status = .locked
            unlockTargets[1].lastTestedAt = .now.addingTimeInterval(-7200)
        }
    }
}

extension AppStore {
    func loadPreviewForDashboard() { loadPreviewData() }
}
