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

    static func serviceStatus() -> SMAppService.Status {
        guard isBundled() else { return .notFound }
        return daemonService().status
    }

    /// TUN 模式是否已就绪（Helper 已注册且系统已批准）。
    static func isReadyForTun() -> Bool {
        isInstalled()
    }

    static func installStatusText() -> String {
        guard isBundled() else {
            return "Helper 未打包进应用"
        }
        switch daemonService().status {
        case .enabled: return "已安装（TUN 异常时请重装）"
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
        if daemonService().status == .enabled {
            try? daemonService().unregister()
        }
        try daemonService().register()
    }

    /// 强制刷新注册：先注销再注册，用于内核/Helper 二进制重新签名后 launchd 仍缓存旧
    /// LightWeight Code Requirement（表现为 spawn failed / EX_CONFIG / XPC 不可达）的恢复。
    static func forceReinstall() throws {
        guard isBundled() else {
            throw HelperInstallError.notBundled
        }
        try HelperTrustStore.recordCurrentUser()
        try? daemonService().unregister()
        Thread.sleep(forTimeInterval: 0.6)
        try daemonService().register()
    }

    /// 供日志输出的服务状态简述。
    static func statusDescription() -> String {
        switch serviceStatus() {
        case .enabled: return "enabled"
        case .requiresApproval: return "requiresApproval"
        case .notRegistered: return "notRegistered"
        case .notFound: return "notFound"
        @unknown default: return "unknown"
        }
    }

    static func installFailureMessage(for error: Error) -> String {
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("operation not permitted")
            || text.contains("操作不被允许") {
            return """
            无法安装 Helper（权限不足）。请确认：
            1. 将 Clash Mac 安装到「应用程序」文件夹
            2. 在系统设置 → 通用 → 登录项 中批准 ClashMac Helper
            3. 或在设置中关闭 TUN，改用系统代理模式
            """
        }
        return "Helper 安装失败：\(text)"
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
