import Foundation

struct RuntimeConfig: Sendable {
    let mixedPort: Int
    let controllerHost: String
    let controllerPort: Int
    let controllerUnixPath: String
    let enableExternalController: Bool
    let secret: String
    let mode: RunMode
    let tunEnabled: Bool
    let tunConfig: TUNConfig
    let dnsServers: [String]
    let ipv6Enabled: Bool
    let dnsOverwriteEnabled: Bool
    let dnsConfig: DNSConfig

    static let `default` = RuntimeConfig(
        mixedPort: 7890,
        controllerHost: "127.0.0.1",
        controllerPort: 9090,
        controllerUnixPath: MihomoIPCPath.socketPath(),
        enableExternalController: false,
        secret: UUID().uuidString,
        mode: .rule,
        tunEnabled: true,
        tunConfig: .vergeDefault,
        dnsServers: ["223.5.5.5", "8.8.8.8"],
        ipv6Enabled: false,
        dnsOverwriteEnabled: true,
        dnsConfig: .vergeDefault
    )

    var controllerBaseURL: URL {
        URL(string: "http://\(controllerHost):\(controllerPort)")!
    }
}

enum RuntimeConfigBuilder {
    static func appSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("ClashMac", isDirectory: true)
    }

    static func workDirectory() -> URL {
        appSupportDirectory().appendingPathComponent("work", isDirectory: true)
    }

    static func runtimeConfigURL() -> URL {
        workDirectory().appendingPathComponent("config.yaml")
    }

    static func profileConfigURL() -> URL {
        appSupportDirectory().appendingPathComponent("profile.yaml")
    }

    /// 将用户 profile 与运行时参数合并为 Mihomo 可用的配置。
    static func materialize(profileYAML: String, runtime: RuntimeConfig) throws -> String {
        var lines = profileYAML
            .components(separatedBy: .newlines)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let blockedPrefixes = [
                    "mixed-port:", "port:", "socks-port:", "redir-port:", "tproxy-port:",
                    "external-controller:", "external-controller-unix:", "external-controller-cors:",
                    "secret:", "allow-lan:", "bind-address:",
                    "mode:", "tun:", "dns:", "hosts:", "log-level:", "ipv6:", "unified-delay:"
                ]
                return !blockedPrefixes.contains { trimmed.hasPrefix($0) }
            }

        var dnsBlock: String
        if runtime.dnsOverwriteEnabled {
            dnsBlock = runtime.dnsConfig.yamlBlock(includePrivilegedListen: runtime.tunEnabled)
            if let hosts = runtime.dnsConfig.hostsYAMLBlock() {
                dnsBlock += "\n\n" + hosts
            }
        } else {
            let dnsList = runtime.dnsServers.map { "    - \($0)" }.joined(separator: "\n")
            let ipv6Block = runtime.ipv6Enabled ? "  ipv6: true" : "  ipv6: false"
            dnsBlock = """
            dns:
              enable: true
              enhanced-mode: fake-ip
            \(ipv6Block)
              nameserver:
            \(dnsList)
            """
        }

        let tunBlock = runtime.tunConfig.yamlLines(enabled: runtime.tunEnabled).joined(separator: "\n")

        let httpController: String
        if runtime.enableExternalController {
            httpController = Self.guardedControllerAddress(host: runtime.controllerHost, port: runtime.controllerPort)
        } else {
            httpController = ""
        }

        var corsBlock = ""
        if runtime.enableExternalController {
            corsBlock = """

            external-controller-cors:
              allow-private-network: true
              allow-origins:
                - tauri://localhost
                - http://tauri.localhost
                - https://yacd.metacubex.one
                - https://metacubex.github.io
                - https://board.zash.run.place
            """
        }

        let runtimeBlock = """

        # --- Clash Mac runtime (auto-generated) ---
        mixed-port: \(runtime.mixedPort)
        allow-lan: false
        external-controller-unix: \(runtime.controllerUnixPath)
        external-controller: \(httpController.isEmpty ? "\"\"" : httpController)
        secret: "\(runtime.secret)"
        mode: \(runtime.mode.rawValue)

        geodata-mode: standard
        \(corsBlock)

        \(tunBlock)

        \(dnsBlock)
        """

        lines.append(runtimeBlock)
        return lines.joined(separator: "\n")
    }

    static func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: workDirectory(), withIntermediateDirectories: true)
    }

    static func writeRuntimeConfig(profileYAML: String, runtime: RuntimeConfig) throws -> URL {
        try MihomoIPCPath.ensureDirectory()
        try ensureDirectories()
        let content = try materialize(profileYAML: profileYAML, runtime: runtime)
        let url = runtimeConfigURL()
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// 强制 external-controller 绑定本机回环地址（对齐 Verge Rev 的 guard_server_ctrl 行为）。
    static func guardedControllerAddress(host: String, port: Int) -> String {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains(":") {
            return normalizeControllerEndpoint(trimmed, fallbackPort: port)
        }
        if trimmed.isEmpty || trimmed == "0.0.0.0" || trimmed == "::" || trimmed == "[::]" {
            return "127.0.0.1:\(port)"
        }
        if trimmed == "localhost" {
            return "127.0.0.1:\(port)"
        }
        return "\(trimmed):\(port)"
    }

    private static func normalizeControllerEndpoint(_ value: String, fallbackPort: Int) -> String {
        if value.hasPrefix(":") {
            return "127.0.0.1\(value)"
        }
        if value.hasPrefix("[::]:") {
            return "127.0.0.1:\(value.split(separator: ":").last.map(String.init) ?? "\(fallbackPort)")"
        }
        if value.hasPrefix("0.0.0.0:") {
            return value.replacingOccurrences(of: "0.0.0.0", with: "127.0.0.1")
        }
        return value
    }
}
