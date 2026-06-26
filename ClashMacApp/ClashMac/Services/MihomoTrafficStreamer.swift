import Foundation

final class MihomoTrafficStreamer: @unchecked Sendable {
    private var webSocket: MihomoUnixWebSocket?
    private var isRunning = false

    func start(runtime: RuntimeConfig, onSample: @escaping @Sendable (Int, Int) -> Void) {
        stop()
        isRunning = true

        let ws = MihomoUnixWebSocket()
        webSocket = ws

        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                try ws.connect(socketPath: runtime.controllerUnixPath, path: "/traffic", secret: runtime.secret)
                ws.receiveText { text in
                    guard let data = text.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                    let up = json["up"] as? Int ?? json["upload"] as? Int ?? 0
                    let down = json["down"] as? Int ?? json["download"] as? Int ?? 0
                    onSample(up, down)
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
}
