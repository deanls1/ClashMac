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
    func startTunnel(corePath: String, configPath: String, workDirectory: String, secret: String, timeout: TimeInterval = 15) async throws {
        let guardrail = ContinuationGuard()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let session = HelperXPCSession(onFailure: {
                guardrail.resumeOnce { continuation.resume(throwing: TunnelHelperError.helperUnavailable) }
            }) else {
                continuation.resume(throwing: TunnelHelperError.helperUnavailable)
                return
            }

            let timeoutWork = DispatchWorkItem {
                guardrail.resumeOnce {
                    session.invalidate()
                    continuation.resume(throwing: TunnelHelperError.startFailed("Helper 启动超时（无响应）"))
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

            session.proxy.startTunnel(
                corePath: corePath,
                configPath: configPath,
                workDirectory: workDirectory,
                secret: secret
            ) { ok, error in
                timeoutWork.cancel()
                guardrail.resumeOnce {
                    session.invalidate()
                    if ok {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: TunnelHelperError.startFailed(error ?? "启动失败"))
                    }
                }
            }
        }
    }

    func stopTunnelSynchronously(timeout: TimeInterval = 3) {
        guard let session = HelperXPCSession(onFailure: {}) else { return }
        let semaphore = DispatchSemaphore(value: 0)
        session.proxy.stopTunnel { _, _ in
            session.invalidate()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + timeout)
        session.invalidate()
    }

    func stopTunnel() async throws {
        let guardrail = ContinuationGuard()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let session = HelperXPCSession(onFailure: {
                guardrail.resumeOnce {
                    continuation.resume(throwing: TunnelHelperError.helperUnavailable)
                }
            }) else {
                continuation.resume(throwing: TunnelHelperError.helperUnavailable)
                return
            }

            let timeoutWork = DispatchWorkItem {
                guardrail.resumeOnce {
                    session.invalidate()
                    continuation.resume(throwing: TunnelHelperError.startFailed("Helper 停止超时（无响应）"))
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: timeoutWork)

            session.proxy.stopTunnel { ok, error in
                timeoutWork.cancel()
                guardrail.resumeOnce {
                    session.invalidate()
                    if ok {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: TunnelHelperError.startFailed(error ?? "停止失败"))
                    }
                }
            }
        }
    }

    func tunnelStatus() async -> (running: Bool, pid: Int32) {
        let guardrail = ContinuationGuard()
        return await withCheckedContinuation { (continuation: CheckedContinuation<(Bool, Int32), Never>) in
            guard let session = HelperXPCSession(onFailure: {
                guardrail.resumeOnce {
                    continuation.resume(returning: (false, 0))
                }
            }) else {
                continuation.resume(returning: (false, 0))
                return
            }

            let timeoutWork = DispatchWorkItem {
                guardrail.resumeOnce {
                    session.invalidate()
                    continuation.resume(returning: (false, 0))
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: timeoutWork)

            session.proxy.tunnelStatus { running, pid in
                timeoutWork.cancel()
                guardrail.resumeOnce {
                    session.invalidate()
                    continuation.resume(returning: (running, pid))
                }
            }
        }
    }

    func isReachable(timeout: TimeInterval = 3) async -> Bool {
        let guardrail = ContinuationGuard()
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            guard let session = HelperXPCSession(onFailure: {
                guardrail.resumeOnce {
                    continuation.resume(returning: false)
                }
            }) else {
                continuation.resume(returning: false)
                return
            }

            let timeoutWork = DispatchWorkItem {
                guardrail.resumeOnce {
                    session.invalidate()
                    continuation.resume(returning: false)
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

            session.proxy.tunnelStatus { _, _ in
                timeoutWork.cancel()
                guardrail.resumeOnce {
                    session.invalidate()
                    continuation.resume(returning: true)
                }
            }
        }
    }

    var isInstalled: Bool { HelperInstaller.isInstalled() }
}

/// 持有 NSXPCConnection 直到 reply 返回，避免连接过早释放导致 decode 失败。
private final class HelperXPCSession: @unchecked Sendable {
    private let connection: NSXPCConnection
    let proxy: HelperProtocol

    init?(onFailure: @escaping () -> Void) {
        guard HelperInstaller.isBundled(), HelperInstaller.isInstalled() else { return nil }

        let connection = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
        connection.remoteObjectInterface = HelperConstants.makeInterface()
        connection.invalidationHandler = onFailure
        connection.interruptionHandler = onFailure
        connection.resume()

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in onFailure() }) as? HelperProtocol else {
            connection.invalidate()
            return nil
        }

        self.connection = connection
        self.proxy = proxy
    }

    func invalidate() {
        connection.invalidate()
    }
}

/// 确保 CheckedContinuation 只被 resume 一次（超时与 XPC 回调竞争时）。
private final class ContinuationGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func resumeOnce(_ block: () -> Void) {
        lock.lock()
        if done {
            lock.unlock()
            return
        }
        done = true
        lock.unlock()
        block()
    }
}
