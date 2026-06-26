import Foundation

/// Mihomo Unix Socket 路径（对齐 Verge Rev 的 external-controller-unix）。
enum MihomoIPCPath {
    static func directory() -> URL {
        RuntimeConfigBuilder.appSupportDirectory().appendingPathComponent("ipc", isDirectory: true)
    }

    static func socketURL() -> URL {
        directory().appendingPathComponent("clashmac-mihomo.sock")
    }

    static func socketPath() -> String {
        socketURL().path
    }

    static func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory(), withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory().path)
    }

    static func removeStaleSocketIfNeeded() {
        let path = socketPath()
        guard FileManager.default.fileExists(atPath: path) else { return }
        try? FileManager.default.removeItem(atPath: path)
    }
}
