import Darwin
import Foundation

/// 单例：内核进程句柄必须跨多次 XPC 连接存活。
/// 客户端每次调用都会新建并随即 invalidate 连接，若 HelperService 按连接创建，
/// startTunnel 启动的 Process 会随连接释放而丢失（表现为 tunnelStatus running=false、内核变孤儿）。
final class HelperService: NSObject, HelperProtocol {
    nonisolated(unsafe) static let shared = HelperService()

    private let lock = NSLock()
    private var clientEGID: gid_t = 0
    private var coreProcess: Process?
    private var corePID: Int32 = 0
    private var lastConfigPath: String?
    private var lastCorePath: String?

    func updateClientEGID(_ egid: gid_t) {
        lock.lock()
        clientEGID = egid
        lock.unlock()
    }

    private func currentClientEGID() -> gid_t {
        lock.lock()
        defer { lock.unlock() }
        return clientEGID
    }

    func startTunnel(
        corePath: String,
        configPath: String,
        workDirectory: String,
        secret: String,
        reply: @escaping (Bool, String?) -> Void
    ) {
        stopCoreIfRunning()

        guard Self.validateClientGID(currentClientEGID(), configPath: configPath) else {
            reply(false, "调用方 GID 校验失败")
            return
        }
        guard HelperPathPolicy.isAllowedCorePath(corePath) else {
            reply(false, "内核路径不在允许范围内")
            return
        }
        guard HelperPathPolicy.isAllowedConfigPath(configPath) else {
            reply(false, "配置路径不在允许范围内")
            return
        }
        guard HelperPathPolicy.isAllowedWorkDirectory(workDirectory) else {
            reply(false, "工作目录不在允许范围内")
            return
        }
        guard Self.configMatchesSecret(at: configPath, secret: secret) else {
            reply(false, "配置密钥校验失败")
            return
        }
        guard Self.configPassesSecurityPolicy(at: configPath) else {
            reply(false, "配置安全策略校验失败")
            return
        }

        guard FileManager.default.isExecutableFile(atPath: corePath) else {
            reply(false, "Mihomo 不可执行")
            return
        }

        // 清理任何使用本应用配置的残留 mihomo（root 启动的孤儿用户态杀不掉），保证单实例，
        // 否则多个进程抢占同一控制 socket 会导致 app 连到非转发实例 → 日志/流量为空。
        let socketPath = Self.unixControllerPath(from: configPath)
        Self.reapStrayCores(configPath: configPath, corePath: corePath)
        try? FileManager.default.removeItem(atPath: socketPath)

        do {
            try FileManager.default.createDirectory(atPath: workDirectory, withIntermediateDirectories: true)
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: corePath)
            // secret 不走命令行（避免 ps 泄露）；mihomo 从已校验的 config 的 `secret:` 字段读取。
            proc.arguments = [
                "-f", configPath,
                "-d", workDirectory,
                "-ext-ctl-unix", socketPath,
            ]
            proc.currentDirectoryURL = URL(fileURLWithPath: workDirectory)
            try proc.run()
            lock.lock()
            coreProcess = proc
            corePID = proc.processIdentifier
            lastConfigPath = configPath
            lastCorePath = corePath
            lock.unlock()
            reply(true, nil)
        } catch {
            reply(false, error.localizedDescription)
        }
    }

    /// 枚举并 SIGKILL 所有命令行匹配本应用 config/core 的 mihomo 进程（helper 以 root 运行，可清理 root 孤儿）。
    /// 仅当 config/core 路径本身落在 HelperPathPolicy 允许范围内时才执行，避免被诱导以任意路径匹配杀进程。
    private static func reapStrayCores(configPath: String, corePath: String) {
        guard HelperPathPolicy.isAllowedConfigPath(configPath),
              HelperPathPolicy.isAllowedCorePath(corePath) else {
            return
        }
        for pid in runningCorePIDs(configPath: configPath, corePath: corePath) {
            kill(pid, SIGKILL)
        }
    }

    private static func runningCorePIDs(configPath: String, corePath: String) -> [Int32] {
        corePIDs { command in
            command.contains(configPath) || command.contains(corePath)
        }
    }

    /// helper 可能被 launchd（KeepAlive）重启而丢失子进程句柄；用 ps 兜底找回正在运行的内核 pid。
    private static func findRunningCorePID(configPath: String?) -> Int32? {
        let marker = configPath ?? "ClashMac/work/config.yaml"
        return corePIDs { $0.contains(marker) }.first
    }

    /// 扫描 ps，返回命令行含 "mihomo" 且满足 predicate 的进程 pid（排除自身）。
    private static func corePIDs(where predicate: (String) -> Bool) -> [Int32] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-axo", "pid=,command="]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        let me = getpid()
        var pids: [Int32] = []
        for rawLine in output.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let spaceIndex = line.firstIndex(of: " ") else { continue }
            let pidPart = String(line[..<spaceIndex])
            let command = String(line[line.index(after: spaceIndex)...])
            guard let pid = Int32(pidPart), pid != me else { continue }
            guard command.contains("mihomo"), predicate(command) else { continue }
            pids.append(pid)
        }
        return pids
    }

    func stopTunnel(reply: @escaping (Bool, String?) -> Void) {
        guard Self.validateClientGID(currentClientEGID(), configPath: nil) else {
            reply(false, "调用方 GID 校验失败")
            return
        }
        stopCoreIfRunning()
        reply(true, nil)
    }

    private func stopCoreIfRunning(timeout: TimeInterval = 2) {
        lock.lock()
        let proc = coreProcess
        let configPath = lastConfigPath
        let corePath = lastCorePath
        coreProcess = nil
        corePID = 0
        lock.unlock()

        if let proc, proc.isRunning {
            proc.terminate()
            let deadline = Date().addingTimeInterval(timeout)
            while proc.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if proc.isRunning {
                kill(proc.processIdentifier, SIGKILL)
            }
        }

        // 兜底清理任何残留实例，避免孤儿进程占用 socket。
        if let configPath, let corePath {
            Self.reapStrayCores(configPath: configPath, corePath: corePath)
        }
    }

    func tunnelStatus(reply: @escaping (Bool, Int32) -> Void) {
        guard Self.validateClientGID(currentClientEGID(), configPath: nil) else {
            reply(false, 0)
            return
        }
        lock.lock()
        var running = coreProcess?.isRunning == true
        var pid = running ? corePID : 0
        let cfg = lastConfigPath
        lock.unlock()
        if !running, let found = Self.findRunningCorePID(configPath: cfg) {
            running = true
            pid = found
        }
        reply(running, pid)
    }

    private static func validateClientGID(_ egid: gid_t, configPath: String?) -> Bool {
        if let configPath,
           let trusted = HelperTrustStore.trustedGID(matchingConfigPath: configPath) {
            return egid == trusted
        }
        let file = HelperTrustStore.trustedGIDFile(inAppSupport: HelperTrustStore.defaultAppSupportDirectory())
        guard let text = try? String(contentsOf: file, encoding: .utf8),
              let trusted = gid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }
        return egid == trusted
    }

    private static func defaultUnixSocketPath() -> String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("ClashMac/ipc/clashmac-mihomo.sock").path
    }

    private static func unixControllerPath(from configPath: String) -> String {
        guard let text = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return defaultUnixSocketPath()
        }
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("external-controller-unix:") else { continue }
            var raw = trimmed.dropFirst("external-controller-unix:".count)
                .trimmingCharacters(in: .whitespaces)
            raw = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            let path = String(raw)
            return path.isEmpty ? defaultUnixSocketPath() : path
        }
        return defaultUnixSocketPath()
    }

    private static func configMatchesSecret(at configPath: String, secret: String) -> Bool {
        guard !secret.isEmpty else { return false }
        guard let text = try? String(contentsOfFile: configPath, encoding: .utf8) else { return false }
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("secret:") else { continue }
            let value = trimmed.dropFirst("secret:".count)
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return value == secret
        }
        return false
    }

    private static func configPassesSecurityPolicy(at configPath: String) -> Bool {
        guard let text = try? String(contentsOfFile: configPath, encoding: .utf8) else { return false }
        var allowLAN: Bool?
        var unixPath: String?
        var httpController: String?

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("allow-lan:") {
                let raw = trimmed.dropFirst("allow-lan:".count).trimmingCharacters(in: .whitespaces)
                allowLAN = raw == "true"
            } else if trimmed.hasPrefix("external-controller-unix:") {
                var raw = trimmed.dropFirst("external-controller-unix:".count)
                    .trimmingCharacters(in: .whitespaces)
                raw = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                unixPath = String(raw)
            } else if trimmed.hasPrefix("external-controller:") {
                var raw = trimmed.dropFirst("external-controller:".count)
                    .trimmingCharacters(in: .whitespaces)
                raw = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                httpController = String(raw)
            }
        }

        if allowLAN == true { return false }
        if let unixPath,
           !unixPath.contains("/Library/Application Support/ClashMac"),
           !unixPath.contains("/Library/Application Support/LiteClash") {
            return false
        }
        if let httpController, !httpController.isEmpty {
            guard httpController.hasPrefix("127.0.0.1") || httpController.hasPrefix("localhost") else {
                return false
            }
        }
        return true
    }
}

final class HelperListener: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard HelperClientValidator.validateSignature(connection),
              let egid = HelperAudit.effectiveGID(for: connection) else {
            return false
        }
        HelperService.shared.updateClientEGID(egid)
        connection.exportedInterface = HelperConstants.makeInterface()
        connection.exportedObject = HelperService.shared
        connection.resume()
        return true
    }
}

enum ClashMacHelperMain {
    nonisolated(unsafe) private static let listenerDelegate = HelperListener()

    static func main() {
        let listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
        listener.delegate = listenerDelegate
        listener.resume()
        RunLoop.current.run()
    }
}

ClashMacHelperMain.main()
