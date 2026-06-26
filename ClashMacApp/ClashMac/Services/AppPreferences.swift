import Foundation

enum MenuBarIconStyle: String, CaseIterable, Identifiable, Sendable {
    case network
    case shield
    case bolt
    case antenna

    var id: String { rawValue }

    var label: String {
        switch self {
        case .network: "网络"
        case .shield: "盾牌"
        case .bolt: "闪电"
        case .antenna: "信号"
        }
    }

    func symbol(running: Bool) -> String {
        switch self {
        case .network:
            running ? "network.badge.shield.half.filled" : "network"
        case .shield:
            running ? "shield.lefthalf.filled.badge.checkmark" : "shield"
        case .bolt:
            running ? "bolt.fill" : "bolt"
        case .antenna:
            running ? "antenna.radiowaves.left.and.right.circle.fill" : "antenna.radiowaves.left.and.right"
        }
    }
}

enum AppPreferences {
    nonisolated(unsafe) private static let defaults = UserDefaults.standard

    private enum Key {
        static let tunEnabled = "tunEnabled"
        static let systemProxyEnabled = "systemProxyEnabled"
        static let proxyGuardEnabled = "proxyGuardEnabled"
        static let launchAtLogin = "launchAtLogin"
        static let hotkeysEnabled = "hotkeysEnabled"
        static let globalHotkey = "globalHotkey"
        static let mixedPort = "mixedPort"
        static let controllerPort = "controllerPort"
        static let enableExternalController = "enableExternalController"
        static let dnsServers = "dnsServers"
        static let ipv6Enabled = "ipv6Enabled"
        static let dnsOverwriteEnabled = "dnsOverwriteEnabled"
        static let menuBarIconStyle = "menuBarIconStyle"
        static let customMenuBarIconPath = "customMenuBarIconPath"
        static let appearance = "appearance"
    }

    static var tunEnabled: Bool {
        get { defaults.object(forKey: Key.tunEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.tunEnabled) }
    }

    static var systemProxyEnabled: Bool {
        get { defaults.object(forKey: Key.systemProxyEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.systemProxyEnabled) }
    }

    static var proxyGuardEnabled: Bool {
        get { defaults.object(forKey: Key.proxyGuardEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.proxyGuardEnabled) }
    }

    static var hotkeysEnabled: Bool {
        get { defaults.object(forKey: Key.hotkeysEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.hotkeysEnabled) }
    }

    static var globalHotkey: Bool {
        get { defaults.object(forKey: Key.globalHotkey) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.globalHotkey) }
    }

    static var mixedPort: Int {
        get {
            let v = defaults.integer(forKey: Key.mixedPort)
            return v > 0 ? v : 7890
        }
        set { defaults.set(newValue, forKey: Key.mixedPort) }
    }

    static var controllerPort: Int {
        get {
            let v = defaults.integer(forKey: Key.controllerPort)
            return v > 0 ? v : 9090
        }
        set { defaults.set(newValue, forKey: Key.controllerPort) }
    }

    static var enableExternalController: Bool {
        get { defaults.object(forKey: Key.enableExternalController) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.enableExternalController) }
    }

    static var dnsServers: [String] {
        get {
            defaults.stringArray(forKey: Key.dnsServers) ?? ["223.5.5.5", "8.8.8.8"]
        }
        set { defaults.set(newValue, forKey: Key.dnsServers) }
    }

    static var ipv6Enabled: Bool {
        get { defaults.object(forKey: Key.ipv6Enabled) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.ipv6Enabled) }
    }

    static var dnsOverwriteEnabled: Bool {
        get { defaults.object(forKey: Key.dnsOverwriteEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.dnsOverwriteEnabled) }
    }

    static var menuBarIconStyle: MenuBarIconStyle {
        get {
            MenuBarIconStyle(rawValue: defaults.string(forKey: Key.menuBarIconStyle) ?? "") ?? .network
        }
        set { defaults.set(newValue.rawValue, forKey: Key.menuBarIconStyle) }
    }

    static var customMenuBarIconPath: String? {
        get { defaults.string(forKey: Key.customMenuBarIconPath) }
        set {
            if let newValue { defaults.set(newValue, forKey: Key.customMenuBarIconPath) }
            else { defaults.removeObject(forKey: Key.customMenuBarIconPath) }
        }
    }

    static var appearance: AppAppearance {
        get { AppAppearance(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: Key.appearance) }
    }

    static var dnsServersText: String {
        get { dnsServers.joined(separator: ", ") }
        set {
            dnsServers = newValue
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
    }

    static func makeRuntimeConfig(mode: RunMode) -> RuntimeConfig {
        RuntimeConfig(
            mixedPort: mixedPort,
            controllerHost: "127.0.0.1",
            controllerPort: controllerPort,
            controllerUnixPath: MihomoIPCPath.socketPath(),
            enableExternalController: enableExternalController,
            secret: persistedSecret(),
            mode: mode,
            tunEnabled: tunEnabled,
            tunConfig: TUNConfigStore.load(),
            dnsServers: dnsServers,
            ipv6Enabled: ipv6Enabled,
            dnsOverwriteEnabled: dnsOverwriteEnabled,
            dnsConfig: DNSConfigStore.load()
        )
    }

    @MainActor
    static func apply(to store: AppStore) {
        store.tunEnabled = tunEnabled
        store.systemProxyEnabled = systemProxyEnabled
        store.proxyGuardEnabled = proxyGuardEnabled
        store.hotkeysEnabled = hotkeysEnabled
        store.globalHotkey = globalHotkey
        store.mixedPortInput = mixedPort
        store.controllerPortInput = controllerPort
        store.enableExternalController = enableExternalController
        store.dnsServersText = dnsServersText
        store.ipv6Enabled = ipv6Enabled
        store.dnsOverwriteEnabled = dnsOverwriteEnabled
        store.dnsConfig = DNSConfigStore.load()
        store.tunConfig = TUNConfigStore.load()
        store.menuBarIconStyle = menuBarIconStyle
        store.customMenuBarIconPath = customMenuBarIconPath
        store.appearance = appearance
    }

    @MainActor
    static func persist(from store: AppStore) {
        tunEnabled = store.tunEnabled
        systemProxyEnabled = store.systemProxyEnabled
        proxyGuardEnabled = store.proxyGuardEnabled
        hotkeysEnabled = store.hotkeysEnabled
        globalHotkey = store.globalHotkey
        mixedPort = store.mixedPortInput
        controllerPort = store.controllerPortInput
        enableExternalController = store.enableExternalController
        dnsServersText = store.dnsServersText
        ipv6Enabled = store.ipv6Enabled
        dnsOverwriteEnabled = store.dnsOverwriteEnabled
        menuBarIconStyle = store.menuBarIconStyle
        customMenuBarIconPath = store.customMenuBarIconPath
        appearance = store.appearance
    }

    private static func persistedSecret() -> String {
        ControllerSecretStore.loadOrCreate()
    }
}

enum AppSupportMigrator {
    static func migrateIfNeeded() {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let oldURL = base.appendingPathComponent("LiteClash", isDirectory: true)
        let newURL = base.appendingPathComponent("ClashMac", isDirectory: true)
        guard FileManager.default.fileExists(atPath: oldURL.path),
              !FileManager.default.fileExists(atPath: newURL.path) else { return }
        try? FileManager.default.moveItem(at: oldURL, to: newURL)
    }
}
