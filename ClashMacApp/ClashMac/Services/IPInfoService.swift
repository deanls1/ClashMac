import CFNetwork
import Foundation

struct IPInfo: Equatable, Sendable {
    var ip: String
    var countryCode: String?
    var country: String?
    var city: String?
    var region: String?
    var isp: String?
    var latencyMs: Int
    var viaProxy: Bool

    var locationLabel: String {
        [city, region, country]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
    }
}

enum IPInfoService {
    private static let endpoint = URL(string: "https://api.ip.sb/geoip")!

    static func fetch(viaProxyPort: Int?) async -> IPInfo? {
        let start = Date()
        let session = session(viaProxyPort: viaProxyPort)
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 8
        request.setValue("ClashMac/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ip = json["ip"] as? String else {
            return nil
        }

        let latency = max(Int(Date().timeIntervalSince(start) * 1000), 1)
        return IPInfo(
            ip: ip,
            countryCode: json["country_code"] as? String,
            country: json["country"] as? String,
            city: json["city"] as? String,
            region: json["region"] as? String,
            isp: (json["isp"] as? String) ?? (json["organization"] as? String),
            latencyMs: latency,
            viaProxy: viaProxyPort != nil
        )
    }

    static func fetchBoth(proxyPort: Int) async -> (direct: IPInfo?, proxy: IPInfo?) {
        async let direct = fetch(viaProxyPort: nil)
        async let proxy = fetch(viaProxyPort: proxyPort)
        return await (direct, proxy)
    }

    private static func session(viaProxyPort: Int?) -> URLSession {
        guard let port = viaProxyPort else {
            return URLSession.shared
        }
        let config = URLSessionConfiguration.default
        config.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable as String: true,
            kCFNetworkProxiesHTTPProxy as String: "127.0.0.1",
            kCFNetworkProxiesHTTPPort as String: port,
            kCFNetworkProxiesHTTPSEnable as String: true,
            kCFNetworkProxiesHTTPSProxy as String: "127.0.0.1",
            kCFNetworkProxiesHTTPSPort as String: port,
        ]
        config.timeoutIntervalForRequest = 8
        return URLSession(configuration: config)
    }
}

enum StartupCheckService {
    struct Result: Sendable {
        var missingGeoData: [String]
        var coreUpdateAvailable: Bool
        var latestCoreVersion: String?
        var localCoreVersion: String?
    }

    static func check(localCoreVersion: String?) async -> Result {
        let missing = GeoDataUpdateService.fileStatus().filter { !$0.exists }.map(\.name)
        var latest: String?
        var updateAvailable = false
        if let remote = try? await CoreUpdateService.latestVersion() {
            latest = remote
            if let local = normalizeVersion(localCoreVersion), normalizeVersion(remote) != local {
                updateAvailable = true
            }
        }
        return Result(
            missingGeoData: missing,
            coreUpdateAvailable: updateAvailable,
            latestCoreVersion: latest,
            localCoreVersion: localCoreVersion
        )
    }

    private static func normalizeVersion(_ raw: String?) -> String? {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        if text.hasPrefix("v") { text.removeFirst() }
        return text
    }
}

struct StartupBanner: Equatable, Sendable {
    enum Kind: String, Hashable, Sendable { case geoData, coreUpdate }
    let kind: Kind
    let title: String
    let message: String
}
