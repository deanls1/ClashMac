import Foundation

// MARK: - Navigation

enum DashboardSection: String, CaseIterable, Identifiable, Sendable {
    case home
    case proxy
    case subscription
    case connections
    case rules
    case logs
    case unlock
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: "首页"
        case .proxy: "代理"
        case .subscription: "订阅"
        case .connections: "连接"
        case .rules: "规则"
        case .logs: "日志"
        case .unlock: "测试"
        case .settings: "设置"
        }
    }

    var pageTitle: String {
        switch self {
        case .home: "首页"
        case .proxy: "代理组"
        case .subscription: "订阅"
        case .connections: "连接"
        case .rules: "规则"
        case .logs: "日志"
        case .unlock: "解锁测试"
        case .settings: "设置"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .proxy: "server.rack"
        case .subscription: "tray.full.fill"
        case .connections: "arrow.left.arrow.right"
        case .rules: "list.bullet.rectangle"
        case .logs: "doc.text"
        case .unlock: "play.rectangle.on.rectangle"
        case .settings: "gearshape.fill"
        }
    }
}

enum LogLevel: String, CaseIterable, Identifiable, Sendable {
    case info, warning, error, debug

    var id: String { rawValue }

    var label: String {
        switch self {
        case .info: "Info"
        case .warning: "Warning"
        case .error: "Error"
        case .debug: "Debug"
        }
    }
}

enum LogsSource: String, CaseIterable, Identifiable, Sendable {
    case core
    case app

    var id: String { rawValue }

    var label: String {
        switch self {
        case .core: "内核"
        case .app: "应用"
        }
    }
}

// MARK: - Connections

struct ConnectionItem: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let host: String
    let process: String
    let rule: String
    let chain: String
    let upload: Int
    let download: Int
    var uploadSpeed: Int
    var downloadSpeed: Int
    let startedAt: Date
    var closedAt: Date?

    var uploadFormatted: String { ByteCountFormatter.shortString(upload) }
    var downloadFormatted: String { ByteCountFormatter.shortString(download) }
    var uploadSpeedFormatted: String { ByteCountFormatter.rateString(uploadSpeed) }
    var downloadSpeedFormatted: String { ByteCountFormatter.rateString(downloadSpeed) }

    init(
        id: String,
        host: String,
        process: String,
        rule: String,
        chain: String,
        upload: Int,
        download: Int,
        uploadSpeed: Int = 0,
        downloadSpeed: Int = 0,
        startedAt: Date,
        closedAt: Date? = nil
    ) {
        self.id = id
        self.host = host
        self.process = process
        self.rule = rule
        self.chain = chain
        self.upload = upload
        self.download = download
        self.uploadSpeed = uploadSpeed
        self.downloadSpeed = downloadSpeed
        self.startedAt = startedAt
        self.closedAt = closedAt
    }
}

// MARK: - Rules

struct RuleItem: Identifiable, Equatable, Sendable {
    let index: Int
    let type: String
    let payload: String
    let proxy: String
    var isEnabled: Bool
    var hitCount: Int

    var id: Int { index }

    var summary: String {
        if payload.isEmpty { return type }
        return "\(type),\(payload)"
    }
}

// MARK: - Logs

struct LogEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let message: String

    init(level: LogLevel, message: String, timestamp: Date = .now) {
        self.id = UUID()
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}

// MARK: - Unlock

struct ProxyProvider: Identifiable, Equatable, Sendable {
    let name: String
    let vehicleType: String
    let updatedAt: Date?

    var id: String { name }

    var updatedAtLabel: String {
        guard let updatedAt else { return "—" }
        return updatedAt.formatted(date: .abbreviated, time: .shortened)
    }
}

struct UnlockTarget: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let name: String
    let symbol: String
    let testURL: URL
    let successHint: String
    var status: UnlockStatus
    var regionCode: String?
    var lastTestedAt: Date?

    init(
        id: String,
        name: String,
        symbol: String,
        testURL: URL,
        successHint: String,
        status: UnlockStatus = .idle,
        regionCode: String? = nil,
        lastTestedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.testURL = testURL
        self.successHint = successHint
        self.status = status
        self.regionCode = regionCode
        self.lastTestedAt = lastTestedAt
    }
}

enum UnlockStatus: Equatable, Sendable, Codable {
    case idle
    case testing
    case unlocked(String)
    case locked
    case failed(String)

    var label: String {
        switch self {
        case .idle: "未检测"
        case .testing: "检测中…"
        case .unlocked(let detail): "已解锁 · \(detail)"
        case .locked: "未解锁"
        case .failed(let reason): "失败 · \(reason)"
        }
    }

    var isPositive: Bool {
        if case .unlocked = self { return true }
        return false
    }

    var vergeBadgeTitle: String {
        switch self {
        case .idle: "未测试"
        case .testing: "测试中"
        case .unlocked: "支持"
        case .locked: "不支持"
        case .failed: "测试失败"
        }
    }

    enum CodingKeys: CodingKey { case kind, detail }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        let detail = try c.decodeIfPresent(String.self, forKey: .detail)
        switch kind {
        case "idle": self = .idle
        case "testing": self = .testing
        case "unlocked": self = .unlocked(detail ?? "")
        case "locked": self = .locked
        case "failed": self = .failed(detail ?? "")
        default: self = .idle
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .idle: try c.encode("idle", forKey: .kind)
        case .testing: try c.encode("testing", forKey: .kind)
        case .unlocked(let d): try c.encode("unlocked", forKey: .kind); try c.encode(d, forKey: .detail)
        case .locked: try c.encode("locked", forKey: .kind)
        case .failed(let d): try c.encode("failed", forKey: .kind); try c.encode(d, forKey: .detail)
        }
    }
}

// MARK: - Startup

struct StartupBanner: Equatable, Sendable {
    enum Kind: String, Hashable, Sendable {
        case geoData
        case coreUpdate
        case coreMissing
        case helperApproval
    }

    let kind: Kind
    let title: String
    let message: String
}

// MARK: - Formatters

enum ByteCountFormatter {
    static func shortString(_ bytes: Int) -> String {
        if bytes == 0 { return "0 B" }
        let formatter = Foundation.ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.includesUnit = true
        let formatted = formatter.string(fromByteCount: Int64(bytes))
        return formatted.replacingOccurrences(of: "Zero", with: "0")
    }

    static func rateString(_ bytesPerSec: Int) -> String {
        shortString(bytesPerSec) + "/s"
    }
}
