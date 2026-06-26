import Foundation

enum GitHubReleaseClient {
    struct ReleaseAsset {
        let name: String
        let downloadURL: URL
        let size: Int
    }

    struct ReleaseInfo {
        let tag: String
        let assets: [ReleaseAsset]
    }

    enum ClientError: LocalizedError {
        case invalidResponse
        case assetNotFound(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "无法解析 GitHub 发布信息"
            case .assetNotFound(let name): "发布中未找到 \(name)"
            }
        }
    }

    static func fetchLatestRelease(repo: String) async throws -> ReleaseInfo {
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("ClashMac/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ClientError.invalidResponse
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let assetsJSON = json["assets"] as? [[String: Any]] else {
            throw ClientError.invalidResponse
        }
        let assets = assetsJSON.compactMap { item -> ReleaseAsset? in
            guard let name = item["name"] as? String,
                  let urlString = item["browser_download_url"] as? String,
                  let url = URL(string: urlString) else { return nil }
            let size = item["size"] as? Int ?? 0
            return ReleaseAsset(name: name, downloadURL: url, size: size)
        }
        return ReleaseInfo(tag: tag, assets: assets)
    }

    static func downloadAsset(_ asset: ReleaseAsset) async throws -> Data {
        var request = URLRequest(url: asset.downloadURL)
        request.setValue("ClashMac/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ClientError.invalidResponse
        }
        if asset.size > 0, data.count != asset.size {
            throw ClientError.invalidResponse
        }
        return data
    }
}
