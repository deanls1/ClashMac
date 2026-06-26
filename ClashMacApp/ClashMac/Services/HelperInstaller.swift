import Foundation
import ServiceManagement

enum HelperInstaller {
    private static let plistName = "com.clashmac.helper.plist"
    private static let daemonLabel = "com.clashmac.helper"

    static func helperPlistURL() -> URL {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchDaemons/\(plistName)")
    }

    static func helperURL() -> URL? {
        let url = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchServices/ClashMacHelper")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    static func isBundled() -> Bool {
        FileManager.default.fileExists(atPath: helperPlistURL().path) && helperURL() != nil
    }

    static func isInstalled() -> Bool {
        guard isBundled() else { return false }
        return daemonService().status == .enabled
    }

    static func installStatusText() -> String {
        guard isBundled() else {
            return "Helper 未打包进应用"
        }
        switch daemonService().status {
        case .enabled: return "已安装"
        case .requiresApproval: return "需要在系统设置 → 登录项 中批准"
        case .notRegistered: return "未安装（点击安装）"
        case .notFound: return "未注册（需安装到 /Applications 后重试）"
        @unknown default: return "未知"
        }
    }

    static func install() throws {
        guard isBundled() else {
            throw HelperInstallError.notBundled
        }
        try HelperTrustStore.recordCurrentUser()
        try daemonService().register()
    }

    static func uninstall() throws {
        guard isBundled() else { return }
        try daemonService().unregister()
    }

    private static func daemonService() -> SMAppService {
        SMAppService.daemon(plistName: plistName)
    }
}

enum HelperInstallError: LocalizedError {
    case notBundled

    var errorDescription: String? {
        switch self {
        case .notBundled: "Helper 未正确打包，请重新编译应用"
        }
    }
}
