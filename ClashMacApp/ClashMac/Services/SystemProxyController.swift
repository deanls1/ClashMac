import Foundation

enum SystemProxyController {
    struct ProxyState: Equatable, Sendable {
        let httpEnabled: Bool
        let httpHost: String
        let httpPort: Int
        let socksEnabled: Bool
        let socksHost: String
        let socksPort: Int
    }

    /// 与 Clash Verge Rev 默认 bypass 对齐，避免本地/局域网流量误走代理。
    private static let defaultBypassDomains = [
        "127.0.0.1", "192.168.0.0/16", "10.0.0.0/8", "172.16.0.0/12",
        "localhost", "*.local", "*.crashlytics.com", "<local>",
    ]

    static func enabledNetworkServices() throws -> [String] {
        let output = try runNetworkSetup("-listallnetworkservices")
        let services = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                guard !line.isEmpty else { return false }
                guard !line.hasPrefix("*") else { return false }
                guard !line.hasPrefix("Hardware Port:") else { return false }
                guard !line.hasPrefix("Device:") else { return false }
                guard !line.contains("An asterisk") else { return false }
                return true
            }
        guard !services.isEmpty else {
            throw SystemProxyError.noNetworkService
        }
        return services
    }

    static func activeNetworkService() throws -> String {
        try enabledNetworkServices().first ?? { throw SystemProxyError.noNetworkService }()
    }

    static func readProxyState(for service: String) throws -> ProxyState {
        let web = try runNetworkSetup("-getwebproxy", service)
        let socks = try runNetworkSetup("-getsocksfirewallproxy", service)
        return ProxyState(
            httpEnabled: parseBool(web, key: "Enabled"),
            httpHost: parseString(web, key: "Server"),
            httpPort: parseInt(web, key: "Port"),
            socksEnabled: parseBool(socks, key: "Enabled"),
            socksHost: parseString(socks, key: "Server"),
            socksPort: parseInt(socks, key: "Port")
        )
    }

    /// 任一已启用网络服务的代理指向预期端口即视为生效（Wi‑Fi / 以太网等）。
    static func isProxyActive(host: String, port: Int) -> Bool {
        guard let services = try? enabledNetworkServices() else { return false }
        return services.contains { service in
            guard let state = try? readProxyState(for: service) else { return false }
            return matchesExpected(state, host: host, port: port)
        }
    }

    static func setSystemProxy(host: String, port: Int, enabled: Bool, service: String? = nil) throws {
        if let service {
            try applySystemProxy(host: host, port: port, enabled: enabled, to: service)
            return
        }

        let services = try enabledNetworkServices()
        var failures: [String] = []
        for svc in services {
            do {
                try applySystemProxy(host: host, port: port, enabled: enabled, to: svc)
            } catch {
                failures.append("\(svc): \(error.localizedDescription)")
            }
        }
        if !failures.isEmpty, failures.count == services.count {
            throw SystemProxyError.commandFailed(failures.joined(separator: "; "))
        }
    }

    static func matchesExpected(_ state: ProxyState, host: String, port: Int) -> Bool {
        state.httpEnabled && state.socksEnabled
            && state.httpHost == host && state.httpPort == port
            && state.socksHost == host && state.socksPort == port
    }

    static func disableActiveServiceProxy() {
        try? setSystemProxy(host: "127.0.0.1", port: ClashMacPorts.defaultMixedPort, enabled: false)
    }

    // MARK: - Private

    private enum SystemProxyError: LocalizedError {
        case noNetworkService
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .noNetworkService: "未找到可用网络服务"
            case .commandFailed(let msg): msg
            }
        }
    }

    private static func applySystemProxy(host: String, port: Int, enabled: Bool, to service: String) throws {
        if enabled {
            // 关闭 PAC，避免覆盖手动代理设置。
            _ = try? runNetworkSetup("-setautoproxystate", service, "off")
            _ = try runNetworkSetup("-setwebproxy", service, host, String(port))
            _ = try runNetworkSetup("-setsecurewebproxy", service, host, String(port))
            _ = try runNetworkSetup("-setsocksfirewallproxy", service, host, String(port))
            _ = try runNetworkSetup("-setproxybypassdomains", args: [service] + defaultBypassDomains)
            _ = try runNetworkSetup("-setwebproxystate", service, "on")
            _ = try runNetworkSetup("-setsecurewebproxystate", service, "on")
            _ = try runNetworkSetup("-setsocksfirewallproxystate", service, "on")
        } else {
            _ = try runNetworkSetup("-setwebproxystate", service, "off")
            _ = try runNetworkSetup("-setsecurewebproxystate", service, "off")
            _ = try runNetworkSetup("-setsocksfirewallproxystate", service, "off")
            _ = try runNetworkSetup("-setautoproxystate", service, "off")
        }
    }

    private static func runNetworkSetup(_ command: String, _ args: String...) throws -> String {
        try runNetworkSetup(command, args: args)
    }

    private static func runNetworkSetup(_ command: String, args: [String]) throws -> String {
        var arguments = [command]
        arguments.append(contentsOf: args)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw SystemProxyError.commandFailed(output.isEmpty ? "networksetup 失败" : output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output
    }

    private static func parseBool(_ text: String, key: String) -> Bool {
        text.contains("\(key): Yes")
    }

    private static func parseString(_ text: String, key: String) -> String {
        for line in text.components(separatedBy: .newlines) where line.hasPrefix("\(key):") {
            return line.replacingOccurrences(of: "\(key):", with: "").trimmingCharacters(in: .whitespaces)
        }
        return ""
    }

    private static func parseInt(_ text: String, key: String) -> Int {
        Int(parseString(text, key: key)) ?? 0
    }
}
