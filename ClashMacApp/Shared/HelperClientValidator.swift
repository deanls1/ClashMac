import Foundation
import Security

/// 校验 XPC 客户端是否为已签名的 Clash Mac 主程序（参考 Verge Service 的调用方限制思路）。
enum HelperClientValidator {
    static let allowedBundleIDs: Set<String> = ["com.clashmac.app"]

    static func validateSignature(_ connection: NSXPCConnection) -> Bool {
        let pid = connection.processIdentifier
        guard pid > 0 else { return false }

        var code: SecCode?
        let attrs = [kSecGuestAttributePid as String: pid] as CFDictionary
        guard SecCodeCopyGuestWithAttributes(nil, attrs, [], &code) == errSecSuccess,
              let code else { return false }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
              let staticCode else { return false }

        let validity = SecStaticCodeCheckValidity(staticCode, [], nil)
        #if DEBUG
        guard validity == errSecSuccess || validity == errSecCSUnsigned else { return false }
        #else
        guard validity == errSecSuccess else { return false }
        #endif

        var cfInfo: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &cfInfo) == errSecSuccess,
              let info = cfInfo as? [String: Any] else { return false }

        if let identifier = info[kSecCodeInfoIdentifier as String] as? String,
           allowedBundleIDs.contains(identifier) {
            return true
        }

        #if DEBUG
        if let executable = info[kSecCodeInfoMainExecutable as String] as? URL {
            let path = executable.path
            return path.contains("Clash Mac.app/") || path.contains("ClashMac.app/")
        }
        #endif

        return false
    }
}
