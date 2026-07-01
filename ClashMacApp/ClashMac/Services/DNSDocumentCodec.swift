import Foundation

enum DNSDocumentCodec {
    enum Error: LocalizedError {
        case invalidFormat(String)

        var errorDescription: String? {
            switch self {
            case .invalidFormat(let msg): msg
            }
        }
    }

    static func encode(_ config: DNSConfig, includePrivilegedListen: Bool) -> String {
        var parts = [config.yamlBlock(includePrivilegedListen: includePrivilegedListen)]
        if let hosts = config.hostsYAMLBlock() {
            parts.append(hosts)
        }
        return parts.joined(separator: "\n\n")
    }

    static func decode(_ text: String) throws -> DNSConfig {
        var config = DNSConfig.vergeDefault
        var section: Section = .root
        var arrayKey: String?

        for rawLine in text.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            if trimmed == "dns:" {
                section = .dns
                arrayKey = nil
                continue
            }
            if trimmed == "hosts:" {
                section = .hosts
                arrayKey = nil
                continue
            }

            if section == .hosts {
                if let (domain, value) = parseMappingLine(trimmed) {
                    appendHosts(domain: domain, value: value, to: &config)
                }
                continue
            }

            guard section == .dns else { continue }

            if trimmed == "fake-ip-filter:" {
                config.fakeIPFilter = []
                arrayKey = "fake-ip-filter"
                continue
            }
            if trimmed == "default-nameserver:" {
                config.defaultNameserver = []
                arrayKey = "default-nameserver"
                continue
            }
            if trimmed == "nameserver:" {
                config.nameserver = []
                arrayKey = "nameserver"
                continue
            }
            if trimmed == "fallback:" {
                config.fallback = []
                arrayKey = "fallback"
                continue
            }
            if trimmed == "proxy-server-nameserver:" {
                config.proxyServerNameserver = []
                arrayKey = "proxy-server-nameserver"
                continue
            }
            if trimmed == "direct-nameserver:" {
                config.directNameserver = []
                arrayKey = "direct-nameserver"
                continue
            }
            if trimmed == "nameserver-policy:" {
                arrayKey = "nameserver-policy"
                continue
            }
            if trimmed == "fallback-filter:" {
                arrayKey = "fallback-filter"
                continue
            }
            if trimmed == "ipcidr:" {
                config.fallbackIpcidr = []
                arrayKey = "ipcidr"
                continue
            }
            if trimmed == "domain:" {
                config.fallbackDomain = []
                arrayKey = "domain"
                continue
            }

            if trimmed.hasPrefix("- ") {
                let value = unquote(String(trimmed.dropFirst(2)))
                appendArrayValue(value, key: arrayKey, to: &config)
                continue
            }

            if let (key, value) = parseKeyValue(trimmed) {
                applyScalar(key: key, value: value, arrayKey: &arrayKey, config: &config)
            }
        }

        return config
    }

    // MARK: - Private

    private enum Section {
        case root, dns, hosts
    }

    private static func parseKeyValue(_ line: String) -> (String, String)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
        let value = unquote(String(line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)))
        guard !key.isEmpty else { return nil }
        return (key, value)
    }

    private static func parseMappingLine(_ line: String) -> (String, String)? {
        if let (key, value) = parseKeyValue(line) {
            return (unquote(key), unquote(value))
        }
        return nil
    }

    private static func unquote(_ value: String) -> String {
        var v = value.trimmingCharacters(in: .whitespaces)
        if (v.hasPrefix("'") && v.hasSuffix("'")) || (v.hasPrefix("\"") && v.hasSuffix("\"")) {
            v = String(v.dropFirst().dropLast())
        }
        return v.replacingOccurrences(of: "''", with: "'")
    }

    private static func appendArrayValue(_ value: String, key: String?, to config: inout DNSConfig) {
        guard let key else { return }
        switch key {
        case "fake-ip-filter": config.fakeIPFilter.append(value)
        case "default-nameserver": config.defaultNameserver.append(value)
        case "nameserver": config.nameserver.append(value)
        case "fallback": config.fallback.append(value)
        case "proxy-server-nameserver": config.proxyServerNameserver.append(value)
        case "direct-nameserver": config.directNameserver.append(value)
        case "ipcidr": config.fallbackIpcidr.append(value)
        case "domain": config.fallbackDomain.append(value)
        default: break
        }
    }

    private static func applyScalar(
        key: String,
        value: String,
        arrayKey: inout String?,
        config: inout DNSConfig
    ) {
        switch key {
        case "enable": config.enable = value == "true"
        case "listen": config.listen = value
        case "enhanced-mode": config.enhancedMode = value
        case "fake-ip-range": config.fakeIPRange = value
        case "fake-ip-filter-mode": config.fakeIPFilterMode = value
        case "prefer-h3": config.preferH3 = value == "true"
        case "respect-rules": config.respectRules = value == "true"
        case "use-hosts": config.useHosts = value == "true"
        case "use-system-hosts": config.useSystemHosts = value == "true"
        case "ipv6": config.ipv6 = value == "true"
        case "direct-nameserver-follow-policy":
            config.directNameserverFollowPolicy = value == "true"
        case "geoip": config.fallbackGeoip = value == "true"
        case "geoip-code": config.fallbackGeoipCode = value
        default:
            if arrayKey == "nameserver-policy" {
                let domain = unquote(key)
                let entry = "\(domain)=\(value.replacingOccurrences(of: ", ", with: ";"))"
                config.nameserverPolicyText = config.nameserverPolicyText.isEmpty
                    ? entry
                    : "\(config.nameserverPolicyText), \(entry)"
            }
        }
    }

    private static func appendHosts(domain: String, value: String, to config: inout DNSConfig) {
        let entry = "\(domain)=\(value)"
        config.hostsText = config.hostsText.isEmpty ? entry : "\(config.hostsText), \(entry)"
    }
}
