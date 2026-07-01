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
                await reapplyIfNeeded(host: host, port: port)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func reapplyIfNeeded(host: String, port: Int) async {
        let needsReapply = await Task.detached(priority: .utility) {
            !SystemProxyController.isProxyActive(host: host, port: port)
        }.value
        guard needsReapply else { return }
        await Task.detached(priority: .utility) {
            try? SystemProxyController.setSystemProxy(host: host, port: port, enabled: true)
        }.value
    }
}
