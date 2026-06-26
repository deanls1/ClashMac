import Foundation

struct Profile: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var fileName: String
    var subscriptionURL: String?
    var updatedAt: Date
    var expiresAt: Date?
    var isActive: Bool

    init(
        id: UUID = UUID(),
        name: String,
        fileName: String,
        subscriptionURL: String? = nil,
        updatedAt: Date = .now,
        expiresAt: Date? = nil,
        isActive: Bool = false
    ) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.subscriptionURL = subscriptionURL
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
        self.isActive = isActive
    }

    var fileURL: URL {
        ProfileStore.profilesDirectory().appendingPathComponent(fileName)
    }
}

enum ProfileStore {
    private static let indexFileName = "profiles.json"

    static func profilesDirectory() -> URL {
        RuntimeConfigBuilder.appSupportDirectory().appendingPathComponent("profiles", isDirectory: true)
    }

    static func indexURL() -> URL {
        RuntimeConfigBuilder.appSupportDirectory().appendingPathComponent(indexFileName)
    }

    static func loadProfiles() throws -> [Profile] {
        try ensureLayout()
        let profiles = try readProfilesFromDisk()
        if profiles.isEmpty {
            return try bootstrapDefaultProfile()
        }
        return profiles
    }

    static func saveProfiles(_ profiles: [Profile]) throws {
        try ensureLayout()
        try writeProfilesToDisk(profiles)
    }

    static func activeProfile(from profiles: [Profile]) -> Profile? {
        profiles.first(where: \.isActive) ?? profiles.first
    }

    static func activateProfile(id: UUID, in profiles: inout [Profile]) {
        for index in profiles.indices {
            profiles[index].isActive = profiles[index].id == id
        }
    }

    static func addLocalProfile(name: String, yamlContent: String) throws -> Profile {
        try ensureLayout()
        var profiles = try readProfilesFromDisk()
        let fileName = "profile-\(UUID().uuidString.prefix(8)).yaml"
        let url = profilesDirectory().appendingPathComponent(fileName)
        try yamlContent.write(to: url, atomically: true, encoding: .utf8)
        for index in profiles.indices { profiles[index].isActive = false }
        let profile = Profile(name: name, fileName: fileName, isActive: true)
        profiles.append(profile)
        try writeProfilesToDisk(profiles)
        return profile
    }

    static func addSubscriptionProfile(name: String, url: String, yamlContent: String) throws -> Profile {
        try ensureLayout()
        var profiles = try readProfilesFromDisk()
        let fileName = "sub-\(UUID().uuidString.prefix(8)).yaml"
        let fileURL = profilesDirectory().appendingPathComponent(fileName)
        try yamlContent.write(to: fileURL, atomically: true, encoding: .utf8)
        for index in profiles.indices { profiles[index].isActive = false }
        let profile = Profile(name: name, fileName: fileName, subscriptionURL: url, isActive: true)
        profiles.append(profile)
        try writeProfilesToDisk(profiles)
        return profile
    }

    static func updateProfileFile(_ profile: Profile, content: String) throws {
        try content.write(to: profile.fileURL, atomically: true, encoding: .utf8)
    }

    static func readProfileYAML(_ profile: Profile) throws -> String {
        try String(contentsOf: profile.fileURL, encoding: .utf8)
    }

    static func deleteProfile(id: UUID) throws {
        var profiles = try loadProfiles()
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let profile = profiles[index]
        try? FileManager.default.removeItem(at: profile.fileURL)
        profiles.remove(at: index)
        if profile.isActive, !profiles.isEmpty {
            profiles[0].isActive = true
        }
        try saveProfiles(profiles)
    }

    static func reorderProfiles(_ profiles: [Profile]) throws {
        try saveProfiles(profiles)
    }

    private static func ensureLayout() throws {
        try FileManager.default.createDirectory(at: profilesDirectory(), withIntermediateDirectories: true)
        try RuntimeConfigBuilder.ensureDirectories()
    }

    private static func bootstrapDefaultProfile() throws -> [Profile] {
        let sample = """
        proxies:
          - name: DIRECT
            type: direct

        proxy-groups:
          - name: Proxy
            type: select
            proxies:
              - DIRECT

        rules:
          - MATCH,Proxy
        """
        let profile = try addLocalProfile(name: "默认配置", yamlContent: sample)
        return [profile]
    }

    private static func readProfilesFromDisk() throws -> [Profile] {
        guard FileManager.default.fileExists(atPath: indexURL().path) else { return [] }
        let data = try Data(contentsOf: indexURL())
        return try JSONDecoder().decode([Profile].self, from: data)
    }

    private static func writeProfilesToDisk(_ profiles: [Profile]) throws {
        let data = try JSONEncoder().encode(profiles)
        try data.write(to: indexURL(), options: .atomic)
    }
}

enum SubscriptionFetcher {
    enum FetchError: LocalizedError {
        case invalidURL
        case insecureURL
        case httpStatus(Int)
        case emptyBody
        case tooLarge

        var errorDescription: String? {
            switch self {
            case .invalidURL: "订阅链接无效"
            case .insecureURL: "订阅链接必须使用 HTTPS"
            case .httpStatus(let code): "订阅下载失败 HTTP \(code)"
            case .emptyBody: "订阅内容为空"
            case .tooLarge: "订阅内容超过大小限制（16MB）"
            }
        }
    }

    private static let maxDownloadBytes = 16 * 1024 * 1024

    static func download(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw FetchError.invalidURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("ClashMac/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FetchError.invalidURL }
        guard (200..<300).contains(http.statusCode) else { throw FetchError.httpStatus(http.statusCode) }
        guard data.count <= maxDownloadBytes else { throw FetchError.tooLarge }
        guard !data.isEmpty else { throw FetchError.emptyBody }
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else {
            throw FetchError.insecureURL
        }
        guard let text = decodeSubscriptionBody(data: data), !text.isEmpty else {
            throw FetchError.emptyBody
        }
        return text
    }

    private static func decodeSubscriptionBody(data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8), text.contains("proxies:") || text.contains("proxy-groups:") {
            return text
        }
        if let text = String(data: data, encoding: .utf8),
           let decoded = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
           let yaml = String(data: decoded, encoding: .utf8) {
            return yaml
        }
        if let yaml = String(data: data, encoding: .utf8) {
            return yaml
        }
        return nil
    }
}
