import Foundation

/// 修复 work 目录中 Helper（root）遗留的不可写文件，避免用户模式启动失败。
/// 同时尽量保留 mihomo 的 store-selected 选择缓存（cache.db），让节点选择跨重启持久化。
enum WorkDirectorySanitizer {
    static func prepareForUserCore(in workDirectory: URL) {
        let fm = FileManager.default
        try? fm.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        // 仅当 cache.db 因被 root 持有而当前用户不可写时才清理（否则用户态内核会启动失败）；
        // 用户自有的缓存予以保留，以持久化节点选择。
        clearCacheFilesIfUnwritable(in: workDirectory)
    }

    static func prepareForPrivilegedCore(in workDirectory: URL) {
        // root 可读写任意属主文件，无需清理缓存；保留 store-selected 选择，使 TUN 重启后选择不丢失。
    }

    private static func clearCacheFilesIfUnwritable(in workDirectory: URL) {
        let fm = FileManager.default
        let cache = workDirectory.appendingPathComponent("cache.db")
        guard fm.fileExists(atPath: cache.path) else { return }
        // 当前用户可写说明是用户自有缓存，保留以维持节点选择持久化。
        if fm.isWritableFile(atPath: cache.path) { return }
        for name in ["cache.db", "cache.db-shm", "cache.db-wal", "cache.db.bak.root"] {
            let url = workDirectory.appendingPathComponent(name)
            guard fm.fileExists(atPath: url.path) else { continue }
            try? fm.removeItem(at: url)
        }
    }
}
