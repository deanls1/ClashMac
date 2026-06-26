import Foundation

enum RunMode: String, CaseIterable, Identifiable, Sendable {
    case rule
    case global
    case direct

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rule: "规则"
        case .global: "全局"
        case .direct: "直连"
        }
    }

    var symbol: String {
        switch self {
        case .rule: "arrow.triangle.branch"
        case .global: "globe.americas.fill"
        case .direct: "bolt.horizontal.fill"
        }
    }
}

enum CoreState: Equatable, Sendable {
    case stopped
    case starting
    case running
    case stopping
    case error(String)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var statusText: String {
        switch self {
        case .stopped: "已停止"
        case .starting: "启动中…"
        case .running: "运行中"
        case .stopping: "停止中…"
        case .error(let message): message
        }
    }
}

struct ProxyNode: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    var delay: Int?
    var isSelected: Bool
    var isAlive: Bool
    var protocolType: String?

    init(
        name: String,
        delay: Int? = nil,
        isSelected: Bool = false,
        isAlive: Bool = true,
        protocolType: String? = nil
    ) {
        self.id = name
        self.name = name
        self.delay = delay
        self.isSelected = isSelected
        self.isAlive = isAlive
        self.protocolType = protocolType
    }
}

struct ProxyGroup: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    var nodes: [ProxyNode]
    var selectedNode: String?

    init(name: String, nodes: [ProxyNode], selectedNode: String? = nil) {
        self.id = name
        self.name = name
        self.nodes = nodes
        self.selectedNode = selectedNode
    }
}

struct TrafficSnapshot: Equatable, Sendable {
    var uploadBytesPerSec: Int
    var downloadBytesPerSec: Int

    static let zero = TrafficSnapshot(uploadBytesPerSec: 0, downloadBytesPerSec: 0)

    var uploadFormatted: String { ByteCountFormatter.rateString(uploadBytesPerSec) }
    var downloadFormatted: String { ByteCountFormatter.rateString(downloadBytesPerSec) }
}
