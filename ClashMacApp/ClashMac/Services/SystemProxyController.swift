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

    static func activeNetworkService() throws -> String {
        let output = try runNetworkSetup("-listallnetworkservices")
        let services = output
            .components(separatedBy: .newlines)
            .dropFirst()
            .filter { !$0.hasPrefix("*") && !$0.isEmpty && !$0.contains("disabled") }
        guard let first = services.first else {
            throw SystemProxyError.noNetworkService
        }
        return first
    }

    static func readProxyState(for service: String? = nil) throws -> ProxyState {
        let svc = try service ?? activeNetworkService()
        let web = try runNetworkSetup("-getwebproxy", svc)
        let socks = try runNetworkSetup("-getsocksfirewallproxy", svc)
        return ProxyState(
            httpEnabled: parseBool(web, key: "Enabled"),
            httpHost: parseString(web, key: "Server"),
            httpPort: parseInt(web, key: "Port"),
            socksEnabled: parseBool(socks, key: "Enabled"),
            socksHost: parseString(socks, key: "Server"),
            socksPort: parseInt(socks, key: "Port")
        )
    }

    static func setSystemProxy(host: String, port: Int, enabled: Bool, service: String? = nil) throws {
        let svc = try service ?? activeNetworkService()
        if enabled {
            _ = try runNetworkSetup("-setwebproxy", svc, host, String(port))
            _ = try runNetworkSetup("-setsecurewebproxy", svc, host, String(port))
            _ = try runNetworkSetup("-setsocksfirewallproxy", svc, host, String(port))
            _ = try runNetworkSetup("-setwebproxystate", svc, "on")
            _ = try runNetworkSetup("-setsecurewebproxystate", svc, "on")
            _ = try runNetworkSetup("-setsocksfirewallproxystate", svc, "on")
        } else {
            _ = try runNetworkSetup("-setwebproxystate", svc, "off")
            _ = try runNetworkSetup("-setsecurewebproxystate", svc, "off")
            _ = try runNetworkSetup("-setsocksfirewallproxystate", svc, "off")
        }
    }

    static func matchesExpected(_ state: ProxyState, host: String, port: Int) -> Bool {
        state.httpEnabled && state.socksEnabled
            && state.httpHost == host && state.httpPort == port
            && state.socksHost == host && state.socksPort == port
    }

    static func disableActiveServiceProxy() {
        try? setSystemProxy(host: "127.0.0.1", port: 7890, enabled: false)
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

    private static func runNetworkSetup(_ args: String...) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw SystemProxyError.commandFailed(output.isEmpty ? "networksetup 失败" : output)
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
