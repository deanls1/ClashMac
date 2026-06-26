import Foundation

/// TUN 模式配置，对齐 Clash Verge Rev 虚拟网卡设置项。
struct TUNConfig: Codable, Equatable, Sendable {
    var stack: String = "system"
    var device: String = "utun1024"
    var autoRoute: Bool = true
    var strictRoute: Bool = false
    var autoDetectInterface: Bool = true
    var dnsHijack: [String] = ["any:53"]
    var mtu: Int = 1500
    var routeExcludeAddress: [String] = [
        "192.168.0.0/16",
        "10.0.0.0/8",
        "172.16.0.0/12",
    ]

    static let vergeDefault = TUNConfig()

    func yamlLines(enabled: Bool) -> [String] {
        var lines = [
            "tun:",
            "  enable: \(enabled)",
            "  stack: \(stack)",
            "  device: \(device)",
            "  auto-route: \(autoRoute)",
            "  strict-route: \(strictRoute)",
            "  auto-detect-interface: \(autoDetectInterface)",
            "  mtu: \(mtu)",
            "  dns-hijack:",
        ]
        dnsHijack.forEach { lines.append("    - \($0)") }
        if !routeExcludeAddress.isEmpty {
            lines.append("  route-exclude-address:")
            routeExcludeAddress.forEach { lines.append("    - \($0)") }
        }
        return lines
    }
}

enum TUNConfigStore {
    static func fileURL() -> URL {
        RuntimeConfigBuilder.appSupportDirectory().appendingPathComponent("tun.json")
    }

    static func load() -> TUNConfig {
        let url = fileURL()
        guard let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(TUNConfig.self, from: data) else {
            return .vergeDefault
        }
        return config
    }

    static func save(_ config: TUNConfig) throws {
        try RuntimeConfigBuilder.ensureDirectories()
        let data = try JSONEncoder().encode(config)
        try data.write(to: fileURL(), options: .atomic)
    }
}
