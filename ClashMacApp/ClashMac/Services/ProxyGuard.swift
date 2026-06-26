import Foundation

@MainActor
final class ProxyGuard {
    private var task: Task<Void, Never>?
    private let interval: Duration = .seconds(5)

    var isRunning: Bool { task != nil }

    func start(host: String, port: Int) {
        stop()
        task = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { break }
                reapplyIfNeeded(host: host, port: port)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func reapplyIfNeeded(host: String, port: Int) {
        guard let state = try? SystemProxyController.readProxyState() else { return }
        guard !SystemProxyController.matchesExpected(state, host: host, port: port) else { return }
        try? SystemProxyController.setSystemProxy(host: host, port: port, enabled: true)
    }
}
