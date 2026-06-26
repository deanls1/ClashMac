import Foundation

enum ConfigBackupService {
    enum BackupError: LocalizedError {
        case archiveFailed

        var errorDescription: String? {
            switch self {
            case .archiveFailed: "备份创建失败"
            }
        }
    }

    static func backupDirectory() -> URL {
        RuntimeConfigBuilder.appSupportDirectory().appendingPathComponent("backups", isDirectory: true)
    }

    static func createBackup() throws -> URL {
        let source = RuntimeConfigBuilder.appSupportDirectory()
        let destDir = backupDirectory()
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        let dest = destDir.appendingPathComponent("clashmac-backup-\(stamp).zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", dest.path, "."]
        process.currentDirectoryURL = source
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw BackupError.archiveFailed }
        return dest
    }

    static func listBackups() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: backupDirectory(), includingPropertiesForKeys: [.creationDateKey]))?
            .filter { $0.pathExtension == "zip" }
            .sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) } ?? []
    }
}

private extension URL {
    var creationDate: Date? {
        try? resourceValues(forKeys: [.creationDateKey]).creationDate
    }
}

enum DiagnosticExporter {
    @MainActor
    static func export(store: AppStore) -> URL {
        let profilesSummary = store.profiles.map { profile in
            [
                "name": profile.name,
                "isActive": profile.id == store.activeProfile?.id,
                "hasSubscription": profile.subscriptionURL != nil,
                "subscriptionHost": profile.subscriptionURL.flatMap { URL(string: $0)?.host }.map(SensitiveDataRedactor.redactURL) ?? "local"
            ] as [String: Any]
        }

        let payload: [String: Any] = [
            "app": "Clash Mac",
            "timestamp": ISO8601DateFormatter().string(from: .now),
            "coreState": store.coreState.statusText,
            "version": store.version,
            "corePath": store.corePath,
            "tunEnabled": store.tunEnabled,
            "systemProxy": store.systemProxyEnabled,
            "proxyGuard": store.proxyGuardEnabled,
            "helperStatus": store.helperStatus,
            "enableExternalController": store.enableExternalController,
            "controllerUnixPath": MihomoIPCPath.socketPath(),
            "activeProfile": store.activeProfile?.name ?? "none",
            "profileCount": store.profiles.count,
            "profiles": profilesSummary,
            "connectionCount": store.connections.count,
            "secret": "<redacted>"
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        let redacted = SensitiveDataRedactor.redact(String(data: data, encoding: .utf8) ?? "")
        let url = RuntimeConfigBuilder.appSupportDirectory().appendingPathComponent("diagnostic.json")
        try? redacted.data(using: .utf8)?.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return url
    }
}
