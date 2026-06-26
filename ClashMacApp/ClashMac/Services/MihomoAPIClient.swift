import Foundation

enum MihomoAPIError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case notRunning

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Mihomo 返回无效数据"
        case .httpStatus(let code): "Mihomo HTTP \(code)"
        case .notRunning: "Mihomo 未运行"
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

    func isReachable() async -> Bool {
        (try? await version()) != nil
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

        return proxies.compactMap { name, value -> ProxyGroup? in
            guard let dict = value as? [String: Any],
                  let groupType = dict["type"] as? String,
                  groupType == "Selector" || groupType == "URLTest" || groupType == "Fallback",
                  let all = dict["all"] as? [String] else {
                return nil
            }

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
            return ProxyGroup(name: name, nodes: nodes, selectedNode: selected)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
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

    func fetchConnections() async throws -> [ConnectionItem] {
        let json = try await getJSON("/connections")
        guard let list = json["connections"] as? [[String: Any]] else {
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
        let host = metadata["host"] as? String ?? metadata["destinationIP"] as? String ?? "—"
        let process = metadata["process"] as? String ?? metadata["processPath"] as? String ?? "—"
        let rule = metadata["rule"] as? String ?? "—"
        let chains = item["chains"] as? [String] ?? []
        let upload = item["upload"] as? Int ?? 0
        let download = item["download"] as? Int ?? 0
        let start = item["start"] as? String ?? ""
        let startedAt = ISO8601DateFormatter().date(from: start) ?? .now
        return ConnectionItem(
            id: id,
            host: host,
            process: (process as NSString).lastPathComponent,
            rule: rule,
            chain: chains.joined(separator: " → "),
            upload: upload,
            download: download,
            startedAt: startedAt
        )
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
