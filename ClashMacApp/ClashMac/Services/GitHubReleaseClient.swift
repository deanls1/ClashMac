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
        case invalidResponse(status: Int?, detail: String)
        case assetNotFound(String)
        case timedOut
        case network(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse(let status, let detail):
                if let status { return "GitHub 响应异常（HTTP \(status)）：\(detail)" }
                return "GitHub 响应异常：\(detail)"
            case .assetNotFound(let name): return "发布中未找到 \(name)"
            case .timedOut: return "连接 GitHub 超时，请检查网络或稍后重试"
            case .network(let detail): return "网络错误：\(detail)"
            }
        }
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 900
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        // 下载内核/GeoData 必须直连 GitHub，避免被本机系统代理劫持导致 SSL bad MAC
        config.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable as String: 0,
            kCFNetworkProxiesHTTPSEnable as String: 0,
            kCFNetworkProxiesProxyAutoConfigEnable as String: 0,
            kCFNetworkProxiesSOCKSEnable as String: 0,
        ]
        return URLSession(configuration: config)
    }()

    static func fetchLatestRelease(repo: String) async throws -> ReleaseInfo {
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("ClashMac/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw ClientError.timedOut
        } catch let error as URLError where isTLSError(error) {
            throw ClientError.network("TLS 握手失败（若已开系统代理，请先停止代理或关闭系统代理后再下载）")
        } catch {
            throw ClientError.network(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode
        guard status == 200 else {
            throw ClientError.invalidResponse(status: status, detail: "无法获取发布信息")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let assetsJSON = json["assets"] as? [[String: Any]] else {
            throw ClientError.invalidResponse(status: status, detail: "无法解析发布信息")
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

    static func downloadAsset(
        _ asset: ReleaseAsset,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> Data {
        var request = URLRequest(url: asset.downloadURL)
        request.setValue("ClashMac/1.0", forHTTPHeaderField: "User-Agent")
        onProgress?(0.05)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw ClientError.timedOut
        } catch let error as URLError where isTLSError(error) {
            throw ClientError.network("TLS 握手失败（若已开系统代理，请先停止代理或关闭系统代理后再下载）")
        } catch {
            throw ClientError.network(error.localizedDescription)
        }
        onProgress?(0.95)

        let status = (response as? HTTPURLResponse)?.statusCode
        guard status == 200 else {
            throw ClientError.invalidResponse(status: status, detail: "下载 \(asset.name) 失败")
        }
        if asset.size > 0, data.count != asset.size {
            throw ClientError.invalidResponse(
                status: status,
                detail: "文件大小不匹配（期望 \(asset.size)，实际 \(data.count)）"
            )
        }
        onProgress?(1)
        return data
    }

    private static func isTLSError(_ error: URLError) -> Bool {
        switch error.code {
        case .secureConnectionFailed,
             .serverCertificateUntrusted,
             .clientCertificateRejected,
             .clientCertificateRequired,
             .cannotLoadFromNetwork,
             .networkConnectionLost,
             .cannotConnectToHost:
            return true
        default:
            return false
        }
    }
}
