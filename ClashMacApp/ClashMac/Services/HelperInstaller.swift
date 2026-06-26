import Foundation
import ServiceManagement

enum HelperInstaller {
    static func helperURL() -> URL? {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchServices/ClashMacHelper")
    }

    static func isInstalled() -> Bool {
        SMAppService.daemon(plistName: "com.clashmac.helper.plist").status == .enabled
    }

    static func installStatusText() -> String {
        switch SMAppService.daemon(plistName: "com.clashmac.helper.plist").status {
        case .enabled: "已安装"
        case .requiresApproval: "需要在系统设置中批准"
        case .notRegistered: "未安装"
        case .notFound: "未找到 Helper 配置"
        @unknown default: "未知"
        }
    }

    static func install() throws {
        try HelperTrustStore.recordCurrentUser()
        let service = SMAppService.daemon(plistName: "com.clashmac.helper.plist")
        try service.register()
    }

    static func uninstall() throws {
        let service = SMAppService.daemon(plistName: "com.clashmac.helper.plist")
        try service.unregister()
    }
}
