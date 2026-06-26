import Foundation

enum ProfileRulesEditor {
    static func loadRulesYAML(from profile: Profile) throws -> String {
        let profileText = try String(contentsOf: profile.fileURL, encoding: .utf8)
        return extractRulesSection(from: profileText) ?? "rules:\n  - MATCH,Proxy\n"
    }

    static func saveRulesYAML(_ rulesYAML: String, to profile: Profile) throws {
        var profileText = try String(contentsOf: profile.fileURL, encoding: .utf8)
        profileText = replaceRulesSection(in: profileText, with: rulesYAML)
        try profileText.write(to: profile.fileURL, atomically: true, encoding: .utf8)
    }

    static func extractRulesSection(from profile: String) -> String? {
        let lines = profile.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "rules:" }) else {
            return nil
        }
        var end = start + 1
        while end < lines.count {
            let line = lines[end]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !line.hasPrefix(" ") && !line.hasPrefix("-") && trimmed.contains(":") {
                break
            }
            end += 1
        }
        return lines[start..<end].joined(separator: "\n")
    }

    private static func replaceRulesSection(in profile: String, with rulesYAML: String) -> String {
        let normalized = rulesYAML.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = extractRulesSection(from: profile) {
            return profile.replacingOccurrences(of: existing, with: normalized)
        }
        return profile.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + normalized + "\n"
    }

    /// 在 rules 段首行插入一条规则（MATCH 之前）。
    static func appendRule(to profile: Profile, type: RuleAddType, payload: String, proxy: String) throws {
        var profileText = try String(contentsOf: profile.fileURL, encoding: .utf8)
        let ruleLine = payload.isEmpty ? "  - \(type.rawValue),\(proxy)" : "  - \(type.rawValue),\(payload),\(proxy)"
        if var section = extractRulesSection(from: profileText) {
            let lines = section.components(separatedBy: .newlines)
            var insertIndex = 1
            for (idx, line) in lines.enumerated() where line.contains("MATCH") {
                insertIndex = idx
                break
            }
            var mutable = lines
            mutable.insert(ruleLine, at: insertIndex)
            section = mutable.joined(separator: "\n")
            profileText = replaceRulesSection(in: profileText, with: section)
        } else {
            profileText += "\nrules:\n\(ruleLine)\n  - MATCH,\(proxy)\n"
        }
        try profileText.write(to: profile.fileURL, atomically: true, encoding: .utf8)
    }
}
