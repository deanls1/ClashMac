import Foundation

final class MihomoTrafficStreamer: @unchecked Sendable {
    private var webSocket: MihomoUnixWebSocket?
    private var isRunning = false
    private var retryTask: Task<Void, Never>?

    func start(runtime: RuntimeConfig, onSample: @escaping @Sendable (Int, Int) -> Void) {
        stop()
        isRunning = true
        connect(runtime: runtime, onSample: onSample, attempt: 0)
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
        onSample: @escaping @Sendable (Int, Int) -> Void,
        attempt: Int
    ) {
        guard isRunning else { return }

        let ws = MihomoUnixWebSocket()
        webSocket = ws

        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                try ws.connect(runtime: runtime, path: "/traffic")
                ws.receiveText { text in
                    guard let data = text.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                    let up = json["up"] as? Int ?? json["upload"] as? Int ?? 0
                    let down = json["down"] as? Int ?? json["download"] as? Int ?? 0
                    onSample(up, down)
                } onClose: { [weak self] in
                    // 连接被内核关闭（如重载配置）时自动重连，避免流量统计永久停摆。
                    self?.scheduleReconnect(runtime: runtime, onSample: onSample, attempt: attempt + 1)
                }
            } catch {
                self?.scheduleReconnect(runtime: runtime, onSample: onSample, attempt: attempt + 1)
            }
        }
    }

    private func scheduleReconnect(
        runtime: RuntimeConfig,
        onSample: @escaping @Sendable (Int, Int) -> Void,
        attempt: Int
    ) {
        guard isRunning, attempt <= 8 else { return }
        retryTask?.cancel()
        retryTask = Task {
            let delay = min(8.0, pow(1.6, Double(attempt)))
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, isRunning else { return }
            connect(runtime: runtime, onSample: onSample, attempt: attempt)
        }
    }
}
