import Foundation

struct WebsiteTestItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let symbol: String
    let url: URL
    var delayMs: Int?
    var isTesting = false

    static let defaults: [WebsiteTestItem] = [
        WebsiteTestItem(id: "apple", name: "Apple", symbol: "apple.logo", url: URL(string: "https://www.apple.com")!),
        WebsiteTestItem(id: "google", name: "Google", symbol: "globe", url: URL(string: "https://www.google.com/generate_204")!),
        WebsiteTestItem(id: "github", name: "GitHub", symbol: "chevron.left.forwardslash.chevron.right", url: URL(string: "https://github.com")!),
        WebsiteTestItem(id: "youtube", name: "YouTube", symbol: "play.rectangle.fill", url: URL(string: "https://www.youtube.com")!),
    ]
}

enum WebsiteLatencyService {
    static func measure(url: URL, proxyPort: Int?) async -> Int? {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 8
        config.waitsForConnectivity = false
        if let proxyPort {
            config.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable as String: 1,
                kCFNetworkProxiesHTTPSEnable as String: 1,
                kCFNetworkProxiesHTTPProxy as String: "127.0.0.1",
                kCFNetworkProxiesHTTPSProxy as String: "127.0.0.1",
                kCFNetworkProxiesHTTPPort as String: proxyPort,
                kCFNetworkProxiesHTTPSPort as String: proxyPort,
            ]
        }
        let session = URLSession(configuration: config)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("ClashMac/1.0", forHTTPHeaderField: "User-Agent")
        let start = Date()
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else {
                return nil
            }
            return max(Int(Date().timeIntervalSince(start) * 1000), 1)
        } catch {
            return nil
        }
    }
}
