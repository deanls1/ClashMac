import Foundation

enum CoreLocator {
    static func bundledCoreURL() -> URL? {
        let names = ["mihomo-darwin-arm64", "mihomo-darwin-amd64", "mihomo"]
        for name in names {
            if let url = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "Core") {
                return url
            }
            if let url = Bundle.main.url(forResource: name, withExtension: nil) {
                return url
            }
        }
        return nil
    }

    static func discoverCoreURL() -> URL? {
        if let installed = CoreUpdateService.installedCoreURL() {
            return installed
        }
        if let bundled = bundledCoreURL(), FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }

        let candidates = [
            "/opt/homebrew/bin/mihomo",
            "/usr/local/bin/mihomo",
            NSHomeDirectory() + "/.local/bin/mihomo"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    /// TUN / Helper 模式仅允许应用内嵌或 App Support 下的内核，禁止 root 启动任意路径二进制。
    static func discoverPrivilegedCoreURL() -> URL? {
        if let installed = CoreUpdateService.installedCoreURL() {
            return installed
        }
        if let bundled = bundledCoreURL(), FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }
        return nil
    }

    static func coreVersion(at url: URL) -> String? {
        let process = Process()
        process.executableURL = url
        process.arguments = ["-v"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
