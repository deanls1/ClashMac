import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppStore {
    // Core
    var coreState: CoreState = .stopped
    var mode: RunMode = .rule
    var tunEnabled: Bool = true
    var systemProxyEnabled: Bool = true
    var proxyGuardEnabled: Bool = true
    var corePath: String = "—"
    var helperStatus: String = "未安装"

    // Profiles
    var profiles: [Profile] = []
    var activeProfile: Profile?

    // Proxy
    var groups: [ProxyGroup] = []
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
    var logEntries: [LogEntry] = []
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
    var menuBarIconStyle: MenuBarIconStyle = .network
    var customMenuBarIconPath: String?

    // Runtime settings
    var mixedPortInput = 7890
    var controllerPortInput = 9090
    var enableExternalController = false
    var dnsServersText = "223.5.5.5, 8.8.8.8"
    var ipv6Enabled = false
    var dnsOverwriteEnabled = true
    var dnsConfig = DNSConfig.vergeDefault
    var tunConfig = TUNConfig.vergeDefault

    // Update status
    var isUpdatingCore = false
    var isUpdatingGeoData = false
    var updateStatusMessage: String?
    var isRefreshingSubscriptions = false
    var testingNodeIDs: Set<String> = []
    var isTestingAllGroups = false
    var connectionSortKey: ConnectionSortKey = .downloadSpeed
    var connectionSortDescending = true
    var appearance: AppAppearance = .system
    var ipInfo: IPInfo?
    var directIPInfo: IPInfo?
    var proxyIPInfo: IPInfo?
    var isFetchingIP = false
    var startupBanners: [StartupBanner] = []
    var dismissedBannerKinds: Set<StartupBanner.Kind> = []
    var isProfileReorderMode = false
    var isDNSOverwritePresented = false
    var isTUNConfigPresented = false

    // UI
    var selectedSection: DashboardSection = .home
    var isSettingsPresented = false
    var isRulesEditorPresented = false
    var isRefreshing = false
    var subscriptionURLInput: String = ""
    var subscriptionNameInput: String = "新订阅"

    private var runtime = RuntimeConfig.default
    private let helper = TunnelHelperClient()
    private let proxyGuard = ProxyGuard()
    private let logStreamer = MihomoLogStreamer()
    private let trafficStreamer = MihomoTrafficStreamer()
    private var refreshTask: Task<Void, Never>?
    private var connectionsTask: Task<Void, Never>?
    private var usingHelper = false
    private var connectionByteSnapshot: [String: (upload: Int, download: Int)] = [:]

    var api: MihomoAPIClient { MihomoAPIClient(runtime: runtime) }
    var mixedPort: Int { runtime.mixedPort }

    var currentSelectedNode: String? {
        groups.flatMap(\.nodes).first(where: \.isSelected)?.name
    }

    init() {
        AppSupportMigrator.migrateIfNeeded()
        helperStatus = HelperInstaller.installStatusText()
        unlockTargets = UnlockTargetStore.load()
        launchAtLogin = LaunchAtLoginService.isEnabled
        AppPreferences.apply(to: self)
        runtime = AppPreferences.makeRuntimeConfig(mode: mode)
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            loadPreviewData()
        } else {
            Task { await bootstrapProfiles() }
            registerHotkeys()
            AppLifecycleDelegate.store = self
        }
    }

    func prepareForQuit() async {
        HotkeyService.shared.removeMonitor()
        refreshTask?.cancel()
        connectionsTask?.cancel()
        refreshTask = nil
        connectionsTask = nil
        proxyGuard.stop()
        logStreamer.stop()
        trafficStreamer.stop()

        SystemProxyController.disableActiveServiceProxy()

        if usingHelper {
            helper.stopTunnelSynchronously()
        }
        CoreProcessController.shared.stop(waitForExit: false)
        usingHelper = false
        coreState = .stopped
    }

    func requestQuit() {
        AppQuit.request()
    }

    var filteredConnections: [ConnectionItem] {
        sortConnections(filterConnections(connections))
    }

    var filteredClosedConnections: [ConnectionItem] {
        sortConnections(filterConnections(closedConnections))
    }

    var filteredRules: [RuleItem] {
        rules.filter { rule in
            rulesFilterOptions.matches("\(rule.summary) \(rule.proxy)", query: rulesFilter)
        }
    }

    var filteredLogs: [LogEntry] {
        logEntries.filter { entry in
            logsDisplayFilter.matches(entry.level)
                && logsFilterOptions.matches(entry.message, query: logsFilter)
        }
    }

    private func filterConnections(_ list: [ConnectionItem]) -> [ConnectionItem] {
        list.filter { item in
            let blob = "\(item.host) \(item.process) \(item.rule) \(item.chain)"
            return connectionFilterOptions.matches(blob, query: connectionFilter)
        }
    }

    private func sortConnections(_ list: [ConnectionItem]) -> [ConnectionItem] {
        list.sorted { lhs, rhs in
            switch connectionSortKey {
            case .downloadSpeed:
                return connectionSortDescending ? lhs.downloadSpeed > rhs.downloadSpeed : lhs.downloadSpeed < rhs.downloadSpeed
            case .uploadSpeed:
                return connectionSortDescending ? lhs.uploadSpeed > rhs.uploadSpeed : lhs.uploadSpeed < rhs.uploadSpeed
            case .download:
                return connectionSortDescending ? lhs.download > rhs.download : lhs.download < rhs.download
            case .upload:
                return connectionSortDescending ? lhs.upload > rhs.upload : lhs.upload < rhs.upload
            case .host:
                let cmp = lhs.host.localizedStandardCompare(rhs.host)
                return connectionSortDescending ? cmp == .orderedDescending : cmp == .orderedAscending
            }
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

    func applyRuntimeSettings() async {
        AppPreferences.persist(from: self)
        runtime = AppPreferences.makeRuntimeConfig(mode: mode)
        registerHotkeys()
        if coreState.isRunning {
            await stop()
            await start()
        }
    }

    func updateCore() async {
        guard !isUpdatingCore else { return }
        isUpdatingCore = true
        updateStatusMessage = "正在下载内核…"
        defer { isUpdatingCore = false }
        do {
            let url = try await CoreUpdateService.downloadAndInstall()
            corePath = url.path
            version = CoreLocator.coreVersion(at: url) ?? "—"
            updateStatusMessage = "内核已更新"
        } catch {
            updateStatusMessage = error.localizedDescription
            coreState = .error(error.localizedDescription)
        }
    }

    func updateGeoData() async {
        guard !isUpdatingGeoData else { return }
        isUpdatingGeoData = true
        updateStatusMessage = "正在下载 GeoData…"
        defer { isUpdatingGeoData = false }
        do {
            try await GeoDataUpdateService.downloadAll()
            updateStatusMessage = "GeoData 已更新"
            if coreState.isRunning {
                try? await api.reloadConfig()
            }
        } catch {
            updateStatusMessage = error.localizedDescription
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

    func createBackup() {
        do {
            _ = try ConfigBackupService.createBackup()
        } catch {
            coreState = .error(error.localizedDescription)
        }
    }

    func exportDiagnostic() -> URL {
        DiagnosticExporter.export(store: self)
    }

    // MARK: - Profiles

    func bootstrapProfiles() async {
        profiles = (try? ProfileStore.loadProfiles()) ?? []
        activeProfile = ProfileStore.activeProfile(from: profiles)
        if HelperInstaller.isInstalled() {
            try? HelperTrustStore.recordCurrentUser()
        }
        await runStartupChecks()
    }

    func runStartupChecks() async {
        if let coreURL = CoreLocator.discoverCoreURL() {
            corePath = coreURL.path
            if let localVersion = CoreLocator.coreVersion(at: coreURL) {
                version = localVersion
            }
        }
        let result = await StartupCheckService.check(localCoreVersion: version)
        var banners: [StartupBanner] = []
        if !result.missingGeoData.isEmpty {
            banners.append(StartupBanner(
                kind: .geoData,
                title: "缺少 GeoData",
                message: "缺失文件：\(result.missingGeoData.joined(separator: "、"))，可能影响规则分流"
            ))
        }
        if result.coreUpdateAvailable, let latest = result.latestCoreVersion {
            banners.append(StartupBanner(
                kind: .coreUpdate,
                title: "发现新内核版本",
                message: "最新 v\(latest)，当前 \(version)"
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
        case .coreUpdate:
            await updateCore()
            await runStartupChecks()
        }
    }

    func refreshIPInfo() async {
        guard !isFetchingIP else { return }
        isFetchingIP = true
        defer { isFetchingIP = false }
        if coreState.isRunning {
            let result = await IPInfoService.fetchBoth(proxyPort: mixedPort)
            directIPInfo = result.direct
            proxyIPInfo = result.proxy
            ipInfo = result.proxy ?? result.direct
        } else {
            let direct = await IPInfoService.fetch(viaProxyPort: nil)
            directIPInfo = direct
            proxyIPInfo = nil
            ipInfo = direct
        }
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

    func refreshSubscription(_ profile: Profile) async {
        guard let url = profile.subscriptionURL else { return }
        do {
            let yaml = try await SubscriptionFetcher.download(from: url)
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
                await refreshGroups()
            }
        } catch {
            coreState = .error(error.localizedDescription)
        }
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

    func installHelper() {
        do {
            try HelperInstaller.install()
            helperStatus = HelperInstaller.installStatusText()
        } catch {
            coreState = .error("Helper 安装失败：\(error.localizedDescription)")
        }
    }

    // MARK: - Lifecycle

    func togglePower() async {
        coreState.isRunning ? await stop() : await start()
    }

    func start() async {
        guard !coreState.isRunning else { return }
        coreState = .starting
        helperStatus = HelperInstaller.installStatusText()

        do {
            let coreURL: URL
            if tunEnabled {
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

            let profileYAML: String
            if let profile = activeProfile ?? profiles.first {
                profileYAML = try ProfileStore.readProfileYAML(profile)
            } else {
                profileYAML = try loadOrCreateDefaultProfile()
            }

            AppPreferences.persist(from: self)
            runtime = AppPreferences.makeRuntimeConfig(mode: mode)
            MihomoIPCPath.removeStaleSocketIfNeeded()
            let configURL = try RuntimeConfigBuilder.writeRuntimeConfig(profileYAML: profileYAML, runtime: runtime)
            try CoreConfigValidator.validate(
                configURL: configURL,
                coreURL: coreURL,
                workDirectory: RuntimeConfigBuilder.workDirectory()
            )

            if tunEnabled {
                if !HelperInstaller.isInstalled() {
                    try HelperInstaller.install()
                    helperStatus = HelperInstaller.installStatusText()
                }
                try await helper.startTunnel(
                    corePath: coreURL.path,
                    configPath: configURL.path,
                    workDirectory: RuntimeConfigBuilder.workDirectory().path,
                    secret: runtime.secret
                )
                usingHelper = true
            } else {
                try CoreProcessController.shared.start(
                    coreURL: coreURL,
                    configURL: configURL,
                    workDirectory: RuntimeConfigBuilder.workDirectory()
                )
                usingHelper = false
            }

            try await waitForCore(timeout: 12)
            if let localVersion = CoreLocator.coreVersion(at: coreURL) {
                version = localVersion
            } else {
                version = (try? await api.version()) ?? "—"
            }

            if systemProxyEnabled && !tunEnabled {
                try SystemProxyController.setSystemProxy(host: "127.0.0.1", port: runtime.mixedPort, enabled: true)
            }
            if proxyGuardEnabled && systemProxyEnabled && !tunEnabled {
                proxyGuard.start(host: "127.0.0.1", port: runtime.mixedPort)
            }

            coreState = .running
            try? CLIInstallService.writeEnvironment(runtime: runtime)
            await refreshAll()
            await refreshIPInfo()
            beginPeriodicRefresh()
            beginConnectionsPolling()
            startLogStreamIfNeeded()
            startTrafficStreamIfNeeded()
        } catch {
            usingHelper = false
            CoreProcessController.shared.stop()
            try? await helper.stopTunnel()
            coreState = .error(error.localizedDescription)
        }
    }

    func stop() async {
        coreState = .stopping
        refreshTask?.cancel()
        connectionsTask?.cancel()
        refreshTask = nil
        connectionsTask = nil
        proxyGuard.stop()
        logStreamer.stop()
        trafficStreamer.stop()

        if usingHelper {
            try? await helper.stopTunnel()
        } else {
            CoreProcessController.shared.stop()
        }
        usingHelper = false

        try? SystemProxyController.setSystemProxy(host: "127.0.0.1", port: runtime.mixedPort, enabled: false)
        connections = []
        closedConnections = []
        connectionByteSnapshot = [:]
        groups = []
        traffic = .zero
        directIPInfo = nil
        proxyIPInfo = nil
        ipInfo = nil
        coreState = .stopped
    }

    func setMode(_ newMode: RunMode) async {
        mode = newMode
        guard coreState.isRunning else { return }
        do { try await api.setMode(newMode) } catch { coreState = .error(error.localizedDescription) }
    }

    func setTunEnabled(_ enabled: Bool) async {
        tunEnabled = enabled
        AppPreferences.tunEnabled = enabled
        if coreState.isRunning { await stop(); await start() }
    }

    func setSystemProxyEnabled(_ enabled: Bool) async {
        systemProxyEnabled = enabled
        AppPreferences.systemProxyEnabled = enabled
        guard coreState.isRunning else { return }
        try? SystemProxyController.setSystemProxy(host: "127.0.0.1", port: runtime.mixedPort, enabled: enabled)
        if proxyGuardEnabled && enabled && !tunEnabled {
            proxyGuard.start(host: "127.0.0.1", port: runtime.mixedPort)
        } else {
            proxyGuard.stop()
        }
    }

    func setProxyGuardEnabled(_ enabled: Bool) {
        proxyGuardEnabled = enabled
        AppPreferences.proxyGuardEnabled = enabled
        guard coreState.isRunning, systemProxyEnabled, !tunEnabled else {
            proxyGuard.stop()
            return
        }
        enabled ? proxyGuard.start(host: "127.0.0.1", port: runtime.mixedPort) : proxyGuard.stop()
    }

    func selectNode(group: ProxyGroup, node: ProxyNode) async {
        guard coreState.isRunning else { return }
        do {
            try await api.selectProxy(group: group.name, node: node.name)
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
            await refreshGroups()
        }
    }

    func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await refreshGroups()
        await refreshConnections()
        await refreshRules()
        await refreshMeta()
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
        for index in groups.indices where groups[index].name == group.name {
            for nodeIndex in groups[index].nodes.indices {
                await measureNode(at: index, nodeIndex: nodeIndex, testURL: testURL)
            }
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
        let fetched = (try? await api.fetchConnections()) ?? []
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

    func refreshRules() async {
        guard coreState.isRunning else { return }
        rules = (try? await api.fetchRules()) ?? []
    }

    func toggleRule(_ rule: RuleItem) async {
        guard coreState.isRunning else { return }
        do {
            try await api.setRuleEnabled(index: rule.index, enabled: !rule.isEnabled)
            await refreshRules()
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
        if coreState.isRunning { startLogStreamIfNeeded() }
    }

    func clearLogs() { logEntries.removeAll() }

    private func startLogStreamIfNeeded() {
        logStreamer.stop()
        logStreamer.start(runtime: runtime, level: logLevel) { [weak self] entry in
            Task { @MainActor in self?.appendLog(entry) }
        }
    }

    private func appendLog(_ entry: LogEntry) {
        guard !logsPaused else { return }
        logEntries.append(entry)
        if logEntries.count > 500 { logEntries.removeFirst(logEntries.count - 500) }
    }

    private func startTrafficStreamIfNeeded() {
        trafficStreamer.stop()
        trafficStreamer.start(runtime: runtime) { [weak self] up, down in
            Task { @MainActor in self?.applyTrafficSample(upload: up, download: down) }
        }
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

    private var activeProxyName: String? {
        groups.flatMap(\.nodes).first(where: \.isSelected)?.name
    }

    // MARK: - Unlock

    func runUnlockTests() async {
        guard coreState.isRunning else { return }
        for index in unlockTargets.indices {
            unlockTargets[index].status = .testing
            let (status, region) = await UnlockService.test(unlockTargets[index], activeProxyName: activeProxyName)
            unlockTargets[index].status = status
            unlockTargets[index].regionCode = region
            unlockTargets[index].lastTestedAt = .now
        }
        try? UnlockTargetStore.save(unlockTargets)
    }

    func runSingleUnlockTest(_ target: UnlockTarget) async {
        guard let index = unlockTargets.firstIndex(where: { $0.id == target.id }) else { return }
        unlockTargets[index].status = .testing
        let (status, region) = await UnlockService.test(unlockTargets[index], activeProxyName: activeProxyName)
        unlockTargets[index].status = status
        unlockTargets[index].regionCode = region
        unlockTargets[index].lastTestedAt = .now
        try? UnlockTargetStore.save(unlockTargets)
    }

    func addCustomUnlockTarget() {
        guard !customUnlockName.isEmpty, let url = URL(string: customUnlockURL) else { return }
        let target = UnlockTarget(
            id: UUID().uuidString,
            name: customUnlockName,
            symbol: "link",
            testURL: url,
            successHint: "自定义"
        )
        unlockTargets.append(target)
        customUnlockName = ""
        customUnlockURL = ""
        try? UnlockTargetStore.save(unlockTargets)
    }

    // MARK: - Private

    private func beginPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, coreState.isRunning else { break }
                await refreshGroups()
            }
        }
    }

    private func beginConnectionsPolling() {
        connectionsTask?.cancel()
        connectionsTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, coreState.isRunning else { break }
                await refreshConnections()
            }
        }
    }

    private func refreshGroups() async {
        guard coreState.isRunning else { return }
        do {
            groups = try await api.fetchProxyGroups()
            if activeGroupName == nil {
                activeGroupName = groups.first(where: { $0.name == "Proxy" })?.name ?? groups.first?.name
            }
        } catch {}
    }

    private func refreshMeta() async {
        guard coreState.isRunning else { return }
        version = (try? await api.version()) ?? version
        if let remoteMode = try? await api.fetchMode() { mode = remoteMode }
    }

    private func waitForCore(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await api.isReachable() { return }
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
            ProxyGroup(name: "手动切换", nodes: [
                ProxyNode(name: "新加坡", delay: 42, isSelected: true, protocolType: "vless"),
                ProxyNode(name: "香港", delay: 68, protocolType: "vless"),
                ProxyNode(name: "美国", delay: 186, protocolType: "trojan"),
                ProxyNode(name: "DIRECT", protocolType: "direct"),
            ]),
            ProxyGroup(name: "Google", nodes: [
                ProxyNode(name: "新加坡", delay: 55, isSelected: true, protocolType: "vless"),
                ProxyNode(name: "香港", delay: 72, protocolType: "vless"),
            ]),
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
