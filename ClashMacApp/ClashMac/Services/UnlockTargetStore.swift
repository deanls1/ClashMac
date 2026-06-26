import Foundation

enum UnlockTargetStore {
    private static let fileName = "unlock-targets.json"

    static func load() -> [UnlockTarget] {
        let url = RuntimeConfigBuilder.appSupportDirectory().appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url),
              let targets = try? JSONDecoder().decode([UnlockTarget].self, from: data) else {
            return UnlockService.defaultTargets
        }
        return targets.isEmpty ? UnlockService.defaultTargets : targets
    }

    static func save(_ targets: [UnlockTarget]) throws {
        try RuntimeConfigBuilder.ensureDirectories()
        let url = RuntimeConfigBuilder.appSupportDirectory().appendingPathComponent(fileName)
        let data = try JSONEncoder().encode(targets)
        try data.write(to: url, options: .atomic)
    }
}

extension UnlockService {
    static func test(_ target: UnlockTarget, activeProxyName: String?, timeout: TimeInterval = 8) async -> (UnlockStatus, String?) {
        var request = URLRequest(url: target.testURL)
        request.timeoutInterval = timeout
        request.setValue("ClashMac/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (.failed("无效响应"), nil)
            }

            let headerRegion = http.value(forHTTPHeaderField: "CF-IPCountry")
                ?? http.value(forHTTPHeaderField: "X-Country-Code")
            let inferred = headerRegion ?? inferRegion(from: activeProxyName)

            switch target.id {
            case "openai":
                if (200..<500).contains(http.statusCode) {
                    return (.unlocked("HTTP \(http.statusCode)"), inferred)
                }
                return (.locked, inferred)
            case "bilibili":
                if http.statusCode == 200, String(data: data, encoding: .utf8)?.contains("code") == true {
                    return (.unlocked("国内 OK"), inferred ?? "CN")
                }
                return (.failed("HTTP \(http.statusCode)"), inferred)
            default:
                if (200..<400).contains(http.statusCode) {
                    return (.unlocked("HTTP \(http.statusCode)"), inferred)
                }
                if http.statusCode == 403 || http.statusCode == 451 {
                    return (.locked, inferred)
                }
                return (.failed("HTTP \(http.statusCode)"), inferred)
            }
        } catch {
            return (.failed(error.localizedDescription), nil)
        }
    }

    static func inferRegion(from proxyName: String?) -> String? {
        guard let name = proxyName?.uppercased() else { return nil }
        let map = ["新加坡": "SG", "香港": "HK", "美国": "US", "日本": "JP", "台湾": "TW", "韩国": "KR"]
        for (key, code) in map where name.contains(key) { return code }
        let codes = ["SG", "HK", "US", "JP", "TW", "KR", "UK", "DE", "FR"]
        return codes.first { name.contains($0) }
    }
}
