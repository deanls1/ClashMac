import Foundation
import Darwin

enum CoreUpdateError: LocalizedError {
    case invalidResponse
    case downloadFailed
    case unsupportedArch
    case invalidArtifact(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "无法解析发布信息"
        case .downloadFailed: "内核下载失败"
        case .unsupportedArch: "不支持的 CPU 架构"
        case .invalidArtifact(let detail): detail
        }
    }
}

enum CoreUpdateService {
    private static let repo = "MetaCubeX/mihomo"

    static func coreDirectory() -> URL {
        RuntimeConfigBuilder.appSupportDirectory().appendingPathComponent("Core", isDirectory: true)
    }

    static func manifestURL() -> URL {
        coreDirectory().appendingPathComponent("core-manifest.json")
    }

    static func installedCoreURL() -> URL? {
        let arch = ProcessInfo.processInfo.machineHardwareName
        let names = ["mihomo-darwin-\(arch)", "mihomo"]
        for name in names {
            let url = coreDirectory().appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    static func latestVersion() async throws -> String {
        let release = try await GitHubReleaseClient.fetchLatestRelease(repo: repo)
        let tag = release.tag
        return tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    struct UpdateStatus: Sendable {
        let localVersion: String?
        let remoteVersion: String
        let isInstalled: Bool
        let updateAvailable: Bool
        let installedPath: String?
    }

    static func checkForUpdate(localVersion: String?) async throws -> UpdateStatus {
        let remote = try await latestVersion()
        let installed = installedCoreURL()
        let local = normalizeVersion(localVersion)
            ?? installed.flatMap { CoreLocator.coreVersion(at: $0) }.flatMap(normalizeVersion)
        let remoteNorm = normalizeVersion(remote)
        let updateAvailable: Bool
        if local == nil {
            updateAvailable = true
        } else if let local, let remoteNorm {
            updateAvailable = local != remoteNorm
        } else {
            updateAvailable = false
        }
        return UpdateStatus(
            localVersion: local,
            remoteVersion: remote,
            isInstalled: installed != nil,
            updateAvailable: updateAvailable,
            installedPath: installed?.path
        )
    }

    private static func normalizeVersion(_ raw: String?) -> String? {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        if text.hasPrefix("v") { text.removeFirst() }
        return text
    }

    static func downloadAndInstall() async throws -> URL {
        let arch = ProcessInfo.processInfo.machineHardwareName
        guard arch == "arm64" || arch == "x86_64" else { throw CoreUpdateError.unsupportedArch }

        let release = try await GitHubReleaseClient.fetchLatestRelease(repo: repo)
        let prefix = arch == "arm64" ? "mihomo-darwin-arm64" : "mihomo-darwin-amd64"
        guard let asset = release.assets.first(where: { $0.name.hasPrefix(prefix) && $0.name.hasSuffix(".gz") }) else {
            throw CoreUpdateError.downloadFailed
        }

        let data = try await GitHubReleaseClient.downloadAsset(asset)
        do {
            try DownloadValidator.validateGzip(data)
        } catch {
            throw CoreUpdateError.invalidArtifact(error.localizedDescription)
        }

        let decompressed = try gunzip(data)
        do {
            try DownloadValidator.validateMachOExecutable(decompressed)
        } catch {
            throw CoreUpdateError.invalidArtifact(error.localizedDescription)
        }

        let sha256 = DownloadValidator.sha256Hex(of: decompressed)
        let dir = coreDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("mihomo-darwin-\(arch)")
        try decompressed.write(to: dest, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest.path)

        let manifest: [String: Any] = [
            "releaseTag": release.tag,
            "assetName": asset.name,
            "sha256": sha256,
            "size": decompressed.count,
            "installedAt": ISO8601DateFormatter().string(from: .now)
        ]
        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try manifestData.write(to: manifestURL(), options: .atomic)

        return dest
    }

    private static func gunzip(_ data: Data) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
        process.arguments = ["-c"]

        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        try process.run()
        input.fileHandleForWriting.write(data)
        try input.fileHandleForWriting.close()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { throw CoreUpdateError.downloadFailed }
        return output.fileHandleForReading.readDataToEndOfFile()
    }
}

private extension ProcessInfo {
    var machineHardwareName: String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        let bytes = machine.map { UInt8(bitPattern: $0) }.prefix(while: { $0 != 0 })
        return String(decoding: bytes, as: UTF8.self)
    }
}
