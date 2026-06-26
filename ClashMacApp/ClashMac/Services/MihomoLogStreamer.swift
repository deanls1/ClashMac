import Foundation

final class MihomoLogStreamer: @unchecked Sendable {
    private var webSocket: MihomoUnixWebSocket?
    private var isRunning = false

    func start(runtime: RuntimeConfig, level: LogLevel, onEntry: @escaping @Sendable (LogEntry) -> Void) {
        stop()
        isRunning = true

        let ws = MihomoUnixWebSocket()
        webSocket = ws
        let path = "/logs?level=\(level.rawValue)"

        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                try ws.connect(socketPath: runtime.controllerUnixPath, path: path, secret: runtime.secret)
                ws.receiveText { text in
                    onEntry(Self.parseLogLine(text))
                } onClose: { }
            } catch {
                self?.stop()
            }
        }
    }

    func stop() {
        isRunning = false
        webSocket?.disconnect()
        webSocket = nil
    }

    private static func parseLogLine(_ line: String) -> LogEntry {
        if line.hasPrefix("[") {
            let parts = line.split(separator: "]", maxSplits: 1)
            let levelRaw = parts.first.map { $0.dropFirst().lowercased() } ?? "info"
            let message = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : line
            let level = LogLevel(rawValue: String(levelRaw)) ?? .info
            return LogEntry(level: level, message: message)
        }
        return LogEntry(level: .info, message: line)
    }
}
