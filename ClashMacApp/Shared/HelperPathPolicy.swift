import Foundation
import Darwin

/// Helper 仅允许启动 Clash Mac 管理目录下的内核与配置。
/// 采用「realpath 解析 + 锚定合法主目录前缀」双重校验：
/// - realpath 会解析符号链接与 `..`，杜绝把 `Core/mihomo` 软链到 `/bin/sh` 之类的提权；
/// - 锚定前缀要求路径真实位于 `/Users/<用户>/Library/Application Support/ClashMac`（或旧版 LiteClash）下，
///   而不是任意包含该子串的伪造路径（如 `/tmp/x/Library/Application Support/ClashMac/...`）。
enum HelperPathPolicy {
    private static let appSupportMarker = "/Library/Application Support/ClashMac"
    private static let legacySupportMarker = "/Library/Application Support/LiteClash"

    static func isAllowedCorePath(_ path: String) -> Bool {
        // 内核必须真实存在，realpath 才能解析其真身；不存在或含符号链接逃逸即拒绝。
        guard let resolved = realResolvedPath(path) else { return false }
        let name = URL(fileURLWithPath: resolved).lastPathComponent
        guard name.hasPrefix("mihomo") else { return false }
        if let base = anchoredAppSupportBase(of: resolved), resolved.hasPrefix(base + "/Core/") {
            return true
        }
        return isBundledCorePath(resolved)
    }

    static func isAllowedConfigPath(_ path: String) -> Bool {
        guard let resolved = realResolvedPath(path) else { return false }
        guard resolved.hasSuffix(".yaml") || resolved.hasSuffix(".yml") else { return false }
        guard let base = anchoredAppSupportBase(of: resolved) else { return false }
        return resolved.hasPrefix(base + "/")
    }

    static func isAllowedWorkDirectory(_ path: String) -> Bool {
        // work 目录可能尚未创建，realpath 会失败；改为解析其真实父目录后再拼接校验，
        // 既能防父目录被软链逃逸，又不因目录未建而误拒。
        let std = URL(fileURLWithPath: path).standardized
        guard let parentReal = realResolvedPath(std.deletingLastPathComponent().path) else { return false }
        let resolved = parentReal + "/" + std.lastPathComponent
        guard let base = anchoredAppSupportBase(of: resolved) else { return false }
        return resolved.hasPrefix(base + "/") && resolved.contains("/work")
    }

    // MARK: - Helpers

    /// realpath(3) 解析（要求路径存在）；失败返回 nil。
    private static func realResolvedPath(_ path: String) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard realpath(path, &buffer) != nil else { return nil }
        return String(cString: buffer)
    }

    /// 若 path 锚定在「合法用户主目录 + App Support/ClashMac」之下，返回该 base 目录字符串，否则 nil。
    /// 关键：marker 之前的前缀必须是真实的单级用户主目录，且 marker 后处于路径边界（`/` 或结尾）。
    private static func anchoredAppSupportBase(of path: String) -> String? {
        for marker in [appSupportMarker, legacySupportMarker] {
            guard let range = path.range(of: marker) else { continue }
            let prefix = String(path[..<range.lowerBound])
            guard isValidHomePrefix(prefix) else { continue }
            let after = path[range.upperBound...]
            guard after.isEmpty || after.hasPrefix("/") else { continue }
            return prefix + marker
        }
        return nil
    }

    /// 主目录必须是 `/Users/<单级名>`（或 realpath 后的 `/var/root` / `/private/var/root`），
    /// 杜绝 `/tmp/x`、`/Users/a/b` 等多级伪造前缀绕过。
    private static func isValidHomePrefix(_ prefix: String) -> Bool {
        if prefix == "/var/root" || prefix == "/private/var/root" { return true }
        let comps = prefix.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        return comps.count == 2 && comps[0] == "Users"
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
