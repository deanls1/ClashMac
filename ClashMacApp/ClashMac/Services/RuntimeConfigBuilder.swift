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
    let logLevel: String

    static let `default` = RuntimeConfig(
        mixedPort: ClashMacPorts.defaultMixedPort,
        controllerHost: "127.0.0.1",
        controllerPort: ClashMacPorts.defaultControllerPort,
        controllerUnixPath: MihomoIPCPath.socketPath(),
        enableExternalController: false,
        secret: UUID().uuidString,
        mode: .rule,
        tunEnabled: false,
        tunConfig: .vergeDefault,
        dnsServers: ["223.5.5.5", "8.8.8.8"],
        ipv6Enabled: false,
        dnsOverwriteEnabled: true,
        dnsConfig: .vergeDefault,
        logLevel: "info"
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

    /// 由 Clash Mac 接管、需从 profile 整段剥离的顶层字段（对齐 Verge Rev HANDLE_FIELDS）。
    private static let managedTopLevelKeys: Set<String> = [
        "mixed-port", "port", "socks-port", "redir-port", "tproxy-port",
        "external-controller", "external-controller-unix", "external-controller-tls",
        "external-controller-cors", "external-ui", "external-ui-url", "secret",
        "allow-lan", "bind-address", "mode", "tun", "dns", "hosts", "profile",
        "log-level", "ipv6", "unified-delay", "geodata-mode", "geodata-loader",
        "geox-url", "geo-auto-update", "geo-update-interval",
    ]

    /// 将用户 profile 与运行时参数合并为 Mihomo 可用的配置。
    static func materialize(profileYAML: String, runtime: RuntimeConfig) throws -> String {
        var lines = stripManagedTopLevelBlocks(from: profileYAML)

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
        ipv6: \(runtime.ipv6Enabled)
        unified-delay: true
        tcp-concurrent: true
        external-controller-unix: \(runtime.controllerUnixPath)
        external-controller: \(httpController.isEmpty ? "\"\"" : httpController)
        secret: "\(runtime.secret)"
        mode: \(runtime.mode.rawValue)
        log-level: \(runtime.logLevel)

        profile:
          store-selected: true
          store-fake-ip: true

        geodata-mode: false
        geodata-loader: memconservative
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
        // config.yaml 内含明文 API secret：收紧为仅属主可读写（0600），
        // 并将 work 目录设为 0700，避免多用户机器上其他本地用户读取密钥。
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: workDirectory().path)
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

    /// 剥离 profile 中由运行时接管的顶层 YAML 块，避免只删 `tun:` 行留下 orphan 子项。
    static func stripManagedTopLevelBlocks(from yaml: String) -> [String] {
        let lines = yaml.components(separatedBy: .newlines)
        var result: [String] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") || line.hasPrefix(" ") || line.hasPrefix("\t") {
                result.append(line)
                index += 1
                continue
            }
            let key = trimmed.split(separator: ":", maxSplits: 1).first.map(String.init) ?? trimmed
            if managedTopLevelKeys.contains(key) {
                index += 1
                while index < lines.count {
                    let next = lines[index]
                    if next.isEmpty {
                        index += 1
                        continue
                    }
                    if !next.hasPrefix(" ") && !next.hasPrefix("\t") {
                        break
                    }
                    index += 1
                }
                continue
            }
            result.append(line)
            index += 1
        }
        return result
    }
}
