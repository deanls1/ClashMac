import Foundation

enum ProfileYAMLSection: String, Sendable {
    case full
    case rules
    case proxies
    case proxyGroups

    var editorTitle: String {
        switch self {
        case .full: "编辑文件"
        case .rules: "编辑规则"
        case .proxies: "编辑节点"
        case .proxyGroups: "编辑代理组"
        }
    }

    var rootKey: String? {
        switch self {
        case .full: nil
        case .rules: "rules"
        case .proxies: "proxies"
        case .proxyGroups: "proxy-groups"
        }
    }
}

enum ProfileYAMLSectionEditor {
    static func load(section: ProfileYAMLSection, from profile: Profile) throws -> String {
        let profileText = try String(contentsOf: profile.fileURL, encoding: .utf8)
        guard let key = section.rootKey else { return profileText }
        return extractSection(key: key, from: profileText)
            ?? defaultSection(key: key)
    }

    static func save(section: ProfileYAMLSection, yaml: String, to profile: Profile) throws {
        if section == .full {
            try yaml.write(to: profile.fileURL, atomically: true, encoding: .utf8)
            return
        }
        guard let key = section.rootKey else { return }
        var profileText = try String(contentsOf: profile.fileURL, encoding: .utf8)
        profileText = replaceSection(key: key, in: profileText, with: yaml)
        try profileText.write(to: profile.fileURL, atomically: true, encoding: .utf8)
    }

    static func extractSection(key: String, from profile: String) -> String? {
        let lines = profile.components(separatedBy: .newlines)
        let marker = "\(key):"
        guard let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == marker }) else {
            return nil
        }
        var end = start + 1
        while end < lines.count {
            let line = lines[end]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                end += 1
                continue
            }
            if !line.hasPrefix(" ") && !line.hasPrefix("\t") && trimmed.contains(":") {
                break
            }
            end += 1
        }
        return lines[start..<end].joined(separator: "\n")
    }

    private static func replaceSection(key: String, in profile: String, with yaml: String) -> String {
        let normalized = yaml.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = extractSection(key: key, from: profile) {
            return profile.replacingOccurrences(of: existing, with: normalized)
        }
        return profile.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + normalized + "\n"
    }

    private static func defaultSection(key: String) -> String {
        switch key {
        case "rules": "rules:\n  - MATCH,Proxy"
        case "proxies": "proxies:\n  - name: DIRECT\n    type: direct"
        case "proxy-groups": """
        proxy-groups:
          - name: Proxy
            type: select
            proxies:
              - DIRECT
        """
        default: "\(key):"
        }
    }
}
