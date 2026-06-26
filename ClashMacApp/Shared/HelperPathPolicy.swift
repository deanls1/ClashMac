import Foundation

/// Helper 仅允许启动 Clash Mac 管理目录下的内核与配置（收紧原先过宽的白名单）。
enum HelperPathPolicy {
    private static let appSupportMarker = "/Library/Application Support/ClashMac"
    private static let legacySupportMarker = "/Library/Application Support/LiteClash"

    static func isAllowedCorePath(_ path: String) -> Bool {
        guard isSafeAbsolutePath(path) else { return false }
        let standardized = URL(fileURLWithPath: path).standardized.path

        if standardized.contains(appSupportMarker + "/Core/") {
            let name = URL(fileURLWithPath: standardized).lastPathComponent
            return name.hasPrefix("mihomo")
        }

        if isBundledCorePath(standardized) {
            return true
        }

        return false
    }

    static func isAllowedConfigPath(_ path: String) -> Bool {
        guard isSafeAbsolutePath(path) else { return false }
        let standardized = URL(fileURLWithPath: path).standardized.path
        guard standardized.hasSuffix(".yaml") || standardized.hasSuffix(".yml") else { return false }
        return isUnderAppSupport(standardized)
    }

    static func isAllowedWorkDirectory(_ path: String) -> Bool {
        guard isSafeAbsolutePath(path) else { return false }
        let standardized = URL(fileURLWithPath: path).standardized.path
        guard isUnderAppSupport(standardized) else { return false }
        return standardized.contains("/work")
    }

    private static func isSafeAbsolutePath(_ path: String) -> Bool {
        let standardized = URL(fileURLWithPath: path).standardized.path
        guard standardized.hasPrefix("/") else { return false }
        guard !standardized.contains("/../") else { return false }
        return true
    }

    private static func isUnderAppSupport(_ path: String) -> Bool {
        path.contains(appSupportMarker) || path.contains(legacySupportMarker)
    }

    private static func isBundledCorePath(_ path: String) -> Bool {
        guard path.contains("/Contents/Resources/Core/") else { return false }
        #if DEBUG
        let appMarkers = ["Clash Mac.app/", "ClashMac.app/"]
        guard appMarkers.contains(where: { path.contains($0) }) || path.contains("/DerivedData/") else {
            return false
        }
        #else
        guard path.contains("Clash Mac.app/") || path.contains("ClashMac.app/") else { return false }
        #endif
        let name = URL(fileURLWithPath: path).lastPathComponent
        return name.hasPrefix("mihomo")
    }
}
