import CryptoKit
import Foundation

enum CoreConfigValidator {
    enum ValidationError: LocalizedError {
        case coreNotFound
        case failed(String)
        case timedOut

        var errorDescription: String? {
            switch self {
            case .coreNotFound: "未找到 Mihomo 内核，无法校验配置"
            case .failed(let msg): msg
            case .timedOut: "配置校验超时"
            }
        }
    }

    private static let cacheDefaultsKey = "lastValidatedConfigHash"

    /// 启动前用 Mihomo 校验配置（对齐 Verge Rev CoreConfigValidator）。
    /// 为提升启动速度，对相同配置内容跳过 `mihomo -t`（一次完整加载约 1-3s）。
    static func validateIfNeeded(configURL: URL, coreURL: URL, workDirectory: URL) throws {
        let hash = configHash(at: configURL, coreURL: coreURL)
        if let hash, hash == UserDefaults.standard.string(forKey: cacheDefaultsKey) {
            return
        }
        try validate(configURL: configURL, coreURL: coreURL, workDirectory: workDirectory)
        if let hash {
            UserDefaults.standard.set(hash, forKey: cacheDefaultsKey)
        }
    }

    /// 配置或内核变化时使缓存失效，强制下次重新校验。
    static func invalidateCache() {
        UserDefaults.standard.removeObject(forKey: cacheDefaultsKey)
    }

    /// 校验超时上限：`mihomo -t` 遇到远程 provider 可能联网拉取而长时间不返回，
    /// 超时则视为不可校验并交由真正启动时的健康检查兜底，避免启动流程被无限阻塞。
    static func validate(configURL: URL, coreURL: URL, workDirectory: URL, timeout: TimeInterval = 6) throws {
        let process = Process()
        process.executableURL = coreURL
        process.arguments = ["-t", "-f", configURL.path, "-d", workDirectory.path]
        process.currentDirectoryURL = workDirectory

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        // 后台持续读取，避免管道缓冲写满导致子进程在我们超时前就被阻塞。
        let handle = pipe.fileHandleForReading
        let collected = OutputCollector()
        handle.readabilityHandler = { fh in
            let chunk = fh.availableData
            if chunk.isEmpty {
                fh.readabilityHandler = nil
            } else {
                collected.append(chunk)
            }
        }

        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.1)
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            handle.readabilityHandler = nil
            throw ValidationError.timedOut
        }

        handle.readabilityHandler = nil
        let output = String(data: collected.data, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ValidationError.failed(message.isEmpty ? "配置校验失败" : message)
        }
    }

    /// 线程安全地累积子进程输出。
    private final class OutputCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var storage = Data()

        func append(_ chunk: Data) {
            lock.lock()
            storage.append(chunk)
            lock.unlock()
        }

        var data: Data {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
    }

    /// 配置内容 + 内核可执行体修改时间共同决定缓存键。
    private static func configHash(at configURL: URL, coreURL: URL) -> String? {
        guard let configData = try? Data(contentsOf: configURL) else { return nil }
        var hasher = SHA256()
        hasher.update(data: configData)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: coreURL.path),
           let modified = attrs[.modificationDate] as? Date {
            hasher.update(data: Data(String(modified.timeIntervalSince1970).utf8))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
