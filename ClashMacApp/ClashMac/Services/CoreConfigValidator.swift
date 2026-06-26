import Foundation

enum CoreConfigValidator {
    enum ValidationError: LocalizedError {
        case coreNotFound
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .coreNotFound: "未找到 Mihomo 内核，无法校验配置"
            case .failed(let msg): msg
            }
        }
    }

    /// 启动前用 Mihomo 校验配置（对齐 Verge Rev CoreConfigValidator）。
    static func validate(configURL: URL, coreURL: URL, workDirectory: URL) throws {
        let process = Process()
        process.executableURL = coreURL
        process.arguments = ["-t", "-f", configURL.path, "-d", workDirectory.path]
        process.currentDirectoryURL = workDirectory

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ValidationError.failed(message.isEmpty ? "配置校验失败" : message)
        }
    }
}
