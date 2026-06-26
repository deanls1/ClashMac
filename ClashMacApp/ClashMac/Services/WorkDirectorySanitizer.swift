import Foundation

/// 修复 work 目录中 Helper（root）遗留的不可写文件，避免用户模式启动失败。
enum WorkDirectorySanitizer {
    static func prepareForUserCore(in workDirectory: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: workDirectory.path) else { return }

        let staleNames = ["cache.db", "cache.db-shm", "cache.db-wal"]
        for name in staleNames {
            let url = workDirectory.appendingPathComponent(name)
            guard fm.fileExists(atPath: url.path) else { continue }
            if !fm.isWritableFile(atPath: url.path) {
                try? fm.removeItem(at: url)
            }
        }
    }
}
