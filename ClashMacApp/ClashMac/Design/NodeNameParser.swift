import Foundation

enum NodeNameParser {
    private static let codeMap: [String: String] = [
        "HK": "HK", "SG": "SG", "US": "US", "JP": "JP", "TW": "TW", "KR": "KR",
        "UK": "GB", "GB": "GB", "DE": "DE", "FR": "FR", "CA": "CA", "AU": "AU",
        "NL": "NL", "RU": "RU", "IN": "IN", "TR": "TR", "VN": "VN", "TH": "TH",
        "MY": "MY", "PH": "PH", "ID": "ID", "BR": "BR", "MX": "MX",
        "香港": "HK", "新加坡": "SG", "美国": "US", "日本": "JP", "台湾": "TW",
        "韩国": "KR", "英国": "GB", "德国": "DE", "法国": "FR", "加拿大": "CA",
        "澳大利亚": "AU", "荷兰": "NL", "俄罗斯": "RU", "印度": "IN", "土耳其": "TR",
        "越南": "VN", "泰国": "TH", "马来西亚": "MY", "菲律宾": "PH", "印尼": "ID"
    ]

    static func countryFlag(from name: String) -> String? {
        if let leading = name.first, leading.unicodeScalars.first?.properties.isEmoji == true {
            let prefix = name.prefix(while: { $0.unicodeScalars.first?.properties.isEmoji == true })
            if !prefix.isEmpty { return String(prefix) }
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count == 2, trimmed.allSatisfy(\.isLetter) {
            return flagEmoji(for: trimmed.uppercased())
        }

        let upper = name.uppercased()
        for (key, code) in codeMap where key.count == 2 {
            if upper.contains(key) { return flagEmoji(for: code) }
        }
        for (key, code) in codeMap where key.count > 2 {
            if name.contains(key) { return flagEmoji(for: code) }
        }
        return nil
    }

    static func protocolLabel(_ type: String?) -> String {
        guard let type else { return "—" }
        switch type.lowercased() {
        case "shadowsocks", "ss": return "SS"
        case "vmess": return "VMess"
        case "vless": return "Vless"
        case "trojan": return "Trojan"
        case "hysteria", "hysteria2": return "Hy2"
        case "tuic": return "TUIC"
        case "wireguard": return "WG"
        case "direct": return "Direct"
        case "reject": return "Reject"
        case "selector": return "Select"
        case "urltest": return "URLTest"
        case "fallback": return "Fallback"
        case "relay": return "Relay"
        default: return type.capitalized
        }
    }

    static func transportTags(for node: ProxyNode) -> [String] {
        var tags: [String] = []
        if let type = node.protocolType?.lowercased() {
            tags.append(protocolLabel(node.protocolType))
            if type == "vless" || type == "vmess" || type == "trojan" {
                tags.append("UDP")
                if type == "vless" { tags.append("XUDP") }
            }
        }
        return tags
    }

    private static func flagEmoji(for code: String) -> String {
        let base: UInt32 = 127397
        return code.uppercased().unicodeScalars.compactMap { scalar in
            UnicodeScalar(base + scalar.value)
        }.map { String($0) }.joined()
    }
}
