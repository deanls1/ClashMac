import Foundation
import Security

/// 控制 API 密钥存 Keychain，避免明文落在 UserDefaults（参考 Verge 对 secret 的隔离思路）。
enum ControllerSecretStore {
    private static let service = "com.clashmac.app.controller"
    private static let account = "external-controller-secret"
    private static let legacyDefaultsKey = "controllerSecret"

    static func loadOrCreate() -> String {
        if let existing = load(), !existing.isEmpty {
            return existing
        }
        if let legacy = UserDefaults.standard.string(forKey: legacyDefaultsKey), !legacy.isEmpty {
            save(legacy)
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
            return legacy
        }
        let secret = UUID().uuidString
        save(secret)
        return secret
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func save(_ secret: String) {
        let data = Data(secret.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query.merging(attrs) { $1 } as CFDictionary, nil)
        if status == errSecDuplicateItem {
            SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        }
    }
}
