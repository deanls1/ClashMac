import Foundation
import Darwin

/// 安装 Helper 时记录当前用户 GID（对齐 Verge Service 的 CLASH_VERGE_SERVICE_GID 绑定思路）。
enum HelperTrustStore {
    private static let fileName = "helper-trusted-gid"

    static func securityDirectory(forAppSupportBase base: URL) -> URL {
        base.appendingPathComponent("security", isDirectory: true)
    }

    static func trustedGIDFile(inAppSupport base: URL) -> URL {
        securityDirectory(forAppSupportBase: base).appendingPathComponent(fileName)
    }

    static func defaultAppSupportDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ClashMac", isDirectory: true)
    }

    static func recordCurrentUser() throws {
        let base = defaultAppSupportDirectory()
        let dir = securityDirectory(forAppSupportBase: base)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = trustedGIDFile(inAppSupport: base)
        try "\(getgid())".write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    static func trustedGID(matchingConfigPath configPath: String) -> gid_t? {
        guard let base = appSupportBaseURL(fromConfigPath: configPath) else { return nil }
        let file = trustedGIDFile(inAppSupport: base)
        guard let text = try? String(contentsOf: file, encoding: .utf8),
              let gid = gid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return gid
    }

    static func appSupportBaseURL(fromConfigPath path: String) -> URL? {
        let marker = "/Library/Application Support/ClashMac"
        let legacy = "/Library/Application Support/LiteClash"
        guard let range = path.range(of: marker) ?? path.range(of: legacy) else { return nil }
        let homePrefix = String(path[..<range.lowerBound])
        guard !homePrefix.isEmpty else { return nil }
        return URL(fileURLWithPath: homePrefix).appendingPathComponent("Library/Application Support/ClashMac")
    }
}
