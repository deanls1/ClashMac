import Foundation

/// DNS 覆写配置，对齐 Clash Verge Rev 默认项与字段。
struct DNSConfig: Codable, Equatable, Sendable {
    var enable: Bool = true
    var listen: String = ":53"
    var enhancedMode: String = "fake-ip"
    var fakeIPRange: String = "198.18.0.1/16"
    var fakeIPFilterMode: String = "blacklist"
    var preferH3: Bool = false
    var respectRules: Bool = false
    var useHosts: Bool = false
    var useSystemHosts: Bool = false
    var ipv6: Bool = true
    var fakeIPFilter: [String] = [
        "*.lan", "*.local", "*.arpa", "time.*.com", "ntp.*.com",
        "+.market.xiaomi.com", "localhost.ptlogin2.qq.com",
        "*.msftncsi.com", "www.msftconnecttest.com",
    ]
    var defaultNameserver: [String] = [
        "system", "223.6.6.6", "8.8.8.8", "2400:3200::1", "2001:4860:4860::8888",
    ]
    var nameserver: [String] = [
        "8.8.8.8", "https://doh.pub/dns-query", "https://dns.alidns.com/dns-query",
    ]
    var fallback: [String] = []
    var proxyServerNameserver: [String] = [
        "https://doh.pub/dns-query", "https://dns.alidns.com/dns-query", "tls://223.5.5.5",
    ]
    var directNameserver: [String] = []
    var directNameserverFollowPolicy: Bool = false
    var fallbackGeoip: Bool = true
    var fallbackGeoipCode: String = "CN"
    var fallbackIpcidr: [String] = ["240.0.0.0/4", "0.0.0.0/32"]
    var fallbackDomain: [String] = ["+.google.com", "+.facebook.com", "+.youtube.com"]
    var nameserverPolicyText: String = ""
    var hostsText: String = ""

    static let vergeDefault = DNSConfig()

    func yamlBlock(includePrivilegedListen: Bool = true) -> String {
        var lines: [String] = ["dns:", "  enable: \(enable)"]
        if includePrivilegedListen, !listen.isEmpty {
            lines.append("  listen: '\(listen)'")
        }
        lines.append("  enhanced-mode: \(enhancedMode)")
        lines.append("  fake-ip-range: '\(fakeIPRange)'")
        lines.append("  fake-ip-filter-mode: \(fakeIPFilterMode)")
        lines.append("  prefer-h3: \(preferH3)")
        lines.append("  respect-rules: \(respectRules)")
        lines.append("  use-hosts: \(useHosts)")
        lines.append("  use-system-hosts: \(useSystemHosts)")
        lines.append("  ipv6: \(ipv6)")
        lines.append("  fake-ip-filter:")
        fakeIPFilter.forEach { lines.append("    - \($0)") }
        lines.append("  default-nameserver:")
        defaultNameserver.forEach { lines.append("    - \($0)") }
        lines.append("  nameserver:")
        nameserver.forEach { lines.append("    - \($0)") }
        if !fallback.isEmpty {
            lines.append("  fallback:")
            fallback.forEach { lines.append("    - \($0)") }
        }
        lines.append("  proxy-server-nameserver:")
        proxyServerNameserver.forEach { lines.append("    - \($0)") }
        if !directNameserver.isEmpty {
            lines.append("  direct-nameserver:")
            directNameserver.forEach { lines.append("    - \($0)") }
        }
        lines.append("  direct-nameserver-follow-policy: \(directNameserverFollowPolicy)")
        let policy = DNSConfig.parseNameserverPolicy(nameserverPolicyText)
        if !policy.isEmpty {
            lines.append("  nameserver-policy:")
            for (key, servers) in policy.sorted(by: { $0.key < $1.key }) {
                if servers.count == 1 {
                    lines.append("    '\(key)': \(servers[0])")
                } else {
                    lines.append("    '\(key)':")
                    servers.forEach { lines.append("      - \($0)") }
                }
            }
        }
        lines.append("  fallback-filter:")
        lines.append("    geoip: \(fallbackGeoip)")
        lines.append("    geoip-code: \(fallbackGeoipCode)")
        lines.append("    ipcidr:")
        fallbackIpcidr.forEach { lines.append("      - \($0)") }
        lines.append("    domain:")
        fallbackDomain.forEach { lines.append("      - \($0)") }
        return lines.joined(separator: "\n")
    }

    func hostsYAMLBlock() -> String? {
        let hosts = DNSConfig.parseHosts(hostsText)
        guard !hosts.isEmpty else { return nil }
        var lines = ["hosts:"]
        for (domain, value) in hosts.sorted(by: { $0.key < $1.key }) {
            if value.count == 1 {
                lines.append("  '\(domain)': \(value[0])")
            } else {
                lines.append("  '\(domain)':")
                value.forEach { lines.append("    - \($0)") }
            }
        }
        return lines.joined(separator: "\n")
    }

    static func parseList(_ text: String) -> [String] {
        text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func parseNameserverPolicy(_ text: String) -> [String: [String]] {
        var result: [String: [String]] = [:]
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return result }
        for part in text.split(separator: ",") {
            let pair = part.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard pair.count == 2 else { continue }
            result[pair[0]] = pair[1].split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        return result
    }

    static func parseHosts(_ text: String) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for part in text.split(separator: ",") {
            let pair = part.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard pair.count == 2 else { continue }
            let values = pair[1].split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }
            result[pair[0]] = values
        }
        return result
    }
}

enum DNSConfigStore {
    static func fileURL() -> URL {
        RuntimeConfigBuilder.appSupportDirectory().appendingPathComponent("dns.yaml")
    }

    static func load() -> DNSConfig {
        let url = fileURL()
        guard let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(DNSConfig.self, from: data) else {
            return .vergeDefault
        }
        return config
    }

    static func save(_ config: DNSConfig) throws {
        try RuntimeConfigBuilder.ensureDirectories()
        let data = try JSONEncoder().encode(config)
        try data.write(to: fileURL(), options: .atomic)
    }
}
