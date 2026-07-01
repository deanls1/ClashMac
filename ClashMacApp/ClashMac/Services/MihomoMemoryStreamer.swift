import Foundation

/// 订阅 Mihomo 的 `/memory` WebSocket，读取内核自报的常驻内存（inuse）。
/// 相比对 PID 跑 `ps`，此方式不受 TUN 下内核为 root 进程、PID 因 KeepAlive 重启失效等影响，更可靠。
final class MihomoMemoryStreamer: @unchecked Sendable {
    private var webSocket: MihomoUnixWebSocket?
    private var isRunning = false
    private var retryTask: Task<Void, Never>?

    func start(runtime: RuntimeConfig, onSample: @escaping @Sendable (Int) -> Void) {
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
        onSample: @escaping @Sendable (Int) -> Void,
        attempt: Int
    ) {
        guard isRunning else { return }

        let ws = MihomoUnixWebSocket()
        webSocket = ws

        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                try ws.connect(runtime: runtime, path: "/memory")
                ws.receiveText { text in
                    guard let data = text.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                    let inuse = json["inuse"] as? Int ?? 0
                    onSample(inuse)
                } onClose: { [weak self] in
                    self?.scheduleReconnect(runtime: runtime, onSample: onSample, attempt: attempt + 1)
                }
            } catch {
                self?.scheduleReconnect(runtime: runtime, onSample: onSample, attempt: attempt + 1)
            }
        }
    }

    private func scheduleReconnect(
        runtime: RuntimeConfig,
        onSample: @escaping @Sendable (Int) -> Void,
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
