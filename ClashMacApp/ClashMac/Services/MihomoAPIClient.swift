import Foundation

enum MihomoAPIError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case notRunning

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Mihomo 返回无效数据"
        case .httpStatus(let code): "Mihomo HTTP \(code)"
        case .notRunning: "Mihomo 启动超时，请重试或查看日志"
        }
    }
}

struct MihomoAPIClient: Sendable {
    let socketPath: String
    let secret: String
    let fallbackHTTP: URL?

    init(runtime: RuntimeConfig) {
        self.socketPath = runtime.controllerUnixPath
        self.secret = runtime.secret
        self.fallbackHTTP = runtime.enableExternalController ? runtime.controllerBaseURL : nil
    }

    // MARK: - Public API

    func version() async throws -> String {
        let data = try await get("/version")
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
    }

    func isReachable(timeout: TimeInterval = 2) async -> Bool {
        await withCheckedContinuation { continuation in
            let gate = ReachabilityGate()
            Task {
                let ok = (try? await version()) != nil
                gate.finish(ok, continuation: continuation)
            }
            Task {
                try? await Task.sleep(for: .seconds(timeout))
                gate.finish(false, continuation: continuation)
            }
        }
    }

    func fetchMode() async throws -> RunMode {
        let json = try await getJSON("/configs")
        guard let mode = json["mode"] as? String,
              let runMode = RunMode(rawValue: mode) else {
            throw MihomoAPIError.invalidResponse
        }
        return runMode
    }

    func setMode(_ mode: RunMode) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["mode": mode.rawValue])
        _ = try await patch("/configs", body: body)
    }

    func fetchProxyGroups() async throws -> [ProxyGroup] {
        let json = try await getJSON("/proxies")
        guard let proxies = json["proxies"] as? [String: Any] else {
            throw MihomoAPIError.invalidResponse
        }

        let leafTypes: Set<String> = [
            "Direct", "Reject", "RejectDrop", "Pass", "Dns", "Compatible",
            "Shadowsocks", "ShadowsocksR", "Snell", "Socks5", "Http", "Https",
            "Vmess", "Vless", "Trojan", "Hysteria", "Hysteria2", "Tuic", "TuicServer",
            "WireGuard", "Ssh", "Mieru", "AnyTLS", "Internal",
        ]

        return proxies.compactMap { name, value -> ProxyGroup? in
            guard name != "GLOBAL" else { return nil }
            guard let dict = value as? [String: Any] else { return nil }
            let groupType = dict["type"] as? String ?? "Selector"
            if leafTypes.contains(groupType) { return nil }

            let all = dict["all"] as? [String] ?? []
            guard !all.isEmpty || isGroupType(groupType) else { return nil }

            let selected = dict["now"] as? String
            let nodes = all.map { nodeName -> ProxyNode in
                var node = ProxyNode(name: nodeName, isSelected: nodeName == selected)
                if let proxyDict = proxies[nodeName] as? [String: Any] {
                    node.protocolType = proxyDict["type"] as? String
                    if let history = proxyDict["history"] as? [[String: Any]],
                       let last = history.last,
                       let delay = last["delay"] as? Int {
                        node.delay = delay
                    }
                }
                return node
            }
            return ProxyGroup(name: name, nodes: nodes, selectedNode: selected, groupType: groupType)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func isGroupType(_ type: String) -> Bool {
        let groupTypes: Set<String> = [
            "Selector", "URLTest", "Fallback", "LoadBalance", "Relay", "Smart",
            "select", "url-test", "fallback", "load-balance", "relay",
        ]
        return groupTypes.contains(type)
    }

    func fetchProxyProviders() async throws -> [ProxyProvider] {
        let json = try await getJSON("/providers/proxies")
        guard let providers = json["providers"] as? [String: Any] else {
            throw MihomoAPIError.invalidResponse
        }
        return providers.compactMap { name, value -> ProxyProvider? in
            guard let dict = value as? [String: Any] else { return nil }
            let vehicleType = dict["vehicleType"] as? String ?? "—"
            let updatedAt = parseProviderDate(dict["updatedAt"] as? String)
            return ProxyProvider(name: name, vehicleType: vehicleType, updatedAt: updatedAt)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func updateProxyProvider(_ name: String) async throws {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        _ = try await put("/providers/proxies/\(encoded)", body: Data())
    }

    private func parseProviderDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let standard = ISO8601DateFormatter()
        return standard.date(from: value)
    }

    func selectProxy(group: String, node: String) async throws {
        let encoded = group.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? group
        let body = try JSONSerialization.data(withJSONObject: ["name": node])
        _ = try await put("/proxies/\(encoded)", body: body)
    }

    func measureDelay(proxy: String, testURL: URL, timeoutMs: Int = 5000) async throws -> Int {
        let encoded = proxy.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? proxy
        let query = "url=\(testURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&timeout=\(timeoutMs)"
        let data = try await get("/proxies/\(encoded)/delay", query: query)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let delay = json["delay"] as? Int else {
            throw MihomoAPIError.invalidResponse
        }
        return delay
    }

    func setLogLevel(_ level: LogLevel) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["log-level": level.rawValue])
        _ = try await patch("/configs", body: body)
    }

    func fetchConnections() async throws -> [ConnectionItem] {
        let json = try await getJSON("/connections")
        guard let raw = json["connections"] else { return [] }
        if raw is NSNull { return [] }
        guard let list = raw as? [[String: Any]] else {
            throw MihomoAPIError.invalidResponse
        }
        return list.compactMap { parseConnection($0) }
    }

    func closeConnection(id: String) async throws {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        _ = try await delete("/connections/\(encoded)")
    }

    func closeAllConnections() async throws {
        _ = try await delete("/connections")
    }

    func fetchRules() async throws -> [RuleItem] {
        let json = try await getJSON("/rules")
        guard let list = json["rules"] as? [[String: Any]] else {
            throw MihomoAPIError.invalidResponse
        }
        return list.enumerated().compactMap { index, item in
            parseRule(index: index, item)
        }
    }

    func setRuleEnabled(index: Int, enabled: Bool) async throws {
        let path = enabled ? "/rules/\(index)/enable" : "/rules/\(index)/disable"
        _ = try await patch(path, body: Data())
    }

    func reloadConfig() async throws {
        _ = try await put("/configs?force=true", body: Data())
    }

    // MARK: - Parsing

    private func parseConnection(_ item: [String: Any]) -> ConnectionItem? {
        guard let id = item["id"] as? String else { return nil }
        let metadata = item["metadata"] as? [String: Any] ?? [:]
        let host = metadata["host"] as? String
            ?? metadata["destinationIP"] as? String
            ?? metadata["destination"] as? String
            ?? "—"
        let processPath = metadata["processPath"] as? String ?? metadata["process"] as? String ?? "—"
        let process = (processPath as NSString).lastPathComponent
        let ruleName = metadata["rule"] as? String ?? "—"
        let rulePayload = metadata["rulePayload"] as? String ?? metadata["payload"] as? String ?? ""
        let rule = rulePayload.isEmpty ? ruleName : "\(ruleName) · \(rulePayload)"
        let chains = item["chains"] as? [String] ?? []
        let upload = Self.jsonInt(item["upload"])
        let download = Self.jsonInt(item["download"])
        let start = item["start"] as? String ?? ""
        let startedAt = ISO8601DateFormatter().date(from: start) ?? .now
        return ConnectionItem(
            id: id,
            host: host,
            process: process.isEmpty ? "—" : process,
            rule: rule,
            chain: chains.joined(separator: " → "),
            upload: upload,
            download: download,
            startedAt: startedAt
        )
    }

    private static func jsonInt(_ value: Any?) -> Int {
        if let v = value as? Int { return v }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String, let v = Int(s) { return v }
        return 0
    }

    private func parseRule(index: Int, _ item: [String: Any]) -> RuleItem? {
        guard let type = item["type"] as? String,
              let proxy = item["proxy"] as? String else { return nil }
        let payload = item["payload"] as? String ?? ""
        let enabled = item["enabled"] as? Bool ?? true
        let hitCount = item["hitCount"] as? Int ?? 0
        return RuleItem(index: index, type: type, payload: payload, proxy: proxy, isEnabled: enabled, hitCount: hitCount)
    }

    // MARK: - Transport

    private func get(_ path: String, query: String? = nil) async throws -> Data {
        try await transport(method: "GET", path: path, query: query, body: nil)
    }

    private func getJSON(_ path: String) async throws -> [String: Any] {
        let data = try await get(path)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MihomoAPIError.invalidResponse
        }
        return json
    }

    private func patch(_ path: String, body: Data) async throws -> Data {
        try await transport(method: "PATCH", path: path, query: nil, body: body)
    }

    private func put(_ path: String, body: Data) async throws -> Data {
        try await transport(method: "PUT", path: path, query: nil, body: body)
    }

    private func delete(_ path: String) async throws -> Data {
        try await transport(method: "DELETE", path: path, query: nil, body: nil)
    }

    private func transport(method: String, path: String, query: String?, body: Data?) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try MihomoUnixTransport.request(
                        socketPath: self.socketPath,
                        method: method,
                        path: path,
                        secret: self.secret,
                        body: body,
                        query: query
                    )
                    continuation.resume(returning: data)
                } catch let error as MihomoUnixTransportError {
                    if case .httpStatus(let code) = error {
                        continuation.resume(throwing: MihomoAPIError.httpStatus(code))
                    } else {
                        continuation.resume(throwing: error)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private final class ReachabilityGate: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false

    func finish(_ value: Bool, continuation: CheckedContinuation<Bool, Never>) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }
        finished = true
        continuation.resume(returning: value)
    }
}
