import Foundation

enum GeoDataUpdateError: LocalizedError {
    case downloadFailed(String)
    case invalidArtifact(String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let name): "\(name) 下载失败"
        case .invalidArtifact(let name): "\(name) 文件校验失败"
        }
    }
}

enum GeoDataUpdateService {
    private static let repo = "MetaCubeX/meta-rules-dat"
    private static let minFileSize = 64 * 1024
    private static let files = ["geoip.metadb", "geosite.dat", "country.mmdb"]

    struct FileInfo: Sendable {
        let name: String
        let exists: Bool
        let bytes: Int?
    }

    struct UpdateStatus: Sendable {
        let remoteRelease: String
        let localRelease: String?
        let files: [FileInfo]
        let missingFiles: [String]
        let isComplete: Bool
    }

    static func geoDirectory() -> URL {
        RuntimeConfigBuilder.workDirectory()
    }

    static func manifestURL() -> URL {
        geoDirectory().appendingPathComponent("geo-manifest.json")
    }

    static func fileStatus() -> [(name: String, exists: Bool)] {
        files.map { name in
            (name, FileManager.default.fileExists(atPath: geoDirectory().appendingPathComponent(name).path))
        }
    }

    static func localReleaseTag() -> String? {
        guard let data = try? Data(contentsOf: manifestURL()),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["releaseTag"] as? String else { return nil }
        return tag
    }

    static func checkStatus() async throws -> UpdateStatus {
        let release = try await GitHubReleaseClient.fetchLatestRelease(repo: repo)
        let remote = release.tag
        let local = localReleaseTag()
        let infos: [FileInfo] = files.map { name in
            let url = geoDirectory().appendingPathComponent(name)
            let exists = FileManager.default.fileExists(atPath: url.path)
            let bytes = exists ? (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) : nil
            return FileInfo(name: name, exists: exists, bytes: bytes)
        }
        let missing = infos.filter { !$0.exists }.map(\.name)
        return UpdateStatus(
            remoteRelease: remote,
            localRelease: local,
            files: infos,
            missingFiles: missing,
            isComplete: missing.isEmpty
        )
    }

    static func downloadAll(onProgress: (@Sendable (Double, String) -> Void)? = nil) async throws {
        try FileManager.default.createDirectory(at: geoDirectory(), withIntermediateDirectories: true)
        onProgress?(0.02, "正在获取 GeoData 发布信息…")
        let release = try await GitHubReleaseClient.fetchLatestRelease(repo: repo)
        var manifest: [String: Any] = [
            "releaseTag": release.tag,
            "updatedAt": ISO8601DateFormatter().string(from: .now)
        ]
        var fileEntries: [[String: Any]] = []
        let total = Double(files.count)

        for (index, name) in files.enumerated() {
            let base = 0.08 + (Double(index) / total) * 0.84
            onProgress?(base, "正在下载 \(name)…")
            guard let asset = release.assets.first(where: { $0.name == name }) else {
                throw GeoDataUpdateError.downloadFailed(name)
            }
            let data = try await GitHubReleaseClient.downloadAsset(asset) { fraction in
                let progress = base + (fraction / total) * 0.84
                onProgress?(min(progress, 0.95), "正在下载 \(name)… \(Int(fraction * 100))%")
            }
            guard data.count >= minFileSize else {
                throw GeoDataUpdateError.invalidArtifact(name)
            }
            let sha256 = DownloadValidator.sha256Hex(of: data)
            let dest = geoDirectory().appendingPathComponent(name)
            try data.write(to: dest, options: .atomic)
            fileEntries.append([
                "name": name,
                "size": data.count,
                "sha256": sha256
            ])
        }

        onProgress?(0.96, "正在写入清单…")
        manifest["files"] = fileEntries
        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try manifestData.write(to: manifestURL(), options: .atomic)
        onProgress?(1, "GeoData 安装完成")
    }
}
