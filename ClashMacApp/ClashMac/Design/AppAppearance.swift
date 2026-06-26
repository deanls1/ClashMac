import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum ProxyGroupSortKey: String, CaseIterable, Identifiable, Sendable {
    case defaultOrder
    case name
    case latency

    var id: String { rawValue }

    var label: String {
        switch self {
        case .defaultOrder: "默认顺序"
        case .name: "名称"
        case .latency: "延迟"
        }
    }
}

enum ConnectionSortKey: String, CaseIterable, Identifiable, Sendable {
    case downloadSpeed
    case uploadSpeed
    case download
    case upload
    case host

    var id: String { rawValue }

    var label: String {
        switch self {
        case .downloadSpeed: "下载速度"
        case .uploadSpeed: "上传速度"
        case .download: "下载量"
        case .upload: "上传量"
        case .host: "主机"
        }
    }
}

extension DashboardSection {
    @MainActor
    func badgeCount(from store: AppStore) -> Int? {
        switch self {
        case .connections where store.coreState.isRunning:
            let count = store.connections.count
            return count > 0 ? count : nil
        case .subscription:
            return store.profiles.count > 0 ? store.profiles.count : nil
        case .rules where !store.rules.isEmpty:
            return store.rules.count
        case .logs where !store.logEntries.isEmpty:
            return min(store.logEntries.count, 99)
        default:
            return nil
        }
    }
}
