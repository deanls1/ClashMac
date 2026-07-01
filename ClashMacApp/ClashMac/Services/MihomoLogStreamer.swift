import Foundation

final class MihomoLogStreamer: @unchecked Sendable {
    private var webSocket: MihomoUnixWebSocket?
    private var isRunning = false
    private var retryTask: Task<Void, Never>?

    func start(
        runtime: RuntimeConfig,
        level: LogLevel,
        onEntry: @escaping @Sendable (LogEntry) -> Void,
        onFailure: (@Sendable (String) -> Void)? = nil
    ) {
        stop()
        isRunning = true
        connect(runtime: runtime, level: level, onEntry: onEntry, onFailure: onFailure, attempt: 0)
    }

    func stop() {
        isRunning = false
        retryTask?.cancel()
        retryTask = nil
        webSocket?.disconnect()
        webSocket = nil
    }

    private func connect(
        runtime: RuntimeConfig,
        level: LogLevel,
        onEntry: @escaping @Sendable (LogEntry) -> Void,
        onFailure: (@Sendable (String) -> Void)?,
        attempt: Int
    ) {
        guard isRunning else { return }

        let ws = MihomoUnixWebSocket()
        webSocket = ws
        let path = "/logs?level=\(level.rawValue)"

        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                try ws.connect(runtime: runtime, path: path)
                ws.receiveText { text in
                    onEntry(Self.parseLogLine(text))
                } onClose: { [weak self] in
                    guard let self, self.isRunning else { return }
                    self.scheduleReconnect(
                        runtime: runtime,
                        level: level,
                        onEntry: onEntry,
                        onFailure: onFailure,
                        attempt: attempt + 1
                    )
                }
            } catch {
                onFailure?("内核日志流连接失败：\(error.localizedDescription)")
                self?.scheduleReconnect(
                    runtime: runtime,
                    level: level,
                    onEntry: onEntry,
                    onFailure: onFailure,
                    attempt: attempt + 1
                )
            }
        }
    }

    private func scheduleReconnect(
        runtime: RuntimeConfig,
        level: LogLevel,
        onEntry: @escaping @Sendable (LogEntry) -> Void,
        onFailure: (@Sendable (String) -> Void)?,
        attempt: Int
    ) {
        guard isRunning, attempt <= 8 else { return }
        retryTask?.cancel()
        retryTask = Task {
            let delay = min(8.0, pow(1.6, Double(attempt)))
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, isRunning else { return }
            connect(runtime: runtime, level: level, onEntry: onEntry, onFailure: onFailure, attempt: attempt)
        }
    }

    private static func parseLogLine(_ line: String) -> LogEntry {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return LogEntry(level: .info, message: line)
        }

        if trimmed.hasPrefix("[") {
            let parts = trimmed.split(separator: "]", maxSplits: 1)
            let levelRaw = parts.first.map { $0.dropFirst().lowercased() } ?? "info"
            let message = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : trimmed
            let level = LogLevel(rawValue: String(levelRaw)) ?? .info
            return LogEntry(level: level, message: message)
        }

        if trimmed.contains("level=") {
            let level: LogLevel
            if trimmed.localizedCaseInsensitiveContains("level=error") {
                level = .error
            } else if trimmed.localizedCaseInsensitiveContains("level=warning") || trimmed.localizedCaseInsensitiveContains("level=warn") {
                level = .warning
            } else if trimmed.localizedCaseInsensitiveContains("level=debug") {
                level = .debug
            } else {
                level = .info
            }
            if let range = trimmed.range(of: "msg=") {
                var message = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if message.hasPrefix("\""), message.hasSuffix("\""), message.count >= 2 {
                    message = String(message.dropFirst().dropLast())
                }
                return LogEntry(level: level, message: message)
            }
            return LogEntry(level: level, message: trimmed)
        }

        return LogEntry(level: .info, message: trimmed)
    }
}
