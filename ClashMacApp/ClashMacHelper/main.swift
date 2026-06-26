import Foundation

final class HelperService: NSObject, HelperProtocol {
    private let clientEGID: gid_t
    private var coreProcess: Process?
    private var corePID: Int32 = 0

    init(clientEGID: gid_t) {
        self.clientEGID = clientEGID
    }

    func startTunnel(
        corePath: String,
        configPath: String,
        workDirectory: String,
        secret: String,
        reply: @escaping (Bool, String?) -> Void
    ) {
        stopTunnel { _, _ in }

        guard Self.validateClientGID(clientEGID, configPath: configPath) else {
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

        do {
            try FileManager.default.createDirectory(atPath: workDirectory, withIntermediateDirectories: true)
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: corePath)
            proc.arguments = ["-f", configPath, "-d", workDirectory]
            proc.currentDirectoryURL = URL(fileURLWithPath: workDirectory)
            try proc.run()
            coreProcess = proc
            corePID = proc.processIdentifier
            reply(true, nil)
        } catch {
            reply(false, error.localizedDescription)
        }
    }

    func stopTunnel(reply: @escaping (Bool, String?) -> Void) {
        guard Self.validateClientGID(clientEGID, configPath: nil) else {
            reply(false, "调用方 GID 校验失败")
            return
        }
        if let proc = coreProcess, proc.isRunning {
            proc.terminate()
            proc.waitUntilExit()
        }
        coreProcess = nil
        corePID = 0
        reply(true, nil)
    }

    func tunnelStatus(reply: @escaping (Bool, Int32) -> Void) {
        guard Self.validateClientGID(clientEGID, configPath: nil) else {
            reply(false, 0)
            return
        }
        let running = coreProcess?.isRunning == true
        reply(running, running ? corePID : 0)
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
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = HelperService(clientEGID: egid)
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
