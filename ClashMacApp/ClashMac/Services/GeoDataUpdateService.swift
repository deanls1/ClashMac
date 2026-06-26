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

    static func downloadAll() async throws {
        try FileManager.default.createDirectory(at: geoDirectory(), withIntermediateDirectories: true)
        let release = try await GitHubReleaseClient.fetchLatestRelease(repo: repo)
        var manifest: [String: Any] = [
            "releaseTag": release.tag,
            "updatedAt": ISO8601DateFormatter().string(from: .now)
        ]
        var fileEntries: [[String: Any]] = []

        for name in files {
            guard let asset = release.assets.first(where: { $0.name == name }) else {
                throw GeoDataUpdateError.downloadFailed(name)
            }
            let data = try await GitHubReleaseClient.downloadAsset(asset)
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

        manifest["files"] = fileEntries
        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try manifestData.write(to: manifestURL(), options: .atomic)
    }
}
