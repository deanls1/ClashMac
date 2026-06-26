import Foundation

struct FilterOptions: Equatable, Sendable {
    var caseSensitive = false
    var wholeWord = false
    var useRegex = false

    func matches(_ text: String, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let haystack = caseSensitive ? text : text.lowercased()
        let needle = caseSensitive ? trimmed : trimmed.lowercased()

        if useRegex {
            guard let regex = try? NSRegularExpression(pattern: needle) else { return false }
            let range = NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)
            return regex.firstMatch(in: haystack, range: range) != nil
        }

        if wholeWord {
            return haystack.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).contains(needle)
        }

        return haystack.contains(needle)
    }
}

enum LogsDisplayFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case info
    case warning
    case error
    case debug

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "ALL"
        case .info: "Info"
        case .warning: "Warning"
        case .error: "Error"
        case .debug: "Debug"
        }
    }

    func matches(_ level: LogLevel) -> Bool {
        switch self {
        case .all: true
        case .info: level == .info
        case .warning: level == .warning
        case .error: level == .error
        case .debug: level == .debug
        }
    }
}

enum ConnectionTab: String, CaseIterable, Identifiable, Sendable {
    case active
    case closed

    var id: String { rawValue }
    var label: String {
        switch self {
        case .active: "活跃"
        case .closed: "已关闭"
        }
    }
}

struct TrafficSample: Identifiable, Equatable, Sendable {
    let id: UUID
    let upload: Int
    let download: Int
    let timestamp: Date

    init(upload: Int, download: Int, timestamp: Date = .now) {
        self.id = UUID()
        self.upload = upload
        self.download = download
        self.timestamp = timestamp
    }
}

struct TrafficTotals: Equatable, Sendable {
    var uploadBytes: Int64 = 0
    var downloadBytes: Int64 = 0

    var uploadFormatted: String { ByteCountFormatter.shortString(Int(uploadBytes)) }
    var downloadFormatted: String { ByteCountFormatter.shortString(Int(downloadBytes)) }
}

enum RuleAddType: String, CaseIterable, Identifiable, Sendable {
    case domainSuffix = "DOMAIN-SUFFIX"
    case domain = "DOMAIN"
    case processName = "PROCESS-NAME"
    case ipCIDR = "IP-CIDR"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .domainSuffix: "域名后缀"
        case .domain: "完整域名"
        case .processName: "进程名"
        case .ipCIDR: "IP 段"
        }
    }
}