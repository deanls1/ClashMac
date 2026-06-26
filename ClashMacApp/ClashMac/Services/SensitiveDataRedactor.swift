import Foundation

enum SensitiveDataRedactor {
    private static let secretPatterns: [NSRegularExpression] = {
        let patterns = [
            #"secret:\s*[\"']?[^\"'\n]+[\"']?"#,
            #"Authorization:\s*Bearer\s+\S+"#,
            #"CLASHMAC_SECRET=\"[^\"]+\""#,
            #"\"secret\"\s*:\s*\"[^\"]+\""#,
            #"password:\s*[\"']?[^\"'\n]+[\"']?"#,
            #"uuid:\s*[0-9a-fA-F-]{36}"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
    }()

    static func redact(_ text: String) -> String {
        var result = text
        for regex in secretPatterns {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "<redacted>")
        }
        return result
    }

    static func redactURL(_ url: String) -> String {
        guard var components = URLComponents(string: url) else { return "<redacted-url>" }
        if let items = components.queryItems {
            components.queryItems = items.map { item in
                let sensitive = ["token", "secret", "key", "password", "access_token"]
                if sensitive.contains(where: { item.name.lowercased().contains($0) }) {
                    return URLQueryItem(name: item.name, value: "<redacted>")
                }
                return item
            }
        }
        return components.string ?? "<redacted-url>"
    }
}
