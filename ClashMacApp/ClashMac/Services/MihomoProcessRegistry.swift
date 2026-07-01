import Foundation
import Darwin

/// 清理 ClashMac 遗留的 Mihomo 进程，避免端口 / Unix Socket 与 API 控制器错位。
enum MihomoProcessRegistry {
    private static let configMarker = "ClashMac/work/config.yaml"
    private static let lock = NSLock()
    private nonisolated(unsafe) static var registeredPID: Int32?

    static func registerManagedPID(_ pid: Int32?) {
        lock.lock()
        registeredPID = pid
        lock.unlock()
    }

    static func clearManagedPID() {
        lock.lock()
        registeredPID = nil
        lock.unlock()
    }

    /// 异步清理，避免阻塞主线程导致启动按钮卡死。
    static func terminateManagedInstances(excludingPID: Int32? = nil) async {
        await Task.detached(priority: .userInitiated) {
            terminateManagedInstancesSync(excludingPID: excludingPID)
        }.value
    }

    /// 退出流程等必须在同步上下文完成时使用。
    static func terminateManagedInstancesSync(excludingPID: Int32? = nil) {
        let exclude = excludingPID ?? registeredPID

        var pids = listMatchingPIDs()
        if let exclude {
            pids = pids.filter { $0 != exclude }
        }
        guard !pids.isEmpty else { return }

        for pid in pids {
            kill(pid, SIGTERM)
        }

        let deadline = Date().addingTimeInterval(1.0)
        while Date() < deadline {
            let survivors = pids.filter(isProcessAlive)
            if survivors.isEmpty { break }
            Thread.sleep(forTimeInterval: 0.05)
        }

        for pid in pids where isProcessAlive(pid) {
            kill(pid, SIGKILL)
        }
    }

    private static func isProcessAlive(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    private static func listMatchingPIDs() -> [Int32] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-ax", "-o", "pid=,command="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        let collector = OutputCollector()
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fh in
            let chunk = fh.availableData
            if chunk.isEmpty {
                fh.readabilityHandler = nil
            } else {
                collector.append(chunk)
            }
        }

        do {
            try process.run()
        } catch {
            handle.readabilityHandler = nil
            return []
        }

        if finished.wait(timeout: .now() + 1) == .timedOut {
            process.terminate()
            handle.readabilityHandler = nil
            return []
        }
        handle.readabilityHandler = nil
        let data = collector.data
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        var pids: [Int32] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard trimmed.localizedCaseInsensitiveContains("mihomo") else { continue }
            guard trimmed.contains(configMarker) else { continue }
            guard let space = trimmed.firstIndex(of: " ") else { continue }
            let pidText = trimmed[..<space].trimmingCharacters(in: .whitespaces)
            if let pid = Int32(pidText) {
                pids.append(pid)
            }
        }
        return pids
    }

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
}
