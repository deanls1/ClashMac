import Foundation

/// 应用自身运行日志（启动、Helper、API 等），与 Mihomo 内核日志分离。
enum AppLogger {
    static func info(_ message: String) { log(.info, message) }
    static func warning(_ message: String) { log(.warning, message) }
    static func error(_ message: String) { log(.error, message) }
    static func debug(_ message: String) { log(.debug, message) }

    private static func log(_ level: LogLevel, _ message: String) {
        Task { @MainActor in
            AppLoggerBridge.shared.append(level: level, message: message)
        }
    }
}

@MainActor
final class AppLoggerBridge {
    static let shared = AppLoggerBridge()
    var handler: ((LogLevel, String) -> Void)?

    func append(level: LogLevel, message: String) {
        handler?(level, message)
    }
}
