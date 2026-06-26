import Foundation

enum TunnelHelperError: LocalizedError {
    case helperUnavailable
    case startFailed(String)

    var errorDescription: String? {
        switch self {
        case .helperUnavailable: "特权 Helper 不可用，请安装到 /Applications 并在设置中批准 Helper"
        case .startFailed(let msg): msg
        }
    }
}

struct TunnelHelperClient: Sendable {
    func startTunnel(corePath: String, configPath: String, workDirectory: String, secret: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let proxy = makeProxy() else {
                continuation.resume(throwing: TunnelHelperError.helperUnavailable)
                return
            }
            proxy.startTunnel(
                corePath: corePath,
                configPath: configPath,
                workDirectory: workDirectory,
                secret: secret
            ) { ok, error in
                if ok {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: TunnelHelperError.startFailed(error ?? "启动失败"))
                }
            }
        }
    }

    func stopTunnelSynchronously(timeout: TimeInterval = 3) {
        guard let proxy = makeProxy() else { return }
        let semaphore = DispatchSemaphore(value: 0)
        proxy.stopTunnel { _, _ in semaphore.signal() }
        _ = semaphore.wait(timeout: .now() + timeout)
    }

    func stopTunnel() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let proxy = makeProxy() else {
                continuation.resume(throwing: TunnelHelperError.helperUnavailable)
                return
            }
            proxy.stopTunnel { ok, error in
                if ok {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: TunnelHelperError.startFailed(error ?? "停止失败"))
                }
            }
        }
    }

    var isInstalled: Bool { HelperInstaller.isInstalled() }

    private func makeProxy() -> HelperProtocol? {
        let connection = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.resume()
        return connection.remoteObjectProxyWithErrorHandler { _ in } as? HelperProtocol
    }
}
